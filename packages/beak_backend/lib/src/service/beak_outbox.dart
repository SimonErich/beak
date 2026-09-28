import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:worm/worm.dart';

import '../common/uuid_v4.dart';

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
  static Future<void> enqueue(
    DatabaseAdapter transaction, {
    required String key,
    required String kind,
    required BeakRecord payload,
  }) async {
    if (key.isEmpty || kind.isEmpty) {
      throw const BeakConfigurationException(
        'Outbox identity and kind are required.',
      );
    }
    final json = jsonEncode(_canonical(payload.toJson()));
    final existing = await transaction.selectOne(
      QueryDescriptor(
        table: BeakOutboxMigration.table,
        where: const StringField('id').eq(key),
      ),
    );
    if (existing != null) {
      if (existing['kind'] != kind || existing['payload'] != json) {
        throw const BeakConflictException(
          'Effect identity was reused with different content.',
        );
      }
      return;
    }
    await transaction.insert(
      InsertDescriptor(
        table: BeakOutboxMigration.table,
        values: {
          'id': key,
          'kind': kind,
          'payload': json,
          'status': 'pending',
          'attempt': 0,
          'available_at': 0,
          'lease': '',
          'last_error': '',
        },
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
  }) : handlers = Map.unmodifiable(handlers),
       _now = now ?? DateTime.now {
    if (maxAttempts < 1 ||
        leaseDuration <= Duration.zero ||
        retryDelay < Duration.zero) {
      throw const BeakConfigurationException(
        'Invalid outbox retry configuration.',
      );
    }
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
  final DateTime Function() _now;
  bool _running = false;

  /// Attempts at most [limit] eligible effects; returns acknowledged deliveries.
  /// Concurrent calls on this worker coalesce. Competing workers claim with CAS.
  Future<int> drain({int limit = 100}) async {
    if (limit < 1 || limit > 1000) {
      throw const BeakConfigurationException(
        'Outbox drain limit must be 1–1000.',
      );
    }
    if (_running) return 0;
    _running = true;
    try {
      final now = _now().millisecondsSinceEpoch;
      final candidates = await adapter.select(
        QueryDescriptor(
          table: BeakOutboxMigration.table,
          where: const StringField('status')
              .eq('pending')
              .or(const StringField('status').eq('running'))
              .and(const ComparableField<int>('available_at').lte(now)),
          limit: limit,
        ),
      );
      var delivered = 0;
      for (final row in candidates) {
        final key = row['id']! as String;
        final lease = generateUuidV4();
        final attempt = (row['attempt']! as num).toInt() + 1;
        final claimed = await adapter.update(
          UpdateDescriptor(
            table: BeakOutboxMigration.table,
            where: const StringField('id')
                .eq(key)
                .and(const StringField('status').eq(row['status']! as String))
                .and(const StringField('lease').eq(row['lease']! as String))
                .and(
                  const ComparableField<int>(
                    'available_at',
                  ).eq((row['available_at']! as num).toInt()),
                ),
            values: {
              'status': 'running',
              'lease': lease,
              'attempt': attempt,
              'available_at': now + leaseDuration.inMilliseconds,
            },
          ),
        );
        if (claimed != 1) continue;
        final owned = const StringField(
          'id',
        ).eq(key).and(const StringField('lease').eq(lease));
        try {
          final kind = row['kind']! as String;
          final handler = handlers[kind];
          if (handler == null) {
            throw BeakConfigurationException(
              'No outbox handler registered for "$kind".',
            );
          }
          await handler(
            BeakOutboxEffect(
              key: key,
              kind: kind,
              attempt: attempt,
              payload: BeakRecord.fromJson(
                (jsonDecode(row['payload']! as String) as Map)
                    .cast<String, Object?>(),
              ),
            ),
          );
          delivered += await adapter.update(
            UpdateDescriptor(
              table: BeakOutboxMigration.table,
              where: owned,
              values: {'status': 'delivered', 'last_error': ''},
            ),
          );
        } on Object catch (error) {
          // Persist a safe category, never arbitrary provider messages/secrets.
          await adapter.update(
            UpdateDescriptor(
              table: BeakOutboxMigration.table,
              where: owned,
              values: {
                'status': attempt >= maxAttempts ? 'failed' : 'pending',
                'available_at':
                    _now().millisecondsSinceEpoch +
                    retryDelay.inMilliseconds * attempt,
                'last_error': error is BeakException
                    ? error.code
                    : 'providerFailure',
              },
            ),
          );
        }
      }
      return delivered;
    } finally {
      _running = false;
    }
  }
}
