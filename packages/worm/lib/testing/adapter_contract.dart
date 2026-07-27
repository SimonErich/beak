/// Shared `DatabaseAdapter` contract test suite.
///
/// Imported by adapter tests in both the core `worm` package and
/// sibling adapter packages (`worm_postgres`, `worm_mongodb`) so
/// every implementation is validated against identical behaviour.
///
/// Intentionally *not* exported from `package:worm/worm.dart` — it
/// is a testing-only module and should only be imported from
/// `*_test.dart` files.
library;

import 'dart:async';

import 'package:test/test.dart';

import '../src/adapter/adapter_capabilities.dart';
import '../src/adapter/database_adapter.dart';
import '../src/exception/configuration_exception.dart';
import '../src/exception/transaction_exception.dart';
import '../src/exception/worm_exception.dart';
import '../src/query/aggregate_descriptor.dart';
import '../src/query/delete_descriptor.dart';
import '../src/query/insert_descriptor.dart';
import '../src/query/operator.dart';
import '../src/query/predicate.dart';
import '../src/query/predicate_tree.dart';
import '../src/query/query_descriptor.dart';
import '../src/query/schema_descriptor.dart';
import '../src/query/sort_clause.dart';
import '../src/query/sort_direction.dart';
import '../src/query/update_descriptor.dart';
import '../src/schema/column_type.dart';

PredicateTree _leaf({
  required String field,
  required Operator op,
  Object? value,
}) => LeafNode(Predicate(fieldName: field, operator: op, value: value));

/// Registers the full `DatabaseAdapter` contract suite.
///
/// [adapterFactory] returns a fresh, unconnected adapter per test.
/// [capabilities] declares which optional features the contract
/// should exercise — currently the transaction rollback group is
/// gated on [AdapterCapabilities.supportsTransactions] and the raw
/// query group is gated on [AdapterCapabilities.supportsRawQuery].
///
/// Example:
/// ```dart
/// runAdapterContractTests(
///   adapterFactory: InMemoryAdapter.new,
///   capabilities: const AdapterCapabilities(),
/// );
/// ```
void runAdapterContractTests({
  required FutureOr<DatabaseAdapter> Function() adapterFactory,
  required AdapterCapabilities capabilities,
  String name = 'DatabaseAdapter contract',
}) {
  group(name, () {
    late DatabaseAdapter adapter;

    setUp(() async {
      adapter = await adapterFactory();
      await adapter.connect();
      await adapter.executeSchema(_dropUsersIfExists);
      await adapter.executeSchema(_createUsersTable);
      await adapter.insertMany(_seedUsers);
    });

    tearDown(() async {
      try {
        await adapter.executeSchema(_dropUsersIfExists);
      } on WormException {
        // Best-effort teardown — ignore drop errors so disconnect
        // still runs.
      }
      await adapter.disconnect();
    });

    DatabaseAdapter current() => adapter;

    _registerCrudTests(current);
    _registerOperatorTests(current);
    _registerCompositionTests(current);
    _registerSortPaginationTests(current);
    _registerAggregationTests(current);
    _registerSchemaTests(current);
    _registerStreamingTests(current);
    _registerCompileToStringTests(current);
    _registerRawQueryTests(current, capabilities);
    _registerCapabilityGatingTests(current, capabilities);
    if (capabilities.supportsColumnAlterations) {
      _registerAlterationTests(current);
    }
    if (capabilities.supportsTransactions) {
      _registerTransactionRollbackTests(current);
    }
  });
}

const SchemaDescriptor _dropUsersIfExists = SchemaDescriptor.dropTable(
  table: 'users',
  ifExists: true,
);

const SchemaDescriptor _createUsersTable = SchemaDescriptor.createTable(
  table: 'users',
  columns: <SchemaColumn>[
    SchemaColumn(name: 'id', type: ColumnType.integer, isPrimaryKey: true),
    SchemaColumn(name: 'name', type: ColumnType.text),
    SchemaColumn(name: 'age', type: ColumnType.integer),
    SchemaColumn(name: 'email', type: ColumnType.text, nullable: true),
    SchemaColumn(name: 'score', type: ColumnType.integer),
  ],
);

