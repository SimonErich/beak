import 'package:beak_backend/beak_backend.dart';
import 'package:beak_core/beak_core.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';

abstract final class _NodeColumns {
  static const id = BeakIntColumn(key: 'id', label: 'Id');
  static const parentId = BeakIntColumn(key: 'parent_id', label: 'Parent');
  static const name = BeakStringColumn(key: 'name', label: 'Name');
  static const values = [id, parentId, name];
}

final class NodeModel extends BeakModel {
  const NodeModel();

  static const parentRelation = BeakBelongsTo(
    key: 'parent',
    label: 'Parent',
    relatedTable: 'nodes',
    displayColumnKey: 'name',
    foreignKey: 'parent_id',
  );
  static const childrenRelation = BeakHasMany(
    key: 'children',
    label: 'Children',
    relatedTable: 'nodes',
    displayColumnKey: 'name',
    foreignKey: 'parent_id',
  );
  static const parent = BeakToOneField(
    model: NodeModel(),
    relation: parentRelation,
    target: NodeModel(),
  );
  static const children = BeakToManyField(
    model: NodeModel(),
    relation: childrenRelation,
    target: NodeModel(),
  );
  static const name = BeakScalarField<String>(
    model: NodeModel(),
    column: _NodeColumns.name,
  );

  @override
  String get table => 'nodes';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => _NodeColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    parentRelation,
    childrenRelation,
  ];
}

final class _RefModel extends BeakModel {
  const _RefModel();

  static const nodeId = BeakScalarField<int>(
    model: _RefModel(),
    column: BeakIntColumn(key: 'node_id', label: 'Node'),
  );

  @override
  String get table => 'refs';

  @override
  String get displayColumnKey => 'label';

  @override
  List<BeakColumn> get columns => const [
    BeakIntColumn(key: 'id', label: 'Id'),
    BeakIntColumn(key: 'node_id', label: 'Node'),
  ];
}

BeakSavePlan _update(int id, Map<String, Object?> row) => BeakSavePlan(
  saveId: 'save-$id',
  root: BeakRecordRef.existing('nodes', id),
  operations: [
    BeakSaveOperation(
      id: 'edit',
      kind: BeakSaveOperationKind.update,
      target: BeakRecordRef.existing('nodes', id),
      values: BeakRecord.fromRow(row),
    ),
  ],
);

BeakSavePlan _delete(int id) => BeakSavePlan(
  saveId: 'delete-$id',
  root: BeakRecordRef.existing('nodes', id),
  operations: [
    BeakSaveOperation(
      id: 'remove',
      kind: BeakSaveOperationKind.delete,
      target: BeakRecordRef.existing('nodes', id),
    ),
  ],
);

