import 'package:beak_backend/beak_backend.dart';
import 'package:beak_backend/src/service/beak_resource_service.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

final class _TimedModel extends BeakModel {
  const _TimedModel();
  @override
  String get table => 'timed_records';
  @override
  String get displayColumnKey => 'title';
  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'ID'),
    BeakStringColumn(key: 'title', label: 'Title', rules: [BeakRequired()]),
    BeakDateTimeColumn(key: 'created_at', label: 'Created'),
    BeakDateTimeColumn(key: 'updated_at', label: 'Updated'),
  ];
}

void main() {
  late SqliteAdapter adapter;
  late WormDataSource source;
  late BeakGraphCommitService graph;
  final instant = DateTime.utc(2026, 9, 28, 7, 42, 0, 123, 456);
  final registry = BeakModelRegistry()..register(const _TimedModel());
  DateTime revision(BeakRecord record) =>
      (record['updated_at']! as BeakDateTimeValue).value;
  DateTime web(DateTime value) => DateTime.fromMillisecondsSinceEpoch(
    value.millisecondsSinceEpoch,
    isUtc: true,
  );
  BeakSavePlan edit(String saveId, DateTime expected, String title) =>
      BeakSavePlan(
        saveId: saveId,
        root: const BeakRecordRef.existing('timed_records', 'record'),
        operations: [
          BeakSaveOperation(
            id: 'edit',
            kind: BeakSaveOperationKind.update,
            target: const BeakRecordRef.existing('timed_records', 'record'),
            values: BeakRecord.fromRow({'title': title}),
            expectedUpdatedAt: expected,
          ),
        ],
      );

  setUp(() async {
    adapter = SqliteAdapter.memory();
    await adapter.connect();
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(
        table: 'timed_records',
        columns: [
          SchemaColumn(name: 'id', type: ColumnType.text, isPrimaryKey: true),
          SchemaColumn(name: 'title', type: ColumnType.text),
          SchemaColumn(name: 'created_at', type: ColumnType.dateTime),
          SchemaColumn(name: 'updated_at', type: ColumnType.dateTime),
        ],
      ),
    );
    await const BeakCommitReceiptsMigration().up(adapter);
    source = WormDataSource(registry, adapter: adapter);
    graph = BeakGraphCommitService(
      registry: registry,
      source: source,
      now: () => instant,
    );
  });
  tearDown(() => adapter.disconnect());

  test(
    'web round trips retain revisions with a frozen sub-millisecond clock',
    () async {
      final created = await graph.commit(
        BeakSavePlan(
          saveId: 'create',
          root: const BeakRecordRef.draft('timed_records', 'record'),
          operations: [
            BeakSaveOperation(
              id: 'create',
              kind: BeakSaveOperationKind.create,
              target: const BeakRecordRef.draft('timed_records', 'record'),
              values: BeakRecord.fromRow({'id': 'record', 'title': 'First'}),
            ),
          ],
        ),
      );
      expect(created.complete, isTrue);
      final first = revision(created.outcomes.single.record!);
      expect(first, web(instant));
      final saved = await graph.commit(edit('edit-one', web(first), 'Second'));
      expect(saved.complete, isTrue);
      final second = revision(saved.outcomes.single.record!);
      expect(second.difference(first), const Duration(milliseconds: 1));
      final stale = await graph.commit(
        edit('stale', web(first), 'Lost update'),
      );
      expect(stale.complete, isFalse);
      expect(stale.outcomes.single.error?.message, contains('changed'));
      expect(
        (await source.getOne('timed_records', 'record'))!['title']?.raw,
        'Second',
      );
      final third = await graph.commit(edit('edit-two', web(second), 'Third'));
      expect(third.complete, isTrue);
      expect(
        revision(third.outcomes.single.record!).difference(second),
        const Duration(milliseconds: 1),
      );
    },
  );

  test(
    'legacy microseconds accept only exact or truncated browser revisions',
    () async {
      await source.create(
        'timed_records',
        BeakRecord.fromRow({
          'id': 'record',
          'title': 'Legacy',
          'created_at': instant,
          'updated_at': instant,
        }),
      );
      final rejected = await graph.commit(
        edit(
          'wrong-microsecond',
          instant.subtract(const Duration(microseconds: 1)),
          'Wrong',
        ),
      );
      expect(rejected.complete, isFalse);
      final saved = await graph.commit(
        edit('legacy-web', web(instant), 'Upgraded'),
      );
      expect(saved.complete, isTrue);
      expect(revision(saved.outcomes.single.record!).microsecond, 0);
      expect(
        revision(saved.outcomes.single.record!),
        web(instant).add(const Duration(milliseconds: 1)),
      );
      expect(
        (await graph.commit(
          edit('legacy-stale', web(instant), 'Wrong'),
        )).complete,
        isFalse,
      );
    },
  );

  test(
    'ordinary resource updates advance within the same millisecond',
    () async {
      final service = BeakResourceService(
        const _TimedModel(),
        source,
        now: () => instant,
      );
      final first = await service.create(
        BeakRecord.fromRow({'id': 'record', 'title': 'First'}),
      );
      final second = await service.update(
        'record',
        BeakRecord.fromRow({'title': 'Second'}),
        expectedUpdatedAt: web(revision(first)),
      );
      expect(
        revision(second).difference(revision(first)),
        const Duration(milliseconds: 1),
      );
      await expectLater(
        service.update(
          'record',
          BeakRecord.fromRow({'title': 'Stale'}),
          expectedUpdatedAt: web(revision(first)),
        ),
        throwsA(isA<BeakConflictException>()),
      );
      final third = await service.update(
        'record',
        BeakRecord.fromRow({'title': 'Third'}),
      );
      expect(
        revision(third).difference(revision(second)),
        const Duration(milliseconds: 1),
      );
    },
  );
}
