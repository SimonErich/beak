import 'dart:async';
import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:worm/worm.dart';

import '../common/uuid_v4.dart';
import '../server/middleware/error_mapping_middleware.dart';

/// Durable effects committed with a graph and delivered after its transaction.
final class BeakOutboxMigration extends Migration {
  /// Registers the internal outbox table with the host migration runner.
  const BeakOutboxMigration();

  /// Private storage table; never exposed as a CRUD resource.
  static const table = '_beak_outbox';

  @override
  String get name => '20260927_000000_beak_outbox';

  @override
  Future<void> up(DatabaseAdapter adapter) => adapter.executeSchema(
    const SchemaDescriptor.createTable(
      table: table,
      ifNotExists: true,
      columns: [
        SchemaColumn(name: 'id', type: ColumnType.text, isPrimaryKey: true),
        SchemaColumn(name: 'kind', type: ColumnType.text),
        SchemaColumn(name: 'payload', type: ColumnType.text),
        SchemaColumn(name: 'status', type: ColumnType.text),
        SchemaColumn(name: 'attempt', type: ColumnType.integer),
        SchemaColumn(name: 'available_at', type: ColumnType.integer),
        SchemaColumn(name: 'lease', type: ColumnType.text),
        SchemaColumn(name: 'last_error', type: ColumnType.text),
      ],
    ),
  );

  @override
  Future<void> down(DatabaseAdapter adapter) => adapter.executeSchema(
    const SchemaDescriptor.dropTable(table: table, ifExists: true),
  );
}

/// Where the outbox keeps its rows.
///
/// Beak's own table is [beak], created by [BeakOutboxMigration]. A host whose
/// migrations Beak does not own (Serverpod) maps the outbox onto a model of
/// its own instead, by naming the table and any column that is spelled
/// differently. Pass the same mapping to [BeakOutbox.enqueue],
/// [BeakOutboxSchedule] and [BeakOutbox.prune], usually through
/// `BeakFrameworkTables.outbox`.
final class BeakOutboxTable {
  /// Maps the outbox fields onto [table]; every column defaults to Beak's own
  /// name, so a renamed table alone is `BeakOutboxTable(table: 'my_outbox')`.
  const BeakOutboxTable({
    required this.table,
    this.idColumn = 'id',
    this.kindColumn = 'kind',
    this.payloadColumn = 'payload',
    this.statusColumn = 'status',
    this.attemptColumn = 'attempt',
    this.availableAtColumn = 'available_at',
    this.leaseColumn = 'lease',
    this.lastErrorColumn = 'last_error',
  });

  /// Beak's own table, created by [BeakOutboxMigration].
  static const BeakOutboxTable beak = BeakOutboxTable(
    table: BeakOutboxMigration.table,
  );

  /// Table name.
  final String table;

  /// Unique text column holding the effect key.
  final String idColumn;

  /// Text column holding the effect kind.
  final String kindColumn;

  /// Text column holding the JSON payload.
  final String payloadColumn;

  /// Text column holding `pending`, `running`, `delivered` or `failed`.
  final String statusColumn;

  /// Integer column counting delivery attempts.
  final String attemptColumn;

  /// Integer column holding milliseconds since the epoch: when the row is
  /// next due, or when its lease ends while it runs.
  final String availableAtColumn;

  /// Text column holding the current claim, empty when unclaimed.
  final String leaseColumn;

  /// Text column holding the category of the last failure.
  final String lastErrorColumn;

  /// Every column the outbox reads or writes.
  Set<String> get columns => {
    idColumn,
    kindColumn,
    payloadColumn,
    statusColumn,
    attemptColumn,
    availableAtColumn,
    leaseColumn,
    lastErrorColumn,
  };
}

/// Immutable delivery with a stable provider idempotency key across retries.
final class BeakOutboxEffect {
  /// Creates the delivery passed to a registered provider.
  const BeakOutboxEffect({
    required this.key,
    required this.kind,
    required this.payload,
    required this.attempt,
  });

  /// Use as the provider's idempotency key, including after lease expiry.
  final String key;

  /// Registered effect type.
  final String kind;

  /// Persisted typed payload; no callbacks or credentials in the queue.
  final BeakRecord payload;

  /// One-based attempt counter.
  final int attempt;
}