const InsertManyDescriptor _seedUsers = InsertManyDescriptor(
  table: 'users',
  rows: <Map<String, Object?>>[
    <String, Object?>{
      'id': 1,
      'name': 'Alice',
      'age': 30,
      'email': 'alice@example.com',
      'score': 100,
    },
    <String, Object?>{
      'id': 2,
      'name': 'Bob',
      'age': 25,
      'email': 'bob@example.com',
      'score': 200,
    },
    <String, Object?>{
      'id': 3,
      'name': 'Carol',
      'age': 40,
      'email': 'carol@example.com',
      'score': 150,
    },
    <String, Object?>{
      'id': 4,
      'name': 'Dave',
      'age': 35,
      'email': null,
      'score': 200,
    },
    <String, Object?>{
      'id': 5,
      'name': 'Eve',
      'age': 28,
      'email': 'eve@example.com',
      'score': 50,
    },
  ],
);

void _registerCrudTests(DatabaseAdapter Function() adapter) {
  group('CRUD', () {
    test('insert returns the row and persists it', () async {
      final inserted = await adapter().insert(
        const InsertDescriptor(
          table: 'users',
          values: <String, Object?>{
            'id': 99,
            'name': 'Zoe',
            'age': 22,
            'email': 'zoe@example.com',
            'score': 10,
          },
        ),
      );
      expect(inserted['name'], 'Zoe');
      final row = await adapter().selectOne(
        QueryDescriptor(
          table: 'users',
          where: _leaf(field: 'id', op: Operator.eq, value: 99),
        ),
      );
      expect(row?['name'], 'Zoe');
    });

    test('insertMany persists every supplied row', () async {
      final rows = await adapter().insertMany(
        const InsertManyDescriptor(
          table: 'users',
          rows: <Map<String, Object?>>[
            <String, Object?>{
              'id': 10,
              'name': 'Xena',
              'age': 31,
              'email': 'xena@example.com',
              'score': 80,
            },
            <String, Object?>{
              'id': 11,
              'name': 'Yuri',
              'age': 29,
              'email': 'yuri@example.com',
              'score': 90,
            },
          ],
        ),
      );
      expect(rows, hasLength(2));
      final all = await adapter().select(const QueryDescriptor(table: 'users'));
      expect(all, hasLength(7));
    });

    test('select returns every seeded row', () async {
      final rows = await adapter().select(
        const QueryDescriptor(table: 'users'),
      );
      expect(rows, hasLength(5));
    });

    test('selectOne returns the first matching row', () async {
      final row = await adapter().selectOne(
        QueryDescriptor(
          table: 'users',
          where: _leaf(field: 'name', op: Operator.eq, value: 'Alice'),
        ),
      );
      expect(row?['id'], 1);
    });

    test('selectOne returns null when nothing matches', () async {
      final row = await adapter().selectOne(
        QueryDescriptor(
          table: 'users',
          where: _leaf(field: 'name', op: Operator.eq, value: 'Zoe'),
        ),
      );
      expect(row, isNull);
    });

    test('update modifies matching rows and returns the count', () async {
      final count = await adapter().update(
        UpdateDescriptor(
          table: 'users',
          values: const <String, Object?>{'age': 99},
          where: _leaf(field: 'name', op: Operator.eq, value: 'Alice'),
        ),
      );
      expect(count, 1);
      final row = await adapter().selectOne(
        QueryDescriptor(
          table: 'users',
          where: _leaf(field: 'name', op: Operator.eq, value: 'Alice'),
        ),
      );
      expect(row?['age'], 99);
    });

    test('delete removes matching rows and returns the count', () async {
      final count = await adapter().delete(
        DeleteDescriptor(
          table: 'users',
          where: _leaf(field: 'age', op: Operator.gte, value: 35),
        ),
      );
      expect(count, 2);
      final remaining = await adapter().select(
        const QueryDescriptor(table: 'users'),
      );
      expect(remaining, hasLength(3));
    });
  });
}

