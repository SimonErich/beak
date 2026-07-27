import 'package:test/test.dart';
import 'package:worm/src/adapter/in_memory_adapter.dart';
import 'package:worm/src/exception/unsupported_operation_exception.dart';
import 'package:worm/src/query/field.dart';
import 'package:worm/src/query/field_operators.dart';
import 'package:worm/src/query/insert_descriptor.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/query/sort_clause.dart';
import 'package:worm/src/schema/column_type.dart';

import '_fixtures.dart';

class _RollbackSignal implements Exception {
  const _RollbackSignal();
}

const _age = ComparableField<int>('age');

void main() {
  group('transaction', () {
    test('callback success commits data', () async {
      final adapter = await adapterWithUsers();
      await adapter.transaction((tx) async {
        await tx.insert(
          const InsertDescriptor(
            table: 'users',
            values: <String, Object?>{'id': 5, 'name': 'Eve', 'age': 22},
          ),
        );
      });
      final rows = await adapter.select(const QueryDescriptor(table: 'users'));
      expect(rows, hasLength(5));
      expect(rows.map((r) => r['name']).toSet(), contains('Eve'));
    });

    test('callback exception rolls back', () async {
      final adapter = await adapterWithUsers();
      await expectLater(
        adapter.transaction<void>((tx) async {
          await tx.insert(
            const InsertDescriptor(
              table: 'users',
              values: <String, Object?>{'id': 5, 'name': 'Eve'},
            ),
          );
          throw const _RollbackSignal();
        }),
        throwsA(isA<_RollbackSignal>()),
      );
      final rows = await adapter.select(const QueryDescriptor(table: 'users'));
      expect(rows, hasLength(4));
      expect(rows.map((r) => r['name']).toSet(), isNot(contains('Eve')));
    });
  });

  group('executeSchema', () {
    test('create adds a table visible to introspection', () async {
      final adapter = InMemoryAdapter();
      await adapter.connect();
      await adapter.executeSchema(
        const SchemaDescriptor.createTable(table: 'products'),
      );
      final schema = await adapter.introspectSchema();
      expect(schema, contains('products'));
    });

    test('drop removes the table', () async {
      final adapter = await adapterWithUsers();
      await adapter.executeSchema(
        const SchemaDescriptor.dropTable(table: 'users'),
      );
      final schema = await adapter.introspectSchema();
      expect(schema, isEmpty);
    });

    test('truncate clears rows but keeps table', () async {
      final adapter = await adapterWithUsers();
      await adapter.executeSchema(
        const SchemaDescriptor.truncateTable(table: 'users'),
      );
      final schema = await adapter.introspectSchema();
      expect(schema.keys, contains('users'));
      final rows = await adapter.select(const QueryDescriptor(table: 'users'));
      expect(rows, isEmpty);
    });
  });

  group('stream', () {
    test('emits all rows matching the query descriptor', () async {
      final adapter = await adapterWithUsers();
      final ids = <Object?>[];
      await adapter
          .stream(
            const QueryDescriptor(
              table: 'users',
              orderBy: <SortClause>[SortClause('id')],
            ),
          )
          .forEach((row) => ids.add(row['id']));
      expect(ids, <int>[1, 2, 3, 4]);
    });

    test('emits only rows matching the where', () async {
      final adapter = await adapterWithUsers();
      final names = <Object?>[];
      await adapter
          .stream(
            QueryDescriptor(
              table: 'users',
              where: _age.gte(35),
              orderBy: const <SortClause>[SortClause('id')],
            ),
          )
          .forEach((row) => names.add(row['name']));
      expect(names, <String>['Carol', 'Dave']);
    });
  });

  group('unsupported operations', () {
    test('rawQuery throws UnsupportedOperationException', () {
      final adapter = InMemoryAdapter();
      expect(
        () => adapter.rawQuery('SELECT 1', const <Object?>[]),
        throwsA(
          isA<UnsupportedOperationException>()
              .having((e) => e.operation, 'operation', 'rawQuery')
              .having((e) => e.adapter, 'adapter', 'InMemoryAdapter'),
        ),
      );
    });

    test('rawExecute throws UnsupportedOperationException', () {
      final adapter = InMemoryAdapter();
      expect(
        () => adapter.rawExecute('DELETE FROM x', const <Object?>[]),
        throwsA(
          isA<UnsupportedOperationException>()
              .having((e) => e.operation, 'operation', 'rawExecute')
              .having((e) => e.adapter, 'adapter', 'InMemoryAdapter'),
        ),
      );
    });

    test('executeSchema(alter) adds and drops columns for real', () async {
      // The store models columns and rows, so a test asserting that a
      // migration added a column must be able to see it.
      final adapter = InMemoryAdapter();
      await adapter.executeSchema(
        const SchemaDescriptor.createTable(
          table: 'users',
          columns: <SchemaColumn>[
            SchemaColumn(name: 'id', type: ColumnType.integer),
            SchemaColumn(name: 'legacy', type: ColumnType.text),
          ],
        ),
      );
      await adapter.insert(
        const InsertDescriptor(
          table: 'users',
          values: <String, Object?>{'id': 1, 'legacy': 'old'},
        ),
      );

      await adapter.executeSchema(
        const SchemaDescriptor.alterTable(
          table: 'users',
          alterations: <SchemaAlteration>[
            SchemaDropColumn('legacy'),
            SchemaAddColumn(SchemaColumn(name: 'email', type: ColumnType.text)),
            // Index and constraint steps have no storage engine to act on;
            // accepting them keeps a migration runnable against the fake.
            SchemaAddIndex(
              SchemaIndex(name: 'users_email_idx', columns: <String>['email']),
            ),
          ],
        ),
      );

      expect(
        await adapter.introspectSchema(),
        containsPair('users', ['id', 'email']),
      );
      final rows = await adapter.select(const QueryDescriptor(table: 'users'));
      expect(rows.single.containsKey('legacy'), isFalse);
    });

    test('executeSchema(alter) rejects an unknown column', () {
      final adapter = InMemoryAdapter();
      expect(
        () => adapter.executeSchema(
          const SchemaDescriptor.alterTable(
            table: 'users',
            alterations: <SchemaAlteration>[SchemaDropColumn('nope')],
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('capabilities', () {
    test('reports transactions, streaming, no joins', () {
      final adapter = InMemoryAdapter();
      expect(adapter.capabilities.supportsTransactions, isTrue);
      expect(adapter.capabilities.supportsStreaming, isTrue);
      expect(adapter.capabilities.supportsJoins, isFalse);
    });
  });

  group('close', () {
    test('clears every table and schema', () async {
      final adapter = await adapterWithUsers();
      await adapter.close();
      expect(adapter.isConnected, isFalse);
      expect(await adapter.introspectSchema(), isEmpty);
    });
  });
}
