import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

/// The table a Serverpod host generates for the outbox: camelCase columns and
/// a serial id the database fills.
const BeakOutboxTable _hostOutbox = BeakOutboxTable(
  table: 'beak_outbox',
  idColumn: 'effectKey',
  kindColumn: 'effectKind',
  payloadColumn: 'payloadJson',
  statusColumn: 'deliveryStatus',
  attemptColumn: 'attemptCount',
  availableAtColumn: 'availableAt',
  leaseColumn: 'leaseToken',
  lastErrorColumn: 'lastError',
);

void main() {
  late InMemoryAdapter adapter;
  var now = DateTime.utc(2026, 9, 28);

  setUp(() async {
    adapter = InMemoryAdapter();
    await adapter.connect();
    now = DateTime.utc(2026, 9, 28);
  });
  tearDown(() => adapter.close());

  Future<void> createHostTable() => adapter.executeSchema(
    const SchemaDescriptor.createTable(
      table: 'beak_outbox',
      columns: [
        SchemaColumn(
          name: 'id',
          type: ColumnType.integer,
          isPrimaryKey: true,
          autoIncrement: true,
        ),
        SchemaColumn(name: 'effectKey', type: ColumnType.text, unique: true),
        SchemaColumn(name: 'effectKind', type: ColumnType.text),
        SchemaColumn(name: 'payloadJson', type: ColumnType.text),
        SchemaColumn(name: 'deliveryStatus', type: ColumnType.text),
        SchemaColumn(name: 'attemptCount', type: ColumnType.integer),
        SchemaColumn(name: 'availableAt', type: ColumnType.integer),
        SchemaColumn(name: 'leaseToken', type: ColumnType.text),
        SchemaColumn(name: 'lastError', type: ColumnType.text),
      ],
    ),
  );

  test('Beak owns its outbox table unless a host maps another', () {
    expect(BeakFrameworkTables.beak.outbox.table, BeakOutboxMigration.table);
    expect(BeakFrameworkTables.beak.outbox.columns, {
      'id',
      'kind',
      'payload',
      'status',
      'attempt',
      'available_at',
      'lease',
      'last_error',
    });
    expect(const BeakOutboxTable(table: 'mine').idColumn, 'id');
  });

  group('a host-owned outbox table', () {
    setUp(createHostTable);

    Future<void> enqueue(String key) => BeakOutbox.enqueue(
      adapter,
      key: key,
      kind: 'email',
      payload: BeakRecord.fromRow({'to': 'a@example.com'}),
      table: _hostOutbox,
    );

    test('receives the row under its own column names', () async {
      await enqueue('order:1');

      final rows = await adapter.select(
        const QueryDescriptor(table: 'beak_outbox'),
      );

      expect(rows, hasLength(1));
      expect(rows.single['effectKey'], 'order:1');
      expect(rows.single['effectKind'], 'email');
      expect(rows.single['deliveryStatus'], 'pending');
      expect(rows.single['leaseToken'], '');
    });

    test(
      'a repeated key stays a no-op and a changed one is rejected',
      () async {
        await enqueue('order:1');
        await enqueue('order:1');

        expect(
          await adapter.count(
            const AggregateDescriptor.count(table: 'beak_outbox'),
          ),
          1,
        );
        await expectLater(
          BeakOutbox.enqueue(
            adapter,
            key: 'order:1',
            kind: 'email',
            payload: BeakRecord.fromRow({'to': 'b@example.com'}),
            table: _hostOutbox,
          ),
          throwsA(isA<BeakConflictException>()),
        );
      },
    );

    test('a worker built for the table delivers and acknowledges', () async {
      await enqueue('order:1');
      final delivered = <String>[];
      final worker = BeakOutboxWorker(
        adapter: adapter,
        table: _hostOutbox,
        now: () => now,
        handlers: {'email': (effect) async => delivered.add(effect.key)},
      );

      expect(await worker.drain(), 1);
      expect(await worker.drain(), 0);

      expect(delivered, ['order:1']);
      final row = await adapter.selectOne(
        const QueryDescriptor(table: 'beak_outbox'),
      );
      expect(row?['deliveryStatus'], 'delivered');
    });

    test('a schedule carries the table to the worker it builds', () async {
      await enqueue('order:1');
      final delivered = <String>[];
      final schedule = BeakOutboxSchedule(
        table: _hostOutbox,
        handlers: {'email': (effect) async => delivered.add(effect.key)},
      );

      expect(await schedule.worker(adapter, now: () => now).drain(), 1);
      expect(delivered, ['order:1']);
    });

    test(
      'a retry and a terminal failure are written to the mapped columns',
      () async {
        await enqueue('order:1');
        final worker = BeakOutboxWorker(
          adapter: adapter,
          table: _hostOutbox,
          now: () => now,
          maxAttempts: 1,
          handlers: {'email': (_) async => throw StateError('provider down')},
        );

        await worker.drain();

        final row = await adapter.selectOne(
          const QueryDescriptor(table: 'beak_outbox'),
        );
        expect(row?['deliveryStatus'], 'failed');
        expect(row?['lastError'], 'providerFailure');
        expect(row?['attemptCount'], 1);
      },
    );

    test('a row missing a mapped column is set aside, not claimed', () async {
      await adapter.insert(
        const InsertDescriptor(
          table: 'beak_outbox',
          values: {
            'effectKey': 'broken',
            'effectKind': 'email',
            'payloadJson': '{}',
            'deliveryStatus': 'pending',
            'attemptCount': 0,
            'availableAt': 0,
            'leaseToken': null,
            'lastError': '',
          },
        ),
      );
      final worker = BeakOutboxWorker(
        adapter: adapter,
        table: _hostOutbox,
        now: () => now,
        handlers: {'email': (_) async {}},
      );

      await expectLater(
        worker.drain(),
        throwsA(
          isA<BeakConfigurationException>().having(
            (error) => error.message,
            'message',
            contains('beak_outbox'),
          ),
        ),
      );
      final row = await adapter.selectOne(
        const QueryDescriptor(table: 'beak_outbox'),
      );
      expect(row?['deliveryStatus'], 'failed');
      expect(row?['lastError'], 'malformedRow');
    });
  });

  group('prune', () {
    setUp(() => const BeakOutboxMigration().up(adapter));

    Future<void> row(String id, String status, DateTime settledAt) =>
        adapter.insert(
          InsertDescriptor(
            table: BeakOutboxMigration.table,
            values: {
              'id': id,
              'kind': 'email',
              'payload': '{}',
              'status': status,
              'attempt': 1,
              'available_at': settledAt.millisecondsSinceEpoch,
              'lease': '',
              'last_error': '',
            },
          ),
        );

    Future<List<Object?>> remaining() async => [
      for (final r in await adapter.select(
        const QueryDescriptor(table: BeakOutboxMigration.table),
      ))
        r['id'],
    ]..sort((a, b) => '$a'.compareTo('$b'));

    test(
      'removes delivered rows older than the age and reports the count',
      () async {
        await row(
          'old-delivered',
          'delivered',
          now.subtract(const Duration(days: 40)),
        );
        await row(
          'new-delivered',
          'delivered',
          now.subtract(const Duration(days: 2)),
        );
        await row(
          'old-pending',
          'pending',
          now.subtract(const Duration(days: 40)),
        );
        await row(
          'old-running',
          'running',
          now.subtract(const Duration(days: 40)),
        );
        await row(
          'old-failed',
          'failed',
          now.subtract(const Duration(days: 40)),
        );

        final removed = await BeakOutbox.prune(
          adapter,
          olderThan: const Duration(days: 30),
          now: () => now,
        );

        expect(removed, 1);
        expect(await remaining(), [
          'new-delivered',
          'old-failed',
          'old-pending',
          'old-running',
        ]);
      },
    );

    test('failed rows go too when asked', () async {
      await row(
        'old-delivered',
        'delivered',
        now.subtract(const Duration(days: 40)),
      );
      await row('old-failed', 'failed', now.subtract(const Duration(days: 40)));
      await row('new-failed', 'failed', now.subtract(const Duration(days: 1)));
      await row(
        'old-pending',
        'pending',
        now.subtract(const Duration(days: 40)),
      );

      final removed = await BeakOutbox.prune(
        adapter,
        olderThan: const Duration(days: 30),
        includeFailed: true,
        now: () => now,
      );

      expect(removed, 2);
      expect(await remaining(), ['new-failed', 'old-pending']);
    });

    test('a pruned key can be enqueued again', () async {
      await row('order:1', 'delivered', now.subtract(const Duration(days: 40)));
      await BeakOutbox.prune(
        adapter,
        olderThan: const Duration(days: 30),
        now: () => now,
      );

      await BeakOutbox.enqueue(
        adapter,
        key: 'order:1',
        kind: 'email',
        payload: BeakRecord.fromRow({'again': true}),
      );

      final fresh = await adapter.selectOne(
        const QueryDescriptor(table: BeakOutboxMigration.table),
      );
      expect(fresh?['status'], 'pending');
    });

    test('rejects a negative age', () {
      expect(
        () => BeakOutbox.prune(adapter, olderThan: const Duration(seconds: -1)),
        throwsA(isA<BeakConfigurationException>()),
      );
    });

    test('prunes a host-owned table through its column names', () async {
      await createHostOutbox(adapter);
      await adapter.insert(
        InsertDescriptor(
          table: 'beak_outbox',
          values: {
            'effectKey': 'old',
            'effectKind': 'email',
            'payloadJson': '{}',
            'deliveryStatus': 'delivered',
            'attemptCount': 1,
            'availableAt': now
                .subtract(const Duration(days: 40))
                .millisecondsSinceEpoch,
            'leaseToken': '',
            'lastError': '',
          },
        ),
      );

      final removed = await BeakOutbox.prune(
        adapter,
        olderThan: const Duration(days: 30),
        table: _hostOutbox,
        now: () => now,
      );

      expect(removed, 1);
    });
  });
}

Future<void> createHostOutbox(InMemoryAdapter adapter) => adapter.executeSchema(
  const SchemaDescriptor.createTable(
    table: 'beak_outbox',
    columns: [
      SchemaColumn(
        name: 'effectKey',
        type: ColumnType.text,
        isPrimaryKey: true,
      ),
      SchemaColumn(name: 'effectKind', type: ColumnType.text),
      SchemaColumn(name: 'payloadJson', type: ColumnType.text),
      SchemaColumn(name: 'deliveryStatus', type: ColumnType.text),
      SchemaColumn(name: 'attemptCount', type: ColumnType.integer),
      SchemaColumn(name: 'availableAt', type: ColumnType.integer),
      SchemaColumn(name: 'leaseToken', type: ColumnType.text),
      SchemaColumn(name: 'lastError', type: ColumnType.text),
    ],
  ),
);