void _registerOperatorTests(DatabaseAdapter Function() adapter) {
  group('Operators', () {
    Future<List<Map<String, Object?>>> where(PredicateTree tree) =>
        adapter().select(QueryDescriptor(table: 'users', where: tree));

    test('eq matches exact value', () async {
      final rows = await where(
        _leaf(field: 'name', op: Operator.eq, value: 'Alice'),
      );
      expect(rows, hasLength(1));
    });

    test('neq excludes exact value', () async {
      final rows = await where(
        _leaf(field: 'name', op: Operator.neq, value: 'Alice'),
      );
      expect(rows, hasLength(4));
    });

    test('gt filters strictly greater', () async {
      final rows = await where(_leaf(field: 'age', op: Operator.gt, value: 30));
      expect(rows, hasLength(2));
    });

    test('gte includes equal values', () async {
      final rows = await where(
        _leaf(field: 'age', op: Operator.gte, value: 30),
      );
      expect(rows, hasLength(3));
    });

    test('lt filters strictly lesser', () async {
      final rows = await where(_leaf(field: 'age', op: Operator.lt, value: 30));
      expect(rows, hasLength(2));
    });

    test('lte includes equal values', () async {
      final rows = await where(
        _leaf(field: 'age', op: Operator.lte, value: 30),
      );
      expect(rows, hasLength(3));
    });

    test('like matches SQL wildcards', () async {
      final rows = await where(
        _leaf(field: 'name', op: Operator.like, value: 'A%'),
      );
      expect(rows.single['name'], 'Alice');
    });

    test('isNull matches null values', () async {
      final rows = await where(_leaf(field: 'email', op: Operator.isNull));
      expect(rows.single['name'], 'Dave');
    });

    test('isNotNull excludes null values', () async {
      final rows = await where(_leaf(field: 'email', op: Operator.isNotNull));
      expect(rows, hasLength(4));
    });

    test('inList matches list membership', () async {
      final rows = await where(
        const LeafNode(
          Predicate(
            fieldName: 'age',
            operator: Operator.inList,
            value: <Object?>[25, 30, 40],
          ),
        ),
      );
      expect(rows, hasLength(3));
    });

    test('notInList excludes list membership', () async {
      final rows = await where(
        const LeafNode(
          Predicate(
            fieldName: 'age',
            operator: Operator.notInList,
            value: <Object?>[25, 30, 40],
          ),
        ),
      );
      expect(rows, hasLength(2));
    });

    test('between matches inclusive range', () async {
      final rows = await where(
        const LeafNode(
          Predicate(
            fieldName: 'age',
            operator: Operator.between,
            value: <Object?>[25, 30],
          ),
        ),
      );
      expect(rows, hasLength(3));
    });

    test('notBetween excludes inclusive range', () async {
      final rows = await where(
        const LeafNode(
          Predicate(
            fieldName: 'age',
            operator: Operator.notBetween,
            value: <Object?>[25, 30],
          ),
        ),
      );
      expect(rows, hasLength(2));
    });
  });
}

void _registerCompositionTests(DatabaseAdapter Function() adapter) {
  group('Predicate composition', () {
    test('AND tree combines two leaves', () async {
      final rows = await adapter().select(
        QueryDescriptor(
          table: 'users',
          where: AndNode(
            _leaf(field: 'age', op: Operator.gte, value: 30),
            _leaf(field: 'email', op: Operator.isNotNull),
          ),
        ),
      );
      expect(rows.map((r) => r['name']).toSet(), <String>{'Alice', 'Carol'});
    });

    test('OR tree combines two leaves', () async {
      final rows = await adapter().select(
        QueryDescriptor(
          table: 'users',
          where: OrNode(
            _leaf(field: 'name', op: Operator.eq, value: 'Alice'),
            _leaf(field: 'name', op: Operator.eq, value: 'Bob'),
          ),
        ),
      );
      expect(rows.map((r) => r['name']).toSet(), <String>{'Alice', 'Bob'});
    });

    test('NOT tree inverts inner predicate', () async {
      final rows = await adapter().select(
        QueryDescriptor(
          table: 'users',
          where: NotNode(_leaf(field: 'name', op: Operator.eq, value: 'Alice')),
        ),
      );
      expect(rows.map((r) => r['name']).toSet(), <String>{
        'Bob',
        'Carol',
        'Dave',
        'Eve',
      });
    });
  });
}