/// Provider execution. Must be idempotent by [BeakOutboxEffect.key].
///
/// Delivery is at least once: a process may die after a provider succeeds but
/// before its acknowledgement is stored. Providers must retain their receipt.
typedef BeakEffectHandler = Future<void> Function(BeakOutboxEffect effect);

/// Transactional queue writer, independent of any payment or notification vendor.
abstract final class BeakOutbox {
  /// Enqueues once. Call with the graph finalizer's transactional adapter.
  /// Reusing a key with different content is rejected rather than overwritten.
  ///
  /// [table] is where the row goes (default: Beak's own `_beak_outbox`).
  static Future<void> enqueue(
    DatabaseAdapter transaction, {
    required String key,
    required String kind,
    required BeakRecord payload,
    BeakOutboxTable table = BeakOutboxTable.beak,
  }) async {
    if (key.isEmpty || kind.isEmpty) {
      throw const BeakConfigurationException(
        'Outbox identity and kind are required.',
      );
    }
    final json = jsonEncode(_canonical(payload.toJson()));
    final existing = await transaction.selectOne(
      QueryDescriptor(
        table: table.table,
        where: StringField(table.idColumn).eq(key),
      ),
    );
    if (existing != null) {
      if (existing[table.kindColumn] != kind ||
          existing[table.payloadColumn] != json) {
        throw const BeakConflictException(
          'Effect identity was reused with different content.',
        );
      }
      return;
    }
    await transaction.insert(
      InsertDescriptor(
        table: table.table,
        values: {
          table.idColumn: key,
          table.kindColumn: kind,
          table.payloadColumn: json,
          table.statusColumn: 'pending',
          table.attemptColumn: 0,
          table.availableAtColumn: 0,
          table.leaseColumn: '',
          table.lastErrorColumn: '',
        },
      ),
    );
  }

  /// Deletes delivered effects that have been settled for at least
  /// [olderThan], and returns how many rows went.
  ///
  /// Nothing calls this for you: a delivered row is kept, so a repeated
  /// [enqueue] of its key stays a no-op instead of sending the effect twice.
  /// Pruning ends that protection for the rows it removes, so choose
  /// [olderThan] longer than any window in which the same key could be
  /// enqueued again (a retried request, a replayed receipt). Schedule it
  /// yourself, for instance from a nightly job:
  ///
  /// ```dart
  /// final removed = await BeakOutbox.prune(
  ///   adapter,
  ///   olderThan: const Duration(days: 30),
  /// );
  /// ```
  ///
  /// The age is measured from the row's due time, which a delivery leaves at
  /// the end of its lease, so a row is never pruned early. Rows that are
  /// `pending` or `running` are never touched. A `failed` row is an
  /// operator's to-do and stays unless [includeFailed] is set.
  ///
  /// [table] is the outbox to prune (default: Beak's own `_beak_outbox`) and
  /// [now] the clock (default: [DateTime.now]).
  static Future<int> prune(
    DatabaseAdapter adapter, {
    required Duration olderThan,
    bool includeFailed = false,
    BeakOutboxTable table = BeakOutboxTable.beak,
    DateTime Function()? now,
  }) async {
    if (olderThan < Duration.zero) {
      throw const BeakConfigurationException(
        'The age to prune outbox rows at must not be negative.',
      );
    }
    final int cutoff =
        (now ?? DateTime.now)().millisecondsSinceEpoch -
        olderThan.inMilliseconds;
    final settled = includeFailed
        ? StringField(table.statusColumn)
              .eq('delivered')
              .or(StringField(table.statusColumn).eq('failed'))
              .group()
        : StringField(table.statusColumn).eq('delivered');
    return adapter.delete(
      DeleteDescriptor(
        table: table.table,
        where: settled.and(
          ComparableField<int>(table.availableAtColumn).lte(cutoff),
        ),
      ),
    );
  }

  static Object? _canonical(Object? value) => switch (value) {
    final Map<String, Object?> map => {
      for (final key in map.keys.toList()..sort()) key: _canonical(map[key]),
    },
    final List<Object?> list => list.map(_canonical).toList(),
    _ => value,
  };
}

