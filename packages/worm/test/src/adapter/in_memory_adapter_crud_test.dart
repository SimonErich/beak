import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/query/delete_descriptor.dart';
import 'package:worm/src/query/field.dart';
import 'package:worm/src/query/field_operators.dart';
import 'package:worm/src/query/insert_descriptor.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/query/update_descriptor.dart';

import '_fixtures.dart';

const _name = StringField('name');
const _age = ComparableField<int>('age');

void main() {
  group('InMemoryAdapter insert', () {
    test('returns inserted row with the exact values supplied', () async {
      final adapter = InMemoryAdapter();
      await adapter.connect();
      await adapter.executeSchema(
        const SchemaDescriptor.createTable(table: 'users'),
      );
      final row = await adapter.insert(
        const InsertDescriptor(
          table: 'users',
          values: <String, Object?>{'id': 1, 'name': 'Alice', 'age': 30},
        ),
      );
      expect(row, <String, Object?>{'id': 1, 'name': 'Alice', 'age': 30});
    });

    test('returns a copy — mutating result does not alter storage', () async {
      final adapter = InMemoryAdapter();
      await adapter.connect();
      await adapter.executeSchema(
        const SchemaDescriptor.createTable(table: 'users'),
      );
      final inserted = await adapter.insert(
        const InsertDescriptor(
          table: 'users',
          values: <String, Object?>{'id': 1, 'name': 'Alice'},
        ),
      );
      inserted['name'] = 'Mallory';
      final stored = await adapter.selectOne(
        const QueryDescriptor(table: 'users'),
      );
      expect(stored?['name'], 'Alice');
    });

    test('returning projects only the named columns', () async {
      final adapter = InMemoryAdapter();
      await adapter.connect();
      await adapter.executeSchema(
        const SchemaDescriptor.createTable(table: 'users'),
      );
      final row = await adapter.insert(
        const InsertDescriptor(
          table: 'users',
          values: <String, Object?>{'id': 1, 'name': 'A', 'age': 9},
          returning: <String>['id'],
        ),
      );
      expect(row, <String, Object?>{'id': 1});
    });
  });

  group('InMemoryAdapter insertMany', () {
    test('persists every row and projects returning columns', () async {
      final adapter = InMemoryAdapter();
      await adapter.connect();
      await adapter.executeSchema(
        const SchemaDescriptor.createTable(table: 'users'),
      );
      final rows = await adapter.insertMany(
        const InsertManyDescriptor(
          table: 'users',
          rows: <Map<String, Object?>>[
            <String, Object?>{'id': 1, 'name': 'Alice', 'age': 30},
            <String, Object?>{'id': 2, 'name': 'Bob', 'age': 25},
          ],
          returning: <String>['id'],
        ),
      );
      expect(rows, <Map<String, Object?>>[
        <String, Object?>{'id': 1},
        <String, Object?>{'id': 2},
      ]);
      final all = await adapter.select(const QueryDescriptor(table: 'users'));
      expect(all, hasLength(2));
    });
  });

  group('InMemoryAdapter selectOne', () {
    test('returns null when no row matches', () async {
      final adapter = await adapterWithUsers();
      final row = await adapter.selectOne(
        QueryDescriptor(table: 'users', where: _name.eq('Zoe')),
      );
      expect(row, isNull);
    });

    test('returns the first matching row when one exists', () async {
      final adapter = await adapterWithUsers();
      final row = await adapter.selectOne(
        QueryDescriptor(table: 'users', where: _name.eq('Alice')),
      );
      expect(row?['id'], 1);
    });
  });

  group('InMemoryAdapter update', () {
    test('returns count of actually modified rows', () async {
      final adapter = await adapterWithUsers();
      final count = await adapter.update(
        UpdateDescriptor(
          table: 'users',
          values: const <String, Object?>{'age': 99},
          where: _name.eq('Alice'),
        ),
      );
      expect(count, 1);
    });

    test('applies the update to matching rows only', () async {
      final adapter = await adapterWithUsers();
      await adapter.update(
        UpdateDescriptor(
          table: 'users',
          values: const <String, Object?>{'age': 99},
          where: _age.gte(35),
        ),
      );
      final rows = await adapter.select(const QueryDescriptor(table: 'users'));
      final updated = rows.where((r) => r['age'] == 99).length;
      expect(updated, 2);
    });

    test('returns 0 when nothing matches', () async {
      final adapter = await adapterWithUsers();
      final count = await adapter.update(
        UpdateDescriptor(
          table: 'users',
          values: const <String, Object?>{'age': 0},
          where: _name.eq('Zoe'),
        ),
      );
      expect(count, 0);
    });
  });

  group('InMemoryAdapter delete', () {
    test('without where removes every row', () async {
      final adapter = await adapterWithUsers();
      final removed = await adapter.delete(
        const DeleteDescriptor(table: 'users'),
      );
      expect(removed, 4);
      final remaining = await adapter.select(
        const QueryDescriptor(table: 'users'),
      );
      expect(remaining, isEmpty);
    });

    test('with where removes only matching rows', () async {
      final adapter = await adapterWithUsers();
      final removed = await adapter.delete(
        DeleteDescriptor(table: 'users', where: _age.gte(35)),
      );
      expect(removed, 2);
      final remaining = await adapter.select(
        const QueryDescriptor(table: 'users'),
      );
      expect(remaining.map((r) => r['name']).toSet(), {'Alice', 'Bob'});
    });
  });
}
