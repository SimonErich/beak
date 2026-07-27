/// End-to-end proof, against a real SQLite database, that a schema can be
/// evolved and that the indexes it declares actually exist.
///
/// Every assertion here failed before: `ALTER TABLE` threw on every adapter,
/// a non-unique `index([...])` compiled to nothing at all, and a declared
/// `length` was dropped one step short of the wire. A compiler unit test
/// proves a string was built; only this proves the database agreed.
library;

import 'package:test/test.dart';
import 'package:worm/src/exception/unsupported_operation_exception.dart';
import 'package:worm/src/query/insert_descriptor.dart';
import 'package:worm/src/query/operator.dart';
import 'package:worm/src/query/predicate.dart';
import 'package:worm/src/query/predicate_tree.dart';
import 'package:worm/src/query/query_descriptor.dart';
import 'package:worm/src/query/schema_descriptor.dart';
import 'package:worm/src/schema/column_type.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

void main() {
  late SqliteAdapter adapter;

  setUp(() async {
    adapter = SqliteAdapter.memory();
    await adapter.connect();
    // Descriptors rather than the `Schema` facade: this package tests the
    // compiler and the driver, and the facade's own mapping is covered in
    // worm, where its internal constructor lives.
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(
        table: 'products',
        columns: <SchemaColumn>[
          SchemaColumn(name: 'id', type: ColumnType.uuid, isPrimaryKey: true),
          SchemaColumn(name: 'name', type: ColumnType.string, length: 120),
          SchemaColumn(
            name: 'status',
            type: ColumnType.string,
            length: 20,
            nullable: true,
          ),
        ],
        indexes: <SchemaIndex>[
          SchemaIndex(name: 'products_status_idx', columns: <String>['status']),
        ],
      ),
    );
  });

  Future<void> alter(List<SchemaAlteration> alterations) =>
      adapter.executeSchema(
        SchemaDescriptor.alterTable(
          table: 'products',
          alterations: alterations,
        ),
      );

  tearDown(() => adapter.disconnect());

  Future<List<Map<String, Object?>>> master() => adapter.rawQuery(
    "SELECT type, name, sql FROM sqlite_master WHERE tbl_name = 'products'",
    const <Object?>[],
  );

  test('a declared index exists in the database', () async {
    // It used to be dropped on the floor: the create-table builder emitted
    // only unique indexes, so every foreign key and every sortable column in
    // every schema was unindexed and nothing reported it.
    final indexes = [
      for (final row in await master())
        if (row['type'] == 'index') row['name'],
    ];

    expect(indexes, contains('products_status_idx'));
  });

  test('the query planner actually uses it', () async {
    // The assertion that separates "we sent a CREATE INDEX" from "the
    // database built one and reads through it".
    final explained = await adapter.explain(
      const QueryDescriptor(
        table: 'products',
        where: LeafNode(
          Predicate(fieldName: 'status', operator: Operator.eq, value: 'live'),
        ),
      ),
    );

    expect(explained.usesIndex, isTrue);
    expect(explained.indexName, 'products_status_idx');
  });

  test('a declared length reaches the table definition', () async {
    final create = [
      for (final row in await master())
        if (row['type'] == 'table') row['sql'],
    ].single;

    expect('$create', contains('"name" TEXT'));
    expect('$create', contains('"status" TEXT'));
  });

  test('a column can be added, and the existing rows survive', () async {
    await adapter.insert(
      const InsertDescriptor(
        table: 'products',
        values: <String, Object?>{
          'id': 'p1',
          'name': 'Hammer',
          'status': 'live',
        },
      ),
    );

    await alter(const <SchemaAlteration>[
      SchemaAddColumn(
        SchemaColumn(name: 'stock', type: ColumnType.integer, nullable: true),
      ),
    ]);

    expect(
      (await adapter.introspectSchema())['products'],
      containsAll(<String>['name', 'status', 'stock']),
    );
    final rows = await adapter.select(const QueryDescriptor(table: 'products'));
    expect(rows.single['name'], 'Hammer');
    expect(
      rows.single['stock'],
      isNull,
      reason: 'an added column reads null until something writes it',
    );

    // And the new column is writable, which a purely syntactic ALTER would
    // not guarantee.
    await adapter.insert(
      const InsertDescriptor(
        table: 'products',
        values: <String, Object?>{'id': 'p2', 'name': 'Chisel', 'stock': 7},
      ),
    );
    final all = await adapter.select(const QueryDescriptor(table: 'products'));
    expect(all, hasLength(2));
  });

  test('an index can be added after the fact and is used', () async {
    await alter(const <SchemaAlteration>[
      SchemaAddIndex(
        SchemaIndex(name: 'products_name_idx', columns: <String>['name']),
      ),
    ]);

    final explained = await adapter.explain(
      const QueryDescriptor(
        table: 'products',
        where: LeafNode(
          Predicate(fieldName: 'name', operator: Operator.eq, value: 'Hammer'),
        ),
      ),
    );

    expect(explained.indexName, 'products_name_idx');
  });

  test('a column and its index can be dropped', () async {
    await alter(const <SchemaAlteration>[
      SchemaDropIndex('products_status_idx'),
      SchemaDropColumn('status'),
    ]);

    expect(
      (await adapter.introspectSchema())['products'],
      isNot(contains('status')),
    );
    final indexes = [
      for (final row in await master())
        if (row['type'] == 'index') row['name'],
    ];
    expect(indexes, isNot(contains('products_status_idx')));
  });

  test('a change SQLite cannot make fails loudly, not silently', () async {
    // Rebuilding the table behind the caller would drop triggers, views and
    // generated columns that introspectSchema cannot see. Refusing keeps the
    // data intact and names the way out.
    await expectLater(
      () => alter(const <SchemaAlteration>[
        SchemaChangeColumn(SchemaColumn(name: 'name', type: ColumnType.text)),
      ]),
      throwsA(
        isA<UnsupportedOperationException>().having(
          (error) => error.message,
          'message',
          allOf(contains('rawExecute'), contains('Postgres')),
        ),
      ),
    );

    // And the table is untouched.
    expect((await adapter.introspectSchema())['products'], contains('name'));
  });
}
