import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm_sqlite/worm_sqlite.dart';
import 'package:worm/worm.dart';

import '../../support/api_models.dart';

final class _VersionedNote extends BeakModel {
  const _VersionedNote({required this.softDeletes});
  @override
  final bool softDeletes;
  @override
  String get table => 'notes';
  @override
  String get displayColumnKey => 'title';
  @override
  List<BeakColumn> get columns => const [
    NoteColumns.id,
    NoteColumns.title,
    NoteColumns.updatedAt,
  ];
}

final class _ChangedRowsAdapter extends DatabaseAdapter
    with CurrentReadCapable {
  _ChangedRowsAdapter(this.inner);
  final DatabaseAdapter inner;
  Future<void> Function()? beforeNoop;
  Map<String, Object?>? staleSnapshot;
  @override
  Future<Map<String, Object?>?> selectOneCurrent(QueryDescriptor query) =>
      inner.selectOne(query);
  @override
  Future<int> count(AggregateDescriptor query) => inner.count(query);
  @override
  Future<Map<String, Object?>?> selectOne(QueryDescriptor query) async =>
      query.table == 'notes' && staleSnapshot != null
      ? staleSnapshot
      : await inner.selectOne(query);
  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor query) =>
      inner.select(query);
  @override
  Future<Map<String, Object?>> insert(InsertDescriptor query) =>
      inner.insert(query);
  @override
  Future<int> delete(DeleteDescriptor query) => inner.delete(query);
  @override
  Future<int> update(UpdateDescriptor query) async {
    if (query.table == 'notes' &&
        query.values.length == 1 &&
        query.values.containsKey('updated_at')) {
      final race = beforeNoop;
      beforeNoop = null;
      if (race != null) {
        staleSnapshot = await inner.selectOne(
          QueryDescriptor(table: query.table, where: query.where),
        );
        await race();
      }
      await inner.update(query);
      return 0;
    }
    return inner.update(query);
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final changedRows in [false, true]) {
    for (final softDeletes in [false, true]) {
      test(
        'SQLite revision-guarded ${softDeletes ? 'soft' : 'hard'} deletion (changed rows: $changedRows)',
        () async {
          final adapter = SqliteAdapter.memory();
          await adapter.connect();
          addTearDown(adapter.disconnect);
          await adapter.executeSchema(
            const SchemaDescriptor.createTable(
              table: 'notes',
              columns: [
                SchemaColumn(
                  name: 'id',
                  type: ColumnType.text,
                  isPrimaryKey: true,
                ),
                SchemaColumn(name: 'title', type: ColumnType.text),
                SchemaColumn(name: 'updated_at', type: ColumnType.dateTime),
                SchemaColumn(
                  name: 'deleted_at',
                  type: ColumnType.dateTime,
                  nullable: true,
                ),
              ],
            ),
          );
          await const BeakCommitReceiptsMigration().up(adapter);
          final registry = BeakModelRegistry()
            ..register(_VersionedNote(softDeletes: softDeletes));
          final changedAdapter = _ChangedRowsAdapter(adapter);
          final source = WormDataSource(
            registry,
            adapter: changedRows ? changedAdapter : adapter,
          );
          final service = BeakGraphCommitService(
            registry: registry,
            source: source,
          );
          final original = DateTime.utc(2026, 9, 28, 7, 42, 0, 123, 456);
          await adapter.insert(
            InsertDescriptor(
              table: 'notes',
              values: {
                'id': 'versioned',
                'title': 'Keep until confirmed',
                'updated_at': original,
              },
            ),
          );
          const root = BeakRecordRef.existing('notes', 'versioned');
          final unchanged = await service.commit(
            BeakSavePlan(
              saveId: 'unchanged-row',
              root: root,
              operations: [
                BeakSaveOperation(
                  id: 'unchanged',
                  kind: BeakSaveOperationKind.update,
                  target: root,
                  expectedUpdatedAt: original,
                  values: BeakRecord.fromRow({'title': 'Keep until confirmed'}),
                ),
              ],
            ),
          );
          expect(unchanged.complete, isTrue, reason: '${unchanged.toJson()}');
          expect(unchanged.rootRecord?['updated_at']?.raw, original);
          final staleNoop = await service.commit(
            BeakSavePlan(
              saveId: 'stale-unchanged-row',
              root: root,
              operations: [
                BeakSaveOperation(
                  id: 'unchanged',
                  kind: BeakSaveOperationKind.update,
                  target: root,
                  expectedUpdatedAt: original.subtract(
                    const Duration(milliseconds: 1),
                  ),
                  values: BeakRecord.fromRow({'title': 'Keep until confirmed'}),
                ),
              ],
            ),
          );
          expect(staleNoop.complete, isFalse);
          expect(staleNoop.outcomes.single.error?.code, 'conflict');
          if (changedRows) {
            changedAdapter.beforeNoop = () async {
              await adapter.update(
                UpdateDescriptor(
                  table: 'notes',
                  values: {
                    'title': 'Concurrent edit',
                    'updated_at': original.add(const Duration(milliseconds: 1)),
                  },
                  where: const Field<String>('id').eq('versioned'),
                ),
              );
            };
            final racingNoop = await service.commit(
              BeakSavePlan(
                saveId: 'racing-noop',
                root: root,
                operations: [
                  BeakSaveOperation(
                    id: 'unchanged',
                    kind: BeakSaveOperationKind.update,
                    target: root,
                    expectedUpdatedAt: original,
                    values: BeakRecord.fromRow({
                      'title': 'Keep until confirmed',
                    }),
                  ),
                ],
              ),
            );
            expect(racingNoop.complete, isFalse);
            expect(racingNoop.outcomes.single.error?.code, 'conflict');
            expect(
              (await source.getOne('notes', 'versioned'))?['title']?.raw,
              'Keep until confirmed',
              reason:
                  'Ordinary reads still expose the old repeatable-read snapshot.',
            );
            expect(
              (await adapter.selectOne(
                QueryDescriptor(
                  table: 'notes',
                  where: const Field<String>('id').eq('versioned'),
                ),
              ))?['title'],
              'Concurrent edit',
            );
            changedAdapter.staleSnapshot = null;
            await adapter.update(
              UpdateDescriptor(
                table: 'notes',
                values: {
                  'title': 'Keep until confirmed',
                  'updated_at': original,
                },
                where: const Field<String>('id').eq('versioned'),
              ),
            );
          }
          BeakSavePlan deletion(String saveId, DateTime expected) =>
              BeakSavePlan(
                saveId: saveId,
                root: root,
                operations: [
                  BeakSaveOperation(
                    id: 'delete',
                    kind: BeakSaveOperationKind.delete,
                    target: root,
                    expectedUpdatedAt: expected,
                  ),
                ],
              );
          final stale = await service.commit(
            deletion(
              'stale-delete',
              original.subtract(const Duration(milliseconds: 1)),
            ),
          );
          expect(stale.complete, isFalse);
          expect(stale.hasUnknown, isFalse);
          expect(stale.outcomes.single.error?.code, 'conflict');
          expect(await source.getOne('notes', 'versioned'), isNotNull);
          // Browsers preserve milliseconds, while the SQL predicate must still use
          // the exact stored microsecond timestamp to prevent racing mutations.
          final plan = deletion(
            'guarded-delete',
            DateTime.fromMillisecondsSinceEpoch(
              original.millisecondsSinceEpoch,
              isUtc: true,
            ),
          );
          final deleted = await service.commit(plan);
          expect(deleted.complete, isTrue, reason: '${deleted.toJson()}');
          expect(await source.getOne('notes', 'versioned'), isNull);
          final rows = await source.query(
            const BeakQuerySpec(table: 'notes', withTrashed: true),
          );
          expect(rows.total, softDeletes ? 1 : 0);
          expect((await service.commit(plan)).toJson(), deleted.toJson());
        },
      );
    }
  }
  test(
    'SQLite stores receipts and business writes in one real transaction',
    () async {
      final adapter = SqliteAdapter.memory();
      await adapter.connect();
      addTearDown(adapter.disconnect);
      await adapter.executeSchema(apiSchema[1]);
      await const BeakCommitReceiptsMigration().up(adapter);
      final registry = BeakModelRegistry()..register(const LabelModel());
      final source = WormDataSource(registry, adapter: adapter);
      final service = BeakGraphCommitService(
        registry: registry,
        source: source,
      );
      BeakSavePlan plan(String saveId, {bool invalid = false}) => BeakSavePlan(
        saveId: saveId,
        root: const BeakRecordRef.draft('labels', 'one'),
        operations: [
          BeakSaveOperation(
            id: 'one',
            kind: BeakSaveOperationKind.create,
            target: const BeakRecordRef.draft('labels', 'one'),
            values: BeakRecord.fromRow({'name': 'One'}),
          ),
          BeakSaveOperation(
            id: 'two',
            kind: BeakSaveOperationKind.create,
            target: const BeakRecordRef.draft('labels', 'two'),
            values: BeakRecord.fromRow({'name': invalid ? null : 'Two'}),
          ),
        ],
      );
      expect(
        (await service.commit(plan('failed', invalid: true))).complete,
        isFalse,
      );
      expect(
        (await source.query(const BeakQuerySpec(table: 'labels'))).total,
        0,
      );
      final saved = await service.commit(plan('saved'));
      expect(saved.complete, isTrue);
      final restarted = BeakGraphCommitService(
        registry: registry,
        source: source,
      );
      expect((await restarted.recover('saved')).toJson(), saved.toJson());
      expect((await restarted.commit(plan('saved'))).toJson(), saved.toJson());
      expect(
        (await source.query(const BeakQuerySpec(table: 'labels'))).total,
        2,
      );
    },
  );
}