/// Bounded, lease-protected delivery with persisted retries and terminal failure.
final class BeakOutboxWorker {
  /// Creates a worker. Hosts schedule [drain] outside graph transactions.
  BeakOutboxWorker({
    required this.adapter,
    required Map<String, BeakEffectHandler> handlers,
    DateTime Function()? now,
    this.leaseDuration = const Duration(minutes: 2),
    this.retryDelay = const Duration(seconds: 10),
    this.maxAttempts = 8,
    this.table = BeakOutboxTable.beak,
  }) : handlers = Map.unmodifiable(handlers),
       _now = now ?? DateTime.now {
    _requireRetryPolicy(
      maxAttempts: maxAttempts,
      leaseDuration: leaseDuration,
      retryDelay: retryDelay,
    );
  }

  /// Shared durable database.
  final DatabaseAdapter adapter;

  /// Registered providers, keyed by effect kind.
  final Map<String, BeakEffectHandler> handlers;

  /// Claim timeout. Providers must still deduplicate concurrent late attempts.
  final Duration leaseDuration;

  /// Base retry delay, multiplied by attempt number.
  final Duration retryDelay;

  /// Failed deliveries stop retrying after this count.
  final int maxAttempts;

  /// The outbox this worker drains.
  final BeakOutboxTable table;
  final DateTime Function() _now;
  bool _running = false;

  /// Attempts at most [limit] eligible effects; returns acknowledged deliveries.
  /// Concurrent calls on this worker coalesce. Competing workers claim with CAS.
  ///
  /// A row missing the columns a claim compares is corruption — only
  /// [BeakOutbox.enqueue] writes this table — so the drain never claims it
  /// blindly. It marks the row `failed` with the error `malformedRow`, which
  /// later drains skip, delivers every other candidate, and then throws a
  /// [BeakConfigurationException] naming the rows it set aside. A row whose
  /// id is not text cannot be marked, so it is named again on every drain,
  /// still without holding up the rest.
  ///
  /// A payload that does not decode fails only its own effect, which is
  /// retried and eventually marked failed like any provider failure.
  Future<int> drain({int limit = 100}) async {
    _requireDrainLimit(limit);
    if (_running) return 0;
    _running = true;
    try {
      final now = _now().millisecondsSinceEpoch;
      final candidates = await adapter.select(
        QueryDescriptor(
          table: table.table,
          // Grouped: SQL binds AND tighter than OR, so an ungrouped `OR`
          // would make every pending entry due on every scan.
          where: StringField(table.statusColumn)
              .eq('pending')
              .or(StringField(table.statusColumn).eq('running'))
              .group()
              .and(ComparableField<int>(table.availableAtColumn).lte(now)),
          limit: limit,
        ),
      );
      var delivered = 0;
      final malformed = <Object?>[];
      for (final row in candidates) {
        final _PendingEffect? pending = _PendingEffect.parse(row, table);
        if (pending == null) {
          malformed.add(row[table.idColumn]);
          await _setAside(row);
          continue;
        }
        // --8<-- [start:outboxClaim]
        final lease = generateUuidV4();
        final attempt = pending.attempt + 1;
        final claimed = await adapter.update(
          UpdateDescriptor(
            table: table.table,
            where: StringField(table.idColumn)
                .eq(pending.key)
                .and(StringField(table.statusColumn).eq(pending.status))
                .and(StringField(table.leaseColumn).eq(pending.lease))
                .and(
                  ComparableField<int>(
                    table.availableAtColumn,
                  ).eq(pending.availableAtInMilliseconds),
                ),
            values: {
              table.statusColumn: 'running',
              table.leaseColumn: lease,
              table.attemptColumn: attempt,
              table.availableAtColumn: now + leaseDuration.inMilliseconds,
            },
          ),
        );
        if (claimed != 1) continue;
        // --8<-- [end:outboxClaim]
        final owned = StringField(
          table.idColumn,
        ).eq(pending.key).and(StringField(table.leaseColumn).eq(lease));
        try {
          final handler =
              handlers[pending.kind] ??
              (throw BeakConfigurationException(
                'No outbox handler registered for "${pending.kind}".',
              ));
          await handler(
            BeakOutboxEffect(
              key: pending.key,
              kind: pending.kind,
              attempt: attempt,
              payload: pending.decodePayload(),
            ),
          );
          delivered += await adapter.update(
            UpdateDescriptor(
              table: table.table,
              where: owned,
              values: {
                table.statusColumn: 'delivered',
                table.lastErrorColumn: '',
              },
            ),
          );
        } on Object catch (error) {
          // --8<-- [start:outboxFailure]
          // Persist a safe category, never arbitrary provider messages/secrets.
          await adapter.update(
            UpdateDescriptor(
              table: table.table,
              where: owned,
              values: {
                table.statusColumn: attempt >= maxAttempts
                    ? 'failed'
                    : 'pending',
                table.availableAtColumn:
                    _now().millisecondsSinceEpoch +
                    retryDelay.inMilliseconds * attempt,
                table.lastErrorColumn: error is BeakException
                    ? error.code
                    : 'providerFailure',
              },
            ),
          );
          // --8<-- [end:outboxFailure]
        }
      }
      if (malformed.isNotEmpty) {
        throw BeakConfigurationException(
          'Outbox rows ${malformed.map((id) => '"$id"').join(', ')} are '
          'malformed and were not delivered: every claim column must be set. '
          'Only BeakOutbox.enqueue may write ${table.table}.',
        );
      }
      return delivered;
    } finally {
      _running = false;
    }
  }

