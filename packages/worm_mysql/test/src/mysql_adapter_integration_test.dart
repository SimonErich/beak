/// Live-database smoke tests for [MysqlAdapter].
///
/// Gated by `MYSQL_URL`. Skipped gracefully when absent.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_mysql/worm_mysql.dart';

PredicateTree _idEq(int id) =>
    LeafNode(Predicate(fieldName: 'id', operator: Operator.eq, value: id));

void main() {
  final url = Platform.environment['MYSQL_URL'];
  if (url == null || url.isEmpty) {
    test(
      'MysqlAdapter integration suite skipped — MYSQL_URL unset',
      () {},
      skip:
          'Set MYSQL_URL (mysql://user:pass@host:port/db) to '
          'run the MySQL integration smoke tests.',
    );
    return;
  }

  group('MysqlAdapter integration', () {
    late MysqlAdapter adapter;

    setUp(() async {
      adapter = MysqlAdapter(pool: MysqlConnectionPool.fromUri(url));
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
            SchemaColumn(name: 'name', type: ColumnType.text),
            SchemaColumn(name: 'qty', type: ColumnType.integer),
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

    test('insert without an id is enriched from LAST_INSERT_ID()', () async {
      final inserted = await adapter.insert(
        const InsertDescriptor(
          table: 'widgets',
          values: <String, Object?>{'name': 'gizmo', 'qty': 3},
        ),
      );
      // AUTO_INCREMENT generated the key; the adapter backfills `id`.
      expect(inserted['id'], isA<int>());
      expect(inserted['name'], 'gizmo');
      final row = await adapter.selectOne(
        QueryDescriptor(table: 'widgets', where: _idEq(inserted['id']! as int)),
      );
      expect(row?['name'], 'gizmo');
      expect(row?['qty'], 3);
    });

    test('insert with an explicit id returns the supplied values', () async {
      final inserted = await adapter.insert(
        const InsertDescriptor(
          table: 'widgets',
          values: <String, Object?>{'id': 42, 'name': 'cog', 'qty': 7},
        ),
      );
      expect(inserted['id'], 42);
      expect(inserted['name'], 'cog');
    });

    test('update and delete report affected-row counts', () async {
      await adapter.insertMany(
        const InsertManyDescriptor(
          table: 'widgets',
          rows: <Map<String, Object?>>[
            <String, Object?>{'id': 1, 'name': 'a', 'qty': 1},
            <String, Object?>{'id': 2, 'name': 'b', 'qty': 2},
            <String, Object?>{'id': 3, 'name': 'c', 'qty': 3},
          ],
        ),
      );
      final updated = await adapter.update(
        UpdateDescriptor(
          table: 'widgets',
          values: const <String, Object?>{'qty': 99},
          where: _idEq(2),
        ),
      );
      expect(updated, 1);
      final deleted = await adapter.delete(
        const DeleteDescriptor(
          table: 'widgets',
          where: LeafNode(
            Predicate(fieldName: 'qty', operator: Operator.gte, value: 3),
          ),
        ),
      );
      expect(deleted, 2); // id 2 (now qty 99) and id 3 (qty 3)
    });

    test('stream emits the same rows as select', () async {
      await adapter.insertMany(
        const InsertManyDescriptor(
          table: 'widgets',
          rows: <Map<String, Object?>>[
            <String, Object?>{'id': 1, 'name': 'a', 'qty': 1},
            <String, Object?>{'id': 2, 'name': 'b', 'qty': 2},
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

    test('rawQuery returns typed scalar columns', () async {
      await adapter.insert(
        const InsertDescriptor(
          table: 'widgets',
          values: <String, Object?>{'id': 1, 'name': 'a', 'qty': 5},
        ),
      );
      final rows = await adapter.rawQuery(
        'SELECT COUNT(*) AS c FROM `widgets` WHERE `qty` >= ?',
        const <Object?>[1],
      );
      expect(rows, hasLength(1));
      expect(rows.first['c'], 1);
    });

    test('explain returns a parsed plan for a live query', () async {
      await adapter.insert(
        const InsertDescriptor(
          table: 'widgets',
          values: <String, Object?>{'id': 1, 'name': 'a', 'qty': 5},
        ),
      );
      final result = await adapter.explain(
        QueryDescriptor(table: 'widgets', where: _idEq(1)),
      );
      expect(result.raw, isNotEmpty);
      expect(result.raw, contains('query_block'));
    });

    test('prepared-statement cache records reuse of identical SQL', () async {
      await adapter.insert(
        const InsertDescriptor(
          table: 'widgets',
          values: <String, Object?>{'id': 1, 'name': 'a', 'qty': 5},
        ),
      );
      adapter.preparedStatementCache.clear();
      for (var i = 0; i < 5; i++) {
        await adapter.select(
          QueryDescriptor(table: 'widgets', where: _idEq(1)),
        );
      }
      // One unique SQL string: one cold miss then four hits.
      expect(adapter.preparedStatementCache.length, 1);
      expect(adapter.preparedStatementCache.missRate, lessThan(0.5));
    });
  });
}
