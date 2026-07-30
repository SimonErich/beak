/// Live-Postgres proof that a schema can be evolved and that what a
/// migration declares is what the database ends up with.
///
/// Gated by `PG_DB`, like the other integration suites here. Skipped
/// gracefully when it is unset.
///
/// Every assertion here failed before: `ALTER TABLE` threw on every adapter,
/// a non-unique `index([...])` compiled to nothing, and a declared `length`
/// or `precision` was dropped one step short of the wire — so a
/// `VARCHAR(120)` arrived as a bare `VARCHAR`.
@TestOn('vm')
library;

import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'package:worm/worm.dart';
import 'package:worm_postgres/worm_postgres.dart';

void main() {
  final url = Platform.environment['PG_DB'];
  if (url == null) {
    test(
      'schema-evolution integration tests skipped — PG_DB unset',
      () {},
      skip:
          'Set PG_DB (postgres://user:pass@host:port/db) to run the '
          'schema-evolution suite.',
    );
    return;
  }

  late PostgresAdapter adapter;

  setUp(() async {
    adapter = PostgresAdapter(
      pool: PostgresConnectionPool(
        pool: Pool<Object?>.withUrl(url),
        maxConnectionCount: 4,
      ),
    );
    await adapter.connect();
    await adapter.rawExecute('DROP TABLE IF EXISTS evo_products', const []);
    // Descriptors rather than the `Schema` facade: this package tests the
    // compiler and the driver, and the facade's own mapping is covered in
    // worm, where its internal constructor lives.
    await adapter.executeSchema(
      const SchemaDescriptor.createTable(
        table: 'evo_products',
        columns: <SchemaColumn>[
          SchemaColumn(name: 'id', type: ColumnType.uuid, isPrimaryKey: true),
          SchemaColumn(name: 'name', type: ColumnType.string, length: 120),
          SchemaColumn(name: 'sku', type: ColumnType.string, length: 40),
          SchemaColumn(
            name: 'price',
            type: ColumnType.decimal,
            precision: 10,
            scale: 2,
          ),
          SchemaColumn(
            name: 'status',
            type: ColumnType.string,
            length: 20,
            nullable: true,
          ),
        ],
        indexes: <SchemaIndex>[
          SchemaIndex(
            name: 'evo_products_sku_key',
            columns: <String>['sku'],
            unique: true,
          ),
          SchemaIndex(
            name: 'evo_products_status_idx',
            columns: <String>['status'],
          ),
        ],
      ),
    );
  });

  tearDown(() async {
    await adapter.rawExecute('DROP TABLE IF EXISTS evo_products', const []);
    await adapter.disconnect();
  });

  Future<void> alter(List<SchemaAlteration> alterations) =>
      adapter.executeSchema(
        SchemaDescriptor.alterTable(
          table: 'evo_products',
          alterations: alterations,
        ),
      );

  Future<Map<String, Map<String, Object?>>> columns() async {
    final rows = await adapter.rawQuery(
      'SELECT column_name, data_type, character_maximum_length, '
      'numeric_precision, numeric_scale, is_nullable '
      "FROM information_schema.columns WHERE table_name = 'evo_products'",
      const <Object?>[],
    );
    return <String, Map<String, Object?>>{
      for (final row in rows) '${row['column_name']}': row,
    };
  }

  Future<List<String>> indexNames() async {
    final rows = await adapter.rawQuery(
      "SELECT indexname FROM pg_indexes WHERE tablename = 'evo_products'",
      const <Object?>[],
    );
    return <String>[for (final row in rows) '${row['indexname']}'];
  }

  test('a declared length and precision reach the database', () async {
    // The round trip used to be lossy here: introspecting a schema, writing
    // the models, deriving the migrations and applying them gave back
    // `character varying` with no length at all.
    final byName = await columns();

    expect(byName['name']!['character_maximum_length'], 120);
    expect(byName['sku']!['character_maximum_length'], 40);
    expect(byName['price']!['numeric_precision'], 10);
    expect(byName['price']!['numeric_scale'], 2);
  });

  test(
    'a non-unique index exists, and a column-level unique became one',
    () async {
      // The non-unique index used to emit no SQL whatsoever.
      expect(
        await indexNames(),
        containsAll(<String>[
          'evo_products_status_idx',
          'evo_products_sku_key',
        ]),
      );
    },
  );

  test('a column can be added and the existing rows survive', () async {
    await adapter.rawExecute(
      'INSERT INTO evo_products (id, name, sku, price, status) VALUES '
      "('11111111-1111-1111-1111-111111111111', 'Hammer', 'HM-1', 19.5, "
      "'live')",
      const <Object?>[],
    );

    await alter(const <SchemaAlteration>[
      SchemaAddColumn(
        SchemaColumn(name: 'stock', type: ColumnType.integer, nullable: true),
      ),
    ]);

    expect(await columns(), contains('stock'));
    final rows = await adapter.rawQuery(
      'SELECT name, stock FROM evo_products',
      const <Object?>[],
    );
    expect(rows.single['name'], 'Hammer');
    expect(rows.single['stock'], isNull);
  });

  test('a column type, nullability and default can be changed', () async {
    await alter(const <SchemaAlteration>[
      SchemaChangeColumn(
        SchemaColumn(
          name: 'name',
          type: ColumnType.string,
          length: 200,
          nullable: true,
          defaultValue: 'untitled',
        ),
      ),
    ]);

    final name = (await columns())['name']!;
    expect(name['character_maximum_length'], 200);
    expect(name['is_nullable'], 'YES');
  });

  test('an index can be added and dropped after the fact', () async {
    await alter(const <SchemaAlteration>[
      SchemaAddIndex(
        SchemaIndex(name: 'evo_products_name_idx', columns: <String>['name']),
      ),
    ]);
    expect(await indexNames(), contains('evo_products_name_idx'));

    await alter(const <SchemaAlteration>[
      SchemaDropIndex('evo_products_name_idx'),
    ]);
    expect(await indexNames(), isNot(contains('evo_products_name_idx')));
  });

  test('a foreign key can be added and dropped after the fact', () async {
    await adapter.rawExecute(
      'CREATE TABLE IF NOT EXISTS evo_brands (id UUID PRIMARY KEY)',
      const <Object?>[],
    );
    addTearDown(
      () => adapter.rawExecute('DROP TABLE IF EXISTS evo_brands', const []),
    );

    await alter(const <SchemaAlteration>[
      SchemaAddColumn(
        SchemaColumn(name: 'brand_id', type: ColumnType.uuid, nullable: true),
      ),
      SchemaAddForeignKey(
        SchemaForeignKey(
          columns: <String>['brand_id'],
          referencedTable: 'evo_brands',
          referencedColumns: <String>['id'],
          onDelete: OnDelete.setNull,
          name: 'evo_products_brand_fk',
        ),
      ),
    ]);

    final constraints = await adapter.rawQuery(
      'SELECT conname FROM pg_constraint WHERE conname = '
      "'evo_products_brand_fk'",
      const <Object?>[],
    );
    expect(constraints, hasLength(1));

    await alter(const <SchemaAlteration>[
      SchemaDropForeignKey('evo_products_brand_fk'),
    ]);
    expect(
      await adapter.rawQuery(
        'SELECT conname FROM pg_constraint WHERE conname = '
        "'evo_products_brand_fk'",
        const <Object?>[],
      ),
      isEmpty,
    );
  });

  test('a dropped column really goes away', () async {
    await alter(const <SchemaAlteration>[
      SchemaDropIndex('evo_products_status_idx'),
      SchemaDropColumn('status'),
    ]);

    expect(await columns(), isNot(contains('status')));
  });
}
