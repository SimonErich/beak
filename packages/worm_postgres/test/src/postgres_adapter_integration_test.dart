/// Live-database smoke tests for [PostgresAdapter].
///
/// Gated by the `PG_DB` environment variable. Skipped
/// gracefully when the variable is absent.
@TestOn('vm')
library;

import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_postgres/worm_postgres.dart';

PredicateTree _leaf({
  required String field,
  required Operator op,
  Object? value,
}) => LeafNode(Predicate(fieldName: field, operator: op, value: value));

/// Minimal row-backed model for eager-loading integration. Uses a
/// private row map (not the package-internal `state`) so it works from
/// this downstream package.
final class _EUser extends Model {
  _EUser.fromRow(this._row) {
    markPersisted();
  }
  final Map<String, Object?> _row;
  @override
  Object get id => _row['id'] ?? 0;
  @override
  Map<String, Object?> toRow() => Map<String, Object?>.unmodifiable(_row);
}

final class _EPost extends Model {
  _EPost.fromRow(this._row) {
    markPersisted();
  }
  final Map<String, Object?> _row;
  @override
  Object get id => _row['id'] ?? 0;
  @override
  Map<String, Object?> toRow() => Map<String, Object?>.unmodifiable(_row);
}

void main() {
  final url = Platform.environment['PG_DB'];
  if (url == null || url.isEmpty) {
    test(
      'PostgresAdapter integration tests skipped — PG_DB unset',
      () {},
      skip:
          'Set PG_DB (postgres://user:pass@host:port/db) to '
          'run live-database integration tests.',
    );
    return;
  }

  group('PostgresAdapter integration', () {
    late PostgresAdapter adapter;

    setUp(() async {
      final pool = PostgresConnectionPool(
        pool: Pool<Object?>.withUrl(url),
        maxConnectionCount: 4,
      );
      adapter = PostgresAdapter(pool: pool);
      await adapter.executeSchema(
        const SchemaDescriptor.dropTable(table: 'widgets', ifExists: true),
      );
      await adapter.executeSchema(
        const SchemaDescriptor.createTable(
          table: 'widgets',
          columns: <SchemaColumn>[
            SchemaColumn(
              name: 'id',
              type: ColumnType.integer,
              isPrimaryKey: true,
            ),
            SchemaColumn(name: 'label', type: ColumnType.text),
          ],
        ),
      );
    });

    tearDown(() async {
      await adapter.executeSchema(
        const SchemaDescriptor.dropTable(table: 'widgets', ifExists: true),
      );
      await adapter.disconnect();
    });

    test('declares the expected AdapterCapabilities', () {
      expect(adapter.capabilities.supportsTransactions, isTrue);
      expect(adapter.capabilities.supportsSavepoints, isTrue);
      expect(adapter.capabilities.supportsReturning, isTrue);
      expect(adapter.capabilities.supportsExplain, isTrue);
      expect(adapter.capabilities.supportsPreparedStatements, isTrue);
      expect(adapter.capabilities.supportsJoins, isTrue);
      expect(adapter.capabilities.supportsAggregations, isTrue);
    });

    test('insert returns the row including server-generated columns', () async {
      final inserted = await adapter.insert(
        const InsertDescriptor(
          table: 'widgets',
          values: <String, Object?>{'id': 1, 'label': 'A'},
        ),
      );
      expect(inserted['id'], 1);
      expect(inserted['label'], 'A');
    });

    test('update returns the affected row count', () async {
      await adapter.insertMany(
        const InsertManyDescriptor(
          table: 'widgets',
          rows: <Map<String, Object?>>[
            <String, Object?>{'id': 1, 'label': 'A'},
            <String, Object?>{'id': 2, 'label': 'B'},
          ],
        ),
      );
      final count = await adapter.update(
        UpdateDescriptor(
          table: 'widgets',
          values: const <String, Object?>{'label': 'X'},
          where: _leaf(field: 'id', op: Operator.eq, value: 1),
        ),
      );
      expect(count, 1);
    });

    test('delete returns the deleted row count', () async {
      await adapter.insertMany(
        const InsertManyDescriptor(
          table: 'widgets',
          rows: <Map<String, Object?>>[
            <String, Object?>{'id': 1, 'label': 'A'},
            <String, Object?>{'id': 2, 'label': 'B'},
          ],
        ),
      );
      final count = await adapter.delete(
        const DeleteDescriptor(table: 'widgets'),
      );
      expect(count, 2);
    });

    test('count returns an int matching the matching rows', () async {
      await adapter.insertMany(
        const InsertManyDescriptor(
          table: 'widgets',
          rows: <Map<String, Object?>>[
            <String, Object?>{'id': 1, 'label': 'A'},
            <String, Object?>{'id': 2, 'label': 'B'},
            <String, Object?>{'id': 3, 'label': 'C'},
          ],
        ),
      );
      final total = await adapter.count(
        const AggregateDescriptor.count(table: 'widgets'),
      );
      expect(total, 3);
    });

    test('stream yields every row from select()', () async {
      await adapter.insertMany(
        const InsertManyDescriptor(
          table: 'widgets',
          rows: <Map<String, Object?>>[
            <String, Object?>{'id': 1, 'label': 'A'},
            <String, Object?>{'id': 2, 'label': 'B'},
          ],
        ),
      );
      const descriptor = QueryDescriptor(
        table: 'widgets',
        orderBy: <SortClause>[SortClause('id')],
      );
      final streamed = await adapter.stream(descriptor).toList();
      final selected = await adapter.select(descriptor);
      expect(streamed, selected);
    });

    test('explain returns an ExplainResult with non-empty plan', () async {
      final result = await adapter.explain(
        const QueryDescriptor(table: 'widgets'),
      );
      expect(result.raw, isNotEmpty);
    });

    test(
      'prepared statement cache reports steady-state low miss rate',
      () async {
        // Reset counters so the measurement isolates steady-state
        // SELECT behaviour from setUp's DDL (which also flows through
        // the shared prepared-statement cache). Running the same query
        // 21× then yields one cold miss followed by 20 hits, leaving
        // the miss rate well under the 5% target.
        adapter.preparedStatementCache.clear();
        const descriptor = QueryDescriptor(table: 'widgets');
        for (var i = 0; i < 21; i++) {
          await adapter.select(descriptor);
        }
        expect(adapter.preparedStatementCache.missRate, lessThan(0.05));
      },
    );
  });

  group('PostgresAdapter eager loading (concurrent + projected)', () {
    late PostgresAdapter adapter;

    setUp(() async {
      final pool = PostgresConnectionPool(
        pool: Pool<Object?>.withUrl(url),
        maxConnectionCount: 4,
      );
      adapter = PostgresAdapter(pool: pool);
      for (final table in <String>['e_posts', 'e_users']) {
        await adapter.executeSchema(
          SchemaDescriptor.dropTable(table: table, ifExists: true),
        );
      }
      await adapter.executeSchema(
        const SchemaDescriptor.createTable(
          table: 'e_users',
          columns: <SchemaColumn>[
            SchemaColumn(
              name: 'id',
              type: ColumnType.integer,
              isPrimaryKey: true,
            ),
            SchemaColumn(name: 'name', type: ColumnType.text),
          ],
        ),
      );
      await adapter.executeSchema(
        const SchemaDescriptor.createTable(
          table: 'e_posts',
          columns: <SchemaColumn>[
            SchemaColumn(
              name: 'id',
              type: ColumnType.integer,
              isPrimaryKey: true,
            ),
            SchemaColumn(name: 'user_id', type: ColumnType.integer),
            SchemaColumn(name: 'views', type: ColumnType.integer),
          ],
        ),
      );
      await adapter.insertMany(
        const InsertManyDescriptor(
          table: 'e_users',
          rows: <Map<String, Object?>>[
            <String, Object?>{'id': 1, 'name': 'Alice'},
            <String, Object?>{'id': 2, 'name': 'Bob'},
          ],
        ),
      );
      await adapter.insertMany(
        const InsertManyDescriptor(
          table: 'e_posts',
          rows: <Map<String, Object?>>[
            <String, Object?>{'id': 10, 'user_id': 1, 'views': 100},
            <String, Object?>{'id': 11, 'user_id': 1, 'views': 50},
            <String, Object?>{'id': 12, 'user_id': 2, 'views': 7},
          ],
        ),
      );
    });

    tearDown(() async {
      for (final table in <String>['e_posts', 'e_users']) {
        await adapter.executeSchema(
          SchemaDescriptor.dropTable(table: table, ifExists: true),
        );
      }
      await adapter.disconnect();
    });

    test('relation + concurrent count/sum aggregates resolve correctly '
        'against the live connection pool', () async {
      final context = QueryContext<_EUser>(
        adapter: adapter,
        table: 'e_users',
        hydrate: _EUser.fromRow,
        relations: <String, Relation<Model, Model>>{
          'posts': const HasManyRelation<Model, Model>(
            name: 'posts',
            childTable: 'e_posts',
            foreignKey: 'user_id',
            hydrateChild: _EPost.fromRow,
          ),
        },
      );

      final users = await QueryBuilder<_EUser>.from(context)
          .orderBy(const Field<int>('id'))
          .withRelationPaths(const <String>['posts'])
          .withCount('posts')
          .withSum('posts', 'views')
          .get();

      expect(users, hasLength(2));
      final alice = users.first;
      expect(alice.getRelation<List<Model>>('posts'), hasLength(2));
      expect(alice.getInjected<int>('postsCount'), 2);
      expect(alice.getInjected<num>('postsSum'), 150);
      expect(users[1].getInjected<int>('postsCount'), 1);
    });
  });
}