  /// Marks malformed [row] failed so later drains skip it. A row whose id is
  /// not text cannot be addressed and is left as it is.
  Future<void> _setAside(Map<String, Object?> row) async {
    if (row[table.idColumn] case final String key) {
      await adapter.update(
        UpdateDescriptor(
          table: table.table,
          where: StringField(table.idColumn).eq(key),
          values: {
            table.statusColumn: 'failed',
            table.lastErrorColumn: 'malformedRow',
          },
        ),
      );
    }
  }
}

/// Throws unless [limit] is a drain size the worker accepts.
void _requireDrainLimit(int limit) {
  if (limit < 1 || limit > 1000) {
    throw const BeakConfigurationException(
      'Outbox drain limit must be 1–1000.',
    );
  }
}

/// Throws unless the retry policy can make progress.
void _requireRetryPolicy({
  required int maxAttempts,
  required Duration leaseDuration,
  required Duration retryDelay,
}) {
  if (maxAttempts < 1 ||
      leaseDuration <= Duration.zero ||
      retryDelay < Duration.zero) {
    throw const BeakConfigurationException(
      'Invalid outbox retry configuration.',
    );
  }
}

/// How often a host drains the outbox, and with which providers.
///
/// Hand one to `BeakServerDefaults.build(outbox:)` and `BeakServeHost.serve()`
/// runs the loop: it starts draining once the server is listening and stops,
/// letting the drain in flight finish, when that server is closed. Nothing
/// else in the process needs a timer.
///
/// ```dart
/// BeakServer beakServer(BeakServerDefaults defaults) => defaults.build(
///   finalizePlan: const OrderEffects().finalize,
///   outbox: BeakOutboxSchedule(
///     interval: const Duration(seconds: 5),
///     handlers: {'receipt': sendReceipt},
///   ),
/// );
/// ```
///
/// [leaseDuration], [retryDelay] and [maxAttempts] configure the
/// [BeakOutboxWorker] it runs; [drainLimit] bounds each drain.
final class BeakOutboxSchedule {
  /// Creates a schedule running [handlers] every [interval].
  const BeakOutboxSchedule({
    required this.handlers,
    this.interval = const Duration(seconds: 1),
    this.drainLimit = 100,
    this.leaseDuration = const Duration(minutes: 2),
    this.retryDelay = const Duration(seconds: 10),
    this.maxAttempts = 8,
    this.table = BeakOutboxTable.beak,
  });

  /// Registered providers, keyed by effect kind.
  final Map<String, BeakEffectHandler> handlers;

  /// The outbox this schedule drains (default: Beak's own `_beak_outbox`).
  final BeakOutboxTable table;

  /// Pause between the start of one drain and the next.
  final Duration interval;

  /// The most effects one drain attempts; 1–1000.
  final int drainLimit;

  /// Claim timeout of the worker; see [BeakOutboxWorker.leaseDuration].
  final Duration leaseDuration;

  /// Base retry delay of the worker; see [BeakOutboxWorker.retryDelay].
  final Duration retryDelay;

  /// Attempts before an effect is marked failed; see
  /// [BeakOutboxWorker.maxAttempts].
  final int maxAttempts;

  /// The worker this schedule drives, delivering through [adapter] and
  /// reading time from [now] (default: [DateTime.now]).
  ///
  /// Throws a [BeakConfigurationException] for an invalid retry policy.
  BeakOutboxWorker worker(
    DatabaseAdapter adapter, {
    DateTime Function()? now,
  }) => BeakOutboxWorker(
    adapter: adapter,
    handlers: handlers,
    now: now,
    leaseDuration: leaseDuration,
    retryDelay: retryDelay,
    maxAttempts: maxAttempts,
    table: table,
  );