void _registerSortPaginationTests(DatabaseAdapter Function() adapter) {
  group('Sorting and pagination', () {
    test('orderBy ascending returns rows in natural order', () async {
      final rows = await adapter().select(
        const QueryDescriptor(
          table: 'users',
          orderBy: <SortClause>[SortClause('age')],
        ),
      );
      expect(rows.map((r) => r['age']).toList(), <int>[25, 28, 30, 35, 40]);
    });

    test('orderBy descending reverses the order', () async {
      final rows = await adapter().select(
        const QueryDescriptor(
          table: 'users',
          orderBy: <SortClause>[
            SortClause('age', direction: SortDirection.desc),
          ],
        ),
      );
      expect(rows.map((r) => r['age']).toList(), <int>[40, 35, 30, 28, 25]);
    });

    test('limit and offset slice the ordered result set', () async {
      final rows = await adapter().select(
        const QueryDescriptor(
          table: 'users',
          orderBy: <SortClause>[SortClause('age')],
          limit: 2,
          offset: 1,
        ),
      );
      expect(rows.map((r) => r['name']).toList(), <String>['Eve', 'Alice']);
    });
  });
}

void _registerAggregationTests(DatabaseAdapter Function() adapter) {
  group('Aggregations', () {
    test('count returns the total row count', () async {
      final total = await adapter().count(
        const AggregateDescriptor.count(table: 'users'),
      );
      expect(total, 5);
    });

    test('sum returns the numeric total of a column', () async {
      final total = await adapter().sum(
        const AggregateDescriptor(
          table: 'users',
          function: AggregateFunction.sum,
          column: 'score',
        ),
      );
      expect(total, 700);
    });

    test('avg returns the mean of a numeric column', () async {
      final mean = await adapter().avg(
        const AggregateDescriptor(
          table: 'users',
          function: AggregateFunction.avg,
          column: 'score',
        ),
      );
      expect(mean, 140);
    });

    test('min returns the minimum value of a column', () async {
      final value = await adapter().min(
        const AggregateDescriptor(
          table: 'users',
          function: AggregateFunction.min,
          column: 'age',
        ),
      );
      expect(value, 25);
    });

    test('max returns the maximum value of a column', () async {
      final value = await adapter().max(
        const AggregateDescriptor(
          table: 'users',
          function: AggregateFunction.max,
          column: 'age',
        ),
      );
      expect(value, 40);
    });

    test('aggregateGrouped counts rows per group', () async {
      // Scores: 100×1, 200×2, 150×1, 50×1.
      final byScore = await adapter().aggregateGrouped(
        const AggregateDescriptor.count(table: 'users', groupBy: 'score'),
      );
      expect(byScore[200], 2);
      expect(byScore[100], 1);
      expect(byScore[50], 1);
    });

    test('aggregateGrouped sums a column per group', () async {
      // Sum of age grouped by score: 200 → 25 (Bob) + 35 (Dave) = 60.
      final ageByScore = await adapter().aggregateGrouped(
        const AggregateDescriptor(
          table: 'users',
          function: AggregateFunction.sum,
          column: 'age',
          groupBy: 'score',
        ),
      );
      expect(ageByScore[200], 60);
      expect(ageByScore[100], 30);
    });
  });
}

