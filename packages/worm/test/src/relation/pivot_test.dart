import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/query/insert_descriptor.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/relation/pivot.dart';

Future<InMemoryAdapter> pivotAdapter() async {
  final adapter = InMemoryAdapter();
  await adapter.connect();
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'role_user'),
  );
  await adapter.insertMany(
    const InsertManyDescriptor(
      table: 'role_user',
      rows: <Map<String, Object?>>[
        <String, Object?>{'user_id': 1, 'role_id': 100},
        <String, Object?>{'user_id': 1, 'role_id': 101},
      ],
    ),
  );
  return adapter;
}

void main() {
  group('Pivot operations', () {
    test('attach inserts a pivot row', () async {
      final adapter = await pivotAdapter();
      final manager = PivotManager(
        adapter: adapter,
        pivotTable: 'role_user',
        parentPivotKey: 'user_id',
        relatedPivotKey: 'role_id',
        parentId: 1,
      );
      await manager.attach(200);
      final rows = await adapter.select(
        const QueryDescriptor(table: 'role_user'),
      );
      expect(rows, hasLength(3));
      expect(rows.last['role_id'], 200);
    });

    test('attach with pivot data writes additional columns', () async {
      final adapter = await pivotAdapter();
      final manager = PivotManager(
        adapter: adapter,
        pivotTable: 'role_user',
        parentPivotKey: 'user_id',
        relatedPivotKey: 'role_id',
        parentId: 1,
      );
      await manager.attach(
        300,
        pivotData: const <String, Object?>{'assigned_at': '2024-01-01'},
      );
      final rows = await adapter.select(
        const QueryDescriptor(table: 'role_user'),
      );
      expect(rows.last['assigned_at'], '2024-01-01');
    });

    test('detach removes pivot rows', () async {
      final adapter = await pivotAdapter();
      final manager = PivotManager(
        adapter: adapter,
        pivotTable: 'role_user',
        parentPivotKey: 'user_id',
        relatedPivotKey: 'role_id',
        parentId: 1,
      );
      final removed = await manager.detach(100);
      expect(removed, 1);
      final rows = await adapter.select(
        const QueryDescriptor(table: 'role_user'),
      );
      expect(rows, hasLength(1));
      expect(rows.first['role_id'], 101);
    });

    test('sync replaces pivot rows precisely', () async {
      final adapter = await pivotAdapter();
      final manager = PivotManager(
        adapter: adapter,
        pivotTable: 'role_user',
        parentPivotKey: 'user_id',
        relatedPivotKey: 'role_id',
        parentId: 1,
      );
      final result = await manager.sync(<Object>[101, 200, 300]);
      expect(result.attached.toSet(), <Object>{200, 300});
      expect(result.detached.toSet(), <Object>{100});
      final rows = await adapter.select(
        const QueryDescriptor(table: 'role_user'),
      );
      final roleIds = rows.map((r) => r['role_id']).toSet();
      expect(roleIds, <Object>{101, 200, 300});
    });
  });
}
