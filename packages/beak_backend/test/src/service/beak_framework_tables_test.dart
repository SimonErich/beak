import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

/// The receipt table a host such as Serverpod owns: a serial `id` the
/// database fills, a unique `receiptKey`, camelCase columns, and a
/// `createdAt` the service never writes.
const BeakFrameworkTables _hostTables = BeakFrameworkTables(
  receipts: BeakCommitReceiptTable(
    table: 'beak_commit_receipt',
    keyColumn: 'receiptKey',
    requestHashColumn: 'requestHash',
    requestJsonColumn: 'requestJson',
    resultJsonColumn: 'resultJson',
    createdAtColumn: 'createdAt',
  ),
);

BeakSavePlan _plan(String saveId, {String title = 'A note'}) => BeakSavePlan(
  saveId: saveId,
  root: const BeakRecordRef.draft('notes', 'note'),
  operations: [
    BeakSaveOperation(
      id: 'note',
      kind: BeakSaveOperationKind.create,
      target: const BeakRecordRef.draft('notes', 'note'),
      values: BeakRecord.fromRow({'title': title}),
    ),
  ],
);

void main() {
  late InMemoryAdapter adapter;
  late WormDataSource source;

  BeakGraphCommitService service() => BeakGraphCommitService(
    registry: createApiRegistry(),
    source: source,
    receipts: _hostTables.receipts,
  );

  setUp(() async {
    adapter = await createApiTestDatabase();
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(
        table: 'beak_commit_receipt',
        columns: [
          SchemaColumn(
            name: 'id',
            type: ColumnType.integer,
            isPrimaryKey: true,
            autoIncrement: true,
          ),
          SchemaColumn(name: 'receiptKey', type: ColumnType.text, unique: true),
          SchemaColumn(name: 'requestHash', type: ColumnType.text),
          SchemaColumn(name: 'requestJson', type: ColumnType.text),
          SchemaColumn(name: 'resultJson', type: ColumnType.text),
          SchemaColumn(name: 'createdAt', type: ColumnType.dateTime),
        ],
      ),
    );
    source = WormDataSource(createApiRegistry(), adapter: adapter);
  });
  tearDown(Worm.reset);

  test('Beak owns its receipt table unless a host maps another', () {
    expect(
      BeakFrameworkTables.beak.receipts.table,
      BeakCommitReceiptsMigration.table,
    );
    expect(BeakFrameworkTables.beak.receipts.columns, {
      'id',
      'request_hash',
      'request_json',
      'result_json',
    });
    expect(_hostTables.receipts.columns, {
      'receiptKey',
      'requestHash',
      'requestJson',
      'resultJson',
    });
    expect(_hostTables.receipts.createdAtColumn, 'createdAt');
    expect(BeakFrameworkTables.beak.receipts.createdAtColumn, isNull);
  });

  test('a commit stores its receipt in the host table', () async {
    final result = await service().commit(_plan('save-1'));

    expect(result.complete, isTrue);
    final receipts = await adapter.select(
      const QueryDescriptor(table: 'beak_commit_receipt'),
    );
    expect(receipts, hasLength(1));
    expect(receipts.single['receiptKey'], isNotEmpty);
    expect(receipts.single['requestHash'], isNotEmpty);
    expect(receipts.single['requestJson'], contains('"saveId":"save-1"'));
    expect(receipts.single['resultJson'], contains('"saveId":"save-1"'));
    expect(
      () => adapter.select(
        const QueryDescriptor(table: BeakCommitReceiptsMigration.table),
      ),
      throwsA(anything),
      reason: 'Beak\'s own receipt table is never created or touched',
    );
  });

  test('replay and recovery read the host table', () async {
    final first = await service().commit(_plan('save-1'));
    final replay = await service().commit(_plan('save-1'));
    final recovered = await service().recover('save-1');

    expect(replay.toJson(), first.toJson());
    expect(recovered.toJson(), first.toJson());
    expect(
      await adapter.select(const QueryDescriptor(table: 'notes')),
      hasLength(1),
    );
  });

  test('a reused save id with other content is a conflict', () async {
    await service().commit(_plan('save-1'));

    await expectLater(
      service().commit(_plan('save-1', title: 'Another')),
      throwsA(isA<BeakConflictException>()),
    );
  });

  group('pruneReceipts', () {
    Future<void> ageReceipt(String saveId, DateTime createdAt) async {
      final rows = await adapter.select(
        const QueryDescriptor(table: 'beak_commit_receipt'),
      );
      final row = rows.firstWhere(
        (row) => '${row['requestJson']}'.contains('"saveId":"$saveId"'),
      );
      await adapter.update(
        UpdateDescriptor(
          table: 'beak_commit_receipt',
          where: const StringField('receiptKey').eq('${row['receiptKey']}'),
          values: {'createdAt': createdAt},
        ),
      );
    }

    test('removes receipts older than the age and keeps the rest', () async {
      final now = DateTime.utc(2026, 9, 28);
      await service().commit(_plan('old'));
      await service().commit(_plan('recent'));
      await ageReceipt('old', now.subtract(const Duration(days: 90)));
      await ageReceipt('recent', now.subtract(const Duration(days: 1)));

      final removed = await service().pruneReceipts(
        olderThan: const Duration(days: 30),
        now: () => now,
      );

      expect(removed, 1);
      await expectLater(
        service().recover('old'),
        throwsA(isA<BeakNotFoundException>()),
      );
      expect((await service().recover('recent')).complete, isTrue);
    });

    test('a pruned save id is a new save', () async {
      final now = DateTime.utc(2026, 9, 28);
      await service().commit(_plan('again'));
      await ageReceipt('again', now.subtract(const Duration(days: 90)));
      await service().pruneReceipts(
        olderThan: const Duration(days: 30),
        now: () => now,
      );

      await service().commit(_plan('again'));

      expect(
        await adapter.select(const QueryDescriptor(table: 'notes')),
        hasLength(2),
        reason: 'the receipt that made the second commit a replay is gone',
      );
    });

    test('Beak\'s own receipt table keeps no timestamp to prune by', () async {
      await const BeakCommitReceiptsMigration().up(adapter);
      final ownService = BeakGraphCommitService(
        registry: createApiRegistry(),
        source: source,
      );

      await expectLater(
        ownService.pruneReceipts(olderThan: const Duration(days: 30)),
        throwsA(
          isA<BeakConfigurationException>().having(
            (error) => error.message,
            'message',
            contains('createdAtColumn'),
          ),
        ),
      );
    });

    test('a negative age is rejected', () {
      expect(
        () => service().pruneReceipts(olderThan: const Duration(days: -1)),
        throwsA(isA<BeakConfigurationException>()),
      );
    });
  });
}