void _registerSchemaTests(DatabaseAdapter Function() adapter) {
  group('Schema', () {
    test(
      'executeSchema creates a table that introspectSchema reports',
      () async {
        await adapter().executeSchema(
          const SchemaDescriptor.dropTable(table: 'products', ifExists: true),
        );
        await adapter().executeSchema(
          const SchemaDescriptor.createTable(
            table: 'products',
            columns: <SchemaColumn>[
              SchemaColumn(
                name: 'id',
                type: ColumnType.integer,
                isPrimaryKey: true,
              ),
              SchemaColumn(name: 'sku', type: ColumnType.text),
            ],
          ),
        );
        final schema = await adapter().introspectSchema();
        expect(schema.containsKey('products'), isTrue);
      },
    );

    test('executeSchema dropTable removes the table from the schema', () async {
      await adapter().executeSchema(
        const SchemaDescriptor.dropTable(table: 'products', ifExists: true),
      );
      await adapter().executeSchema(
        const SchemaDescriptor.createTable(
          table: 'products',
          columns: <SchemaColumn>[
            SchemaColumn(name: 'id', type: ColumnType.integer),
          ],
        ),
      );
      await adapter().executeSchema(
        const SchemaDescriptor.dropTable(table: 'products'),
      );
      final schema = await adapter().introspectSchema();
      expect(schema.containsKey('products'), isFalse);
    });
  });
}

/// `ALTER TABLE`, on every adapter that has one.
///
/// This is the regression net for the change that gave worm alterations at
/// all. Before it, adding a field to a shipped app had no migration path but
/// `migrate:fresh` — and the only thing that proves an alteration was really
/// applied, rather than merely compiled, is reading the table afterwards.
void _registerAlterationTests(DatabaseAdapter Function() adapter) {
  group('Alterations', () {
    test('an added column is readable, and the rows survive', () async {
      await adapter().executeSchema(
        const SchemaDescriptor.alterTable(
          table: 'users',
          alterations: <SchemaAlteration>[
            SchemaAddColumn(
              SchemaColumn(
                name: 'nickname',
                type: ColumnType.text,
                nullable: true,
              ),
            ),
          ],
        ),
      );

      final rows = await adapter().select(
        const QueryDescriptor(
          table: 'users',
          orderBy: <SortClause>[SortClause('id')],
        ),
      );
      expect(rows, hasLength(5), reason: 'the alteration dropped rows');
      expect(rows.first['name'], 'Alice');
      expect(rows.first.containsKey('nickname'), isTrue);
      expect(rows.first['nickname'], isNull, reason: 'nullable, no backfill');
    });

    test('an added column accepts writes', () async {
      await adapter().executeSchema(
        const SchemaDescriptor.alterTable(
          table: 'users',
          alterations: <SchemaAlteration>[
            SchemaAddColumn(
              SchemaColumn(
                name: 'nickname',
                type: ColumnType.text,
                nullable: true,
              ),
            ),
          ],
        ),
      );
      await adapter().update(
        const UpdateDescriptor(
          table: 'users',
          values: <String, Object?>{'nickname': 'Ali'},
          where: LeafNode(
            Predicate(fieldName: 'id', operator: Operator.eq, value: 1),
          ),
        ),
      );

      final row = await adapter().selectOne(
        const QueryDescriptor(
          table: 'users',
          where: LeafNode(
            Predicate(fieldName: 'id', operator: Operator.eq, value: 1),
          ),
        ),
      );
      expect(row?['nickname'], 'Ali');
    });

    test('a dropped column leaves the schema', () async {
      await adapter().executeSchema(
        const SchemaDescriptor.alterTable(
          table: 'users',
          alterations: <SchemaAlteration>[
            SchemaAddColumn(
              SchemaColumn(
                name: 'nickname',
                type: ColumnType.text,
                nullable: true,
              ),
            ),
          ],
        ),
      );
      await adapter().executeSchema(
        const SchemaDescriptor.alterTable(
          table: 'users',
          alterations: <SchemaAlteration>[SchemaDropColumn('nickname')],
        ),
      );

      final schema = await adapter().introspectSchema();
      expect(schema['users'], isNot(contains('nickname')));
      expect(schema['users'], contains('name'));
    });

    test('an index can be created and then dropped by name', () async {
      // Dropping without `ifExists` is the assertion: a database that never
      // created the index refuses to drop it, so the pair proves the
      // `CREATE INDEX` was executed rather than merely emitted.
      await adapter().executeSchema(
        const SchemaDescriptor.alterTable(
          table: 'users',
          alterations: <SchemaAlteration>[
            SchemaAddIndex(
              SchemaIndex(
                name: 'users_contract_email_idx',
                columns: <String>['email'],
              ),
            ),
          ],
        ),
      );

      await expectLater(
        adapter().executeSchema(
          const SchemaDescriptor.alterTable(
            table: 'users',
            alterations: <SchemaAlteration>[
              SchemaDropIndex('users_contract_email_idx'),
            ],
          ),
        ),
        completes,
      );
    });
  });
}