  /// Throws a [BeakConfigurationException] when this schedule cannot run:
  /// [interval] is not positive, [drainLimit] is outside 1–1000, or the retry
  /// policy is invalid.
  ///
  /// [start] checks the same. `BeakServeHost.serve()` calls this before it
  /// binds the port, so a misconfigured schedule never serves a request.
  void validate() {
    if (interval <= Duration.zero) {
      throw const BeakConfigurationException(
        'The outbox interval must be positive.',
      );
    }
    _requireDrainLimit(drainLimit);
    _requireRetryPolicy(
      maxAttempts: maxAttempts,
      leaseDuration: leaseDuration,
      retryDelay: retryDelay,
    );
  }

  /// Starts draining [adapter]'s outbox every [interval] until the returned
  /// loop is stopped.
  ///
  /// A failing drain is reported to [onError] and the schedule keeps going:
  /// an unreachable provider is retried on later drains, and a malformed row
  /// is reported once and set aside (see [BeakOutboxWorker.drain]), so
  /// neither stops delivery of the rest.
  ///
  /// Throws a [BeakConfigurationException] for a schedule [validate] rejects.
  BeakOutboxLoop start(
    DatabaseAdapter adapter, {
    required BeakUnexpectedErrorListener onError,
    DateTime Function()? now,
  }) {
    validate();
    return BeakOutboxLoop._(
      worker: worker(adapter, now: now),
      interval: interval,
      drainLimit: drainLimit,
      onError: onError,
    );
  }
}

/// A running [BeakOutboxSchedule]; [stop] ends it.
final class BeakOutboxLoop {
  BeakOutboxLoop._({
    required BeakOutboxWorker worker,
    required Duration interval,
    required int drainLimit,
    required BeakUnexpectedErrorListener onError,
  }) : _worker = worker,
       _drainLimit = drainLimit,
       _onError = onError {
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  final BeakOutboxWorker _worker;
  final int _drainLimit;
  final BeakUnexpectedErrorListener _onError;
  Timer? _timer;
  Future<void>? _inFlight;

  /// Whether the loop still schedules drains.
  bool get isRunning => _timer != null;

  /// Stops scheduling drains and completes once the drain in flight, if any,
  /// has finished, so no effect is left claimed by a stopped loop.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _inFlight;
  }

  void _tick() {
    if (_inFlight != null) return;
    _inFlight = _drainOnce().whenComplete(() => _inFlight = null);
  }

  Future<void> _drainOnce() async {
    try {
      await _worker.drain(limit: _drainLimit);
    } on Object catch (error, stackTrace) {
      _onError(error, stackTrace);
    }
  }
}

/// One queued row, decoded from the columns a claim compares.
final class _PendingEffect {
  const _PendingEffect({
    required this.key,
    required this.kind,
    required this.payload,
    required this.status,
    required this.lease,
    required this.attempt,
    required this.availableAtInMilliseconds,
  });

  /// Decodes [row], read through [table]'s column names, or `null` when a
  /// claim column is missing or mistyped.
  static _PendingEffect? parse(
    Map<String, Object?> row,
    BeakOutboxTable table,
  ) => switch ((
    row[table.idColumn],
    row[table.kindColumn],
    row[table.payloadColumn],
    row[table.statusColumn],
    row[table.leaseColumn],
    row[table.attemptColumn],
    row[table.availableAtColumn],
  )) {
    (
      final String key,
      final String kind,
      final String payload,
      final String status,
      final String lease,
      final num attempt,
      final num availableAt,
    ) =>
      _PendingEffect(
        key: key,
        kind: kind,
        payload: payload,
        status: status,
        lease: lease,
        attempt: attempt.toInt(),
        availableAtInMilliseconds: availableAt.toInt(),
      ),
    _ => null,
  };

  final String key;
  final String kind;
  final String payload;
  final String status;
  final String lease;
  final int attempt;
  final int availableAtInMilliseconds;

  /// The stored payload as a record.
  BeakRecord decodePayload() => switch (jsonDecode(payload)) {
    final Map<String, Object?> json => BeakRecord.fromJson(json),
    _ => throw BeakConfigurationException(
      'The payload of outbox effect "$key" is not a JSON object.',
    ),
  };
}