void main() {
  late InMemoryAdapter adapter;
  late WormDataSource source;
  late BeakModelRegistry registry;

  setUp(() async {
    adapter = InMemoryAdapter();
    await adapter.connect();
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(
        table: 'nodes',
        columns: [
          SchemaColumn(
            name: 'id',
            type: ColumnType.integer,
            isPrimaryKey: true,
          ),
          SchemaColumn(
            name: 'parent_id',
            type: ColumnType.integer,
            nullable: true,
          ),
          SchemaColumn(name: 'name', type: ColumnType.text),
        ],
      ),
    );
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(
        table: 'refs',
        columns: [
          SchemaColumn(
            name: 'id',
            type: ColumnType.integer,
            isPrimaryKey: true,
          ),
          SchemaColumn(
            name: 'node_id',
            type: ColumnType.integer,
            nullable: true,
          ),
        ],
      ),
    );
    registry = BeakModelRegistry()
      ..register(const NodeModel())
      ..register(const _RefModel());
    source = WormDataSource(registry, adapter: adapter);
  });

  Future<void> insert(Map<String, Object?> row) async {
    await adapter.insert(InsertDescriptor(table: 'nodes', values: row));
  }

  test('a structural change is recognised, a name edit is not', () {
    final rule = BeakTreeRule(
      parent: NodeModel.parent,
      children: NodeModel.children,
    );

    expect(rule.changes(_update(1, {'name': 'Leaf'})), isFalse);
    expect(rule.changes(_update(1, {'parent_id': 2})), isTrue);
    expect(rule.changes(_delete(1)), isTrue);
  });

  test('a record cannot become its own parent', () async {
    await insert({'id': 1, 'name': 'Root'});
    final rule = BeakTreeRule(
      parent: NodeModel.parent,
      children: NodeModel.children,
    );

    await expectLater(
      applyBeakTreeRules(
        [rule],
        _update(1, {'parent_id': 1}),
        source,
        registry,
        null,
      ),
      throwsA(
        isA<BeakValidationException>().having(
          (error) => error.fieldErrors.keys,
          'fields',
          contains('parent_id'),
        ),
      ),
    );
  });

  test('a record cannot move under its own descendant', () async {
    await insert({'id': 1, 'name': 'Root'});
    await insert({'id': 2, 'name': 'Child', 'parent_id': 1});
    await insert({'id': 3, 'name': 'Grandchild', 'parent_id': 2});
    final rule = BeakTreeRule(
      parent: NodeModel.parent,
      children: NodeModel.children,
    );

    await expectLater(
      applyBeakTreeRules(
        [rule],
        _update(1, {'parent_id': 3}),
        source,
        registry,
        null,
      ),
      throwsA(
        isA<BeakValidationException>().having(
          (error) => error.fieldErrors.keys,
          'fields',
          contains('parent_id'),
        ),
      ),
    );
  });

  test('a parent with children cannot be deleted', () async {
    await insert({'id': 1, 'name': 'Root'});
    await insert({'id': 2, 'name': 'Child', 'parent_id': 1});
    final rule = BeakTreeRule(
      parent: NodeModel.parent,
      children: NodeModel.children,
    );

    await expectLater(
      applyBeakTreeRules([rule], _delete(1), source, registry, null),
      throwsA(isA<BeakConflictException>()),
    );
  });

  test('a referenced record cannot be deleted', () async {
    await insert({'id': 1, 'name': 'Root'});
    await adapter.insert(
      const InsertDescriptor(table: 'refs', values: {'id': 1, 'node_id': 1}),
    );
    final rule = BeakTreeRule(
      parent: NodeModel.parent,
      children: NodeModel.children,
      referencedBy: [_RefModel.nodeId],
    );

    await expectLater(
      applyBeakTreeRules([rule], _delete(1), source, registry, null),
      throwsA(isA<BeakConflictException>()),
    );
  });

  test('siblings cannot repeat a sameAs value', () async {
    await insert({'id': 1, 'name': 'Root'});
    await insert({'id': 2, 'name': 'Taken', 'parent_id': 1});
    await insert({'id': 3, 'name': 'Free', 'parent_id': 1});
    final rule = BeakTreeRule(
      parent: NodeModel.parent,
      children: NodeModel.children,
      sameAs: [NodeModel.name],
    );

    await expectLater(
      applyBeakTreeRules(
        [rule],
        _update(3, {'name': 'Taken'}),
        source,
        registry,
        null,
      ),
      throwsA(
        isA<BeakValidationException>().having(
          (error) => error.fieldErrors.keys,
          'fields',
          contains('name'),
        ),
      ),
    );
  });

  test('a move that grows the tree past maxDepth is refused', () async {
    await insert({'id': 1, 'name': 'Root'});
    await insert({'id': 2, 'name': 'Child', 'parent_id': 1});
    await insert({'id': 3, 'name': 'OtherRoot'});
    await insert({'id': 4, 'name': 'OtherChild', 'parent_id': 3});
    final rule = BeakTreeRule(
      parent: NodeModel.parent,
      children: NodeModel.children,
      maxDepth: 1,
    );

    await expectLater(
      applyBeakTreeRules(
        [rule],
        _update(3, {'parent_id': 2}),
        source,
        registry,
        null,
      ),
      throwsA(isA<BeakValidationException>()),
    );
  });

  test('a valid move passes', () async {
    await insert({'id': 1, 'name': 'Root'});
    await insert({'id': 2, 'name': 'Child', 'parent_id': 1});
    final rule = BeakTreeRule(
      parent: NodeModel.parent,
      children: NodeModel.children,
      maxDepth: 3,
    );

    await applyBeakTreeRules(
      [rule],
      _update(2, {'parent_id': null}),
      source,
      registry,
      null,
    );
  });
}