void _registerStreamingTests(DatabaseAdapter Function() adapter) {
  group('Streaming', () {
    test('stream emits the same rows as select for the same query', () async {
      const descriptor = QueryDescriptor(
        table: 'users',
        orderBy: <SortClause>[SortClause('id')],
      );
      final streamed = await adapter().stream(descriptor).toList();
      final selected = await adapter().select(descriptor);
      expect(streamed, selected);
    });
  });
}

void _registerCompileToStringTests(DatabaseAdapter Function() adapter) {
  group('compileToString', () {
    test('returns a non-empty string for a QueryDescriptor', () {
      final result = adapter().compileToString(
        const QueryDescriptor(table: 'users'),
      );
      expect(result, isNotEmpty);
    });
  });
}

void _registerRawQueryTests(
  DatabaseAdapter Function() adapter,
  AdapterCapabilities capabilities,
) {
  group('rawQuery', () {
    test('respects supportsRawQuery capability', () async {
      if (capabilities.supportsRawQuery) {
        return;
      }
      expect(
        () => adapter().rawQuery('select 1', const <Object?>[]),
        throwsA(isA<WormException>()),
      );
    });
  });
}

void _registerCapabilityGatingTests(
  DatabaseAdapter Function() adapter,
  AdapterCapabilities capabilities,
) {
  group('Capability gating', () {
    test('declared capabilities are non-falsely claimed', () {
      final declared = adapter().capabilities;
      expect(declared.supportsTransactions, capabilities.supportsTransactions);
      expect(declared.supportsStreaming, capabilities.supportsStreaming);
      expect(declared.supportsAggregations, capabilities.supportsAggregations);
    });

    test('configuration exceptions propagate when capabilities deny', () async {
      if (capabilities.supportsRawQuery) return;
      expect(
        () => adapter().rawQuery('SELECT 1', const <Object?>[]),
        throwsA(anyOf(isA<ConfigurationException>(), isA<WormException>())),
      );
    });

    test('transaction gating mirrors capability flag', () async {
      if (capabilities.supportsTransactions) return;
      expect(
        () => adapter().transaction((_) async => null),
        throwsA(isA<TransactionException>()),
      );
    });
  });
}

void _registerTransactionRollbackTests(DatabaseAdapter Function() adapter) {
  group('Transaction rollback', () {
    test('throwing inside a transaction discards writes', () async {
      await expectLater(
        adapter().transaction((tx) async {
          await tx.insert(
            const InsertDescriptor(
              table: 'users',
              values: <String, Object?>{
                'id': 100,
                'name': 'Rolled',
                'age': 1,
                'email': null,
                'score': 0,
              },
            ),
          );
          throw const _RollbackSignal();
        }),
        throwsA(isA<_RollbackSignal>()),
      );
      final row = await adapter().selectOne(
        QueryDescriptor(
          table: 'users',
          where: _leaf(field: 'id', op: Operator.eq, value: 100),
        ),
      );
      expect(row, isNull);
    });

    test('committing transaction persists writes', () async {
      await adapter().transaction((tx) async {
        await tx.insert(
          const InsertDescriptor(
            table: 'users',
            values: <String, Object?>{
              'id': 101,
              'name': 'Persisted',
              'age': 1,
              'email': null,
              'score': 0,
            },
          ),
        );
      });
      final row = await adapter().selectOne(
        QueryDescriptor(
          table: 'users',
          where: _leaf(field: 'id', op: Operator.eq, value: 101),
        ),
      );
      expect(row?['name'], 'Persisted');
    });
  });
}

class _RollbackSignal implements Exception {
  const _RollbackSignal();
}
