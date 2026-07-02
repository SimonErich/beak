/// Prepared-statement cache + WAL behaviour on the live SqliteAdapter.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

const SchemaDescriptor _createWidgets = SchemaDescriptor.createTable(
  table: 'widgets',
  columns: <SchemaColumn>[
    SchemaColumn(name: 'id', type: ColumnType.integer, isPrimaryKey: true),
  ],
);

const SchemaDescriptor _dropWidgets = SchemaDescriptor.dropTable(
  table: 'widgets',
  ifExists: true,
);

void main() {
  test('prepared cache reaches a low steady-state miss rate', () async {
    final adapter = SqliteAdapter.memory();
    await adapter.connect();
    await adapter.executeSchema(_createWidgets);
    // DDL clears the cache; reset counters for a clean measurement.
    adapter.preparedStatementCache.clear();

    const query = QueryDescriptor(table: 'widgets');
    for (var i = 0; i < 21; i++) {
      await adapter.select(query);
    }
    // One cold miss + 20 hits = 1/21 ≈ 0.048.
    expect(adapter.preparedStatementCache.missRate, lessThan(0.05));
    expect(adapter.preparedStatementCache.hitCount, 20);
    await adapter.disconnect();
  });

  test('a cached SELECT survives a table drop + recreate', () async {
    final adapter = SqliteAdapter.memory();
    await adapter.connect();
    await adapter.executeSchema(_createWidgets);
    await adapter.insert(
      const InsertDescriptor(
        table: 'widgets',
        values: <String, Object?>{'id': 1},
      ),
    );
    const query = QueryDescriptor(table: 'widgets');
    expect(await adapter.select(query), hasLength(1)); // caches the statement

    // Recreating the table invalidates any statement referencing it;
    // the cache is cleared on DDL so the next select re-prepares.
    await adapter.executeSchema(_dropWidgets);
    await adapter.executeSchema(_createWidgets);
    expect(await adapter.select(query), isEmpty);
    await adapter.disconnect();
  });

  test('connect enables WAL + foreign keys on a file database', () async {
    final dir = Directory.systemTemp.createTempSync('worm_sqlite_test');
    final adapter = SqliteAdapter.open('${dir.path}/test.db');
    try {
      await adapter.connect();
      final journal = await adapter.rawQuery(
        'PRAGMA journal_mode',
        const <Object?>[],
      );
      expect(journal.first['journal_mode'], 'wal');
      final foreignKeys = await adapter.rawQuery(
        'PRAGMA foreign_keys',
        const <Object?>[],
      );
      expect(foreignKeys.first['foreign_keys'], 1);
    } finally {
      await adapter.disconnect();
      dir.deleteSync(recursive: true);
    }
  });
}
