import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

/// A tag whose name is unique and that keeps the revision stamp a version
/// precondition compares.
final class _Tag extends BeakModel {
  const _Tag();

  @override
  String get table => 'tags';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakStringColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name', unique: true),
    BeakDateTimeColumn(key: 'updated_at', label: 'Updated at'),
  ];
}

/// An adapter without transactions, over the in-memory one.
final class _PlainAdapter extends DatabaseAdapter {
  _PlainAdapter(this.inner);

  final DatabaseAdapter inner;

  @override
  Future<Map<String, Object?>?> selectOne(QueryDescriptor query) =>
      inner.selectOne(query);

  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor query) =>
      inner.select(query);

  @override
  Future<Map<String, Object?>> insert(InsertDescriptor insert) =>
      inner.insert(insert);

  @override
  Future<int> update(UpdateDescriptor update) => inner.update(update);

  @override
  Future<int> delete(DeleteDescriptor delete) => inner.delete(delete);

  @override
  Future<int> count(AggregateDescriptor query) => inner.count(query);

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final DateTime _stamp = DateTime.utc(2026, 1, 1);

BeakSavePlan _rename(String saveId, {DateTime? expectedUpdatedAt}) =>
    BeakSavePlan(
      saveId: saveId,
      root: const BeakRecordRef.existing('tags', 'blue'),
      operations: [
        BeakSaveOperation(
          id: 'rename',
          kind: BeakSaveOperationKind.update,
          target: const BeakRecordRef.existing('tags', 'blue'),
          values: BeakRecord.fromRow({'name': 'red'}),
          expectedUpdatedAt: expectedUpdatedAt,
        ),
      ],
    );

/// A save with a version precondition writes with SQL of its own, so it has to
/// bring the checks the ordinary update makes with it.
void main() {
  late BeakModelRegistry registry;
  late WormDataSource source;
  late BeakGraphCommitService service;

  setUp(() async {
    final inner = InMemoryAdapter();
    await inner.connect();
    await inner.executeSchema(
      const SchemaDescriptor.createTable(
        table: 'tags',
        columns: [
          SchemaColumn(name: 'id', type: ColumnType.text, isPrimaryKey: true),
          SchemaColumn(name: 'name', type: ColumnType.text),
          SchemaColumn(name: 'updated_at', type: ColumnType.dateTime),
        ],
      ),
    );
    await const BeakCommitReceiptsMigration().up(inner);
    registry = BeakModelRegistry()..register(const _Tag());
    source = WormDataSource(registry, adapter: _PlainAdapter(inner));
    for (final tag in [('red', 'red'), ('blue', 'blue')]) {
      await source.create(
        'tags',
        BeakRecord.fromRow({
          'id': tag.$1,
          'name': tag.$2,
          'updated_at': _stamp,
        }),
      );
    }
    service = BeakGraphCommitService(registry: registry, source: source);
  });
  tearDown(Worm.reset);

  Future<Object?> nameOf(String id) async =>
      (await source.getOne('tags', id))?['name']?.raw;

  test('without a precondition a duplicate name is refused', () async {
    final result = await service.commit(_rename('plain'));

    expect(result.mode, BeakSaveMode.staged);
    expect(result.complete, isFalse);
    expect(await nameOf('blue'), 'blue');
  });

  test('and with one it is refused the same way', () async {
    final result = await service.commit(
      _rename('conditional', expectedUpdatedAt: _stamp),
    );

    expect(result.complete, isFalse);
    expect(result.outcomes.single.status, BeakWriteOutcome.unapplied);
    expect(result.outcomes.single.error?.code, 'validation');
    expect(result.outcomes.single.error?.fieldErrors.keys, ['name']);
    expect(await nameOf('blue'), 'blue');
  });
}
