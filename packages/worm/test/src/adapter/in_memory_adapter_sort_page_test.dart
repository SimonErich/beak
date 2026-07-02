import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/query/insert_descriptor.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/query/sort_clause.dart';
import 'package:worm/src/query/sort_direction.dart';

Future<InMemoryAdapter> _adapter() async {
  final adapter = InMemoryAdapter();
  await adapter.connect();
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'users'),
  );
  await adapter.insertMany(
    const InsertManyDescriptor(
      table: 'users',
      rows: <Map<String, Object?>>[
        <String, Object?>{'id': 1, 'name': 'Alice', 'age': 30},
        <String, Object?>{'id': 2, 'name': 'Bob', 'age': 25},
        <String, Object?>{'id': 3, 'name': 'Carol', 'age': 40},
        <String, Object?>{'id': 4, 'name': 'Dave', 'age': 35},
        <String, Object?>{'id': 5, 'name': 'Eve', 'age': 28},
      ],
    ),
  );
  return adapter;
}

Future<InMemoryAdapter> _adapterWithDuplicates() async {
  final adapter = InMemoryAdapter();
  await adapter.connect();
  await adapter.executeSchema(
    const SchemaDescriptor.createTable(table: 'tags'),
  );
  await adapter.insertMany(
    const InsertManyDescriptor(
      table: 'tags',
      rows: <Map<String, Object?>>[
        <String, Object?>{'value': 'red'},
        <String, Object?>{'value': 'blue'},
        <String, Object?>{'value': 'red'},
        <String, Object?>{'value': 'green'},
        <String, Object?>{'value': 'blue'},
      ],
    ),
  );
  return adapter;
}

void main() {
  group('sorting', () {
    test('ascending order sorts ascendingly', () async {
      final adapter = await _adapter();
      final rows = await adapter.select(
        const QueryDescriptor(
          table: 'users',
          orderBy: <SortClause>[SortClause('age')],
        ),
      );
      expect(rows.map((r) => r['age']).toList(), <int>[25, 28, 30, 35, 40]);
    });

    test('descending order sorts descendingly', () async {
      final adapter = await _adapter();
      final rows = await adapter.select(
        const QueryDescriptor(
          table: 'users',
          orderBy: <SortClause>[
            SortClause('age', direction: SortDirection.desc),
          ],
        ),
      );
      expect(rows.map((r) => r['age']).toList(), <int>[40, 35, 30, 28, 25]);
    });

    test('multi-field sort produces a deterministic order', () async {
      final adapter = InMemoryAdapter();
      await adapter.connect();
      await adapter.executeSchema(
        const SchemaDescriptor.createTable(table: 'staff'),
      );
      await adapter.insertMany(
        const InsertManyDescriptor(
          table: 'staff',
          rows: <Map<String, Object?>>[
            <String, Object?>{'team': 'A', 'age': 30, 'id': 1},
            <String, Object?>{'team': 'B', 'age': 25, 'id': 2},
            <String, Object?>{'team': 'A', 'age': 25, 'id': 3},
            <String, Object?>{'team': 'B', 'age': 30, 'id': 4},
            <String, Object?>{'team': 'A', 'age': 30, 'id': 5},
          ],
        ),
      );
      final rows = await adapter.select(
        const QueryDescriptor(
          table: 'staff',
          orderBy: <SortClause>[
            SortClause('team'),
            SortClause('age', direction: SortDirection.desc),
            SortClause('id'),
          ],
        ),
      );
      expect(rows.map((r) => r['id']).toList(), <int>[1, 5, 3, 4, 2]);
    });
  });

  group('pagination', () {
    test('limit returns exactly N rows', () async {
      final adapter = await _adapter();
      final rows = await adapter.select(
        const QueryDescriptor(
          table: 'users',
          orderBy: <SortClause>[SortClause('id')],
          limit: 2,
        ),
      );
      expect(rows, hasLength(2));
      expect(rows.map((r) => r['id']).toList(), <int>[1, 2]);
    });

    test('offset skips rows', () async {
      final adapter = await _adapter();
      final rows = await adapter.select(
        const QueryDescriptor(
          table: 'users',
          orderBy: <SortClause>[SortClause('id')],
          offset: 2,
        ),
      );
      expect(rows, hasLength(3));
      expect(rows.map((r) => r['id']).toList(), <int>[3, 4, 5]);
    });

    test('offset beyond the data returns an empty list', () async {
      final adapter = await _adapter();
      final rows = await adapter.select(
        const QueryDescriptor(
          table: 'users',
          orderBy: <SortClause>[SortClause('id')],
          offset: 10,
        ),
      );
      expect(rows, isEmpty);
    });

    test('limit combined with offset paginates a window', () async {
      final adapter = await _adapter();
      final rows = await adapter.select(
        const QueryDescriptor(
          table: 'users',
          orderBy: <SortClause>[SortClause('id')],
          limit: 2,
          offset: 1,
        ),
      );
      expect(rows.map((r) => r['id']).toList(), <int>[2, 3]);
    });
  });

  group('distinct', () {
    test('removes duplicate rows', () async {
      final adapter = await _adapterWithDuplicates();
      final rows = await adapter.select(
        const QueryDescriptor(
          table: 'tags',
          columns: <String>['value'],
          orderBy: <SortClause>[SortClause('value')],
          distinct: true,
        ),
      );
      expect(rows.map((r) => r['value']).toList(), <String>[
        'blue',
        'green',
        'red',
      ]);
    });

    test('does not affect already-unique rows', () async {
      final adapter = await _adapter();
      final rows = await adapter.select(
        const QueryDescriptor(
          table: 'users',
          columns: <String>['id'],
          orderBy: <SortClause>[SortClause('id')],
          distinct: true,
        ),
      );
      expect(rows.map((r) => r['id']).toList(), <int>[1, 2, 3, 4, 5]);
    });
  });
}
