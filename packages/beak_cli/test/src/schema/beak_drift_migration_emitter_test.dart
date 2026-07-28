import 'package:beak_cli/beak_cli.dart';
import 'package:test/test.dart';

/// A schema over [table] declaring [fields].
BeakSchemaIr schemaWith(
  String className,
  String table,
  List<String> fields, {
  bool softDeletes = false,
  bool required = false,
  Map<String, String> options = const {},
}) => BeakSchemaIr(
  className: className,
  table: table,
  libraryPath: 'models/${className.toLowerCase()}.dart',
  columns: [
    for (final field in fields)
      BeakColumnIr(
        fieldName: field,
        columnKey: field,
        label: field,
        kind: BeakColumnKind.integer,
        isRequired: required,
        arguments: options,
      ),
  ],
  relations: const [],
  displayColumnKey: fields.first,
  softDeletes: softDeletes,
  timestamps: false,
  managesSchema: true,
);

/// [table] as the database has it, holding [columns].
IntrospectedTable tableWith(String table, List<String> columns) =>
    IntrospectedTable(
      name: table,
      columns: [
        for (final name in columns)
          IntrospectedColumn(name: name, dataType: 'text', isNullable: true),
      ],
      foreignKeys: const [],
      primaryKey: 'id',
    );

String? emitFor({
  required List<BeakSchemaIr> schemas,
  required List<IntrospectedTable> tables,
}) => BeakDriftMigrationEmitter.emit(
  className: 'AddStockToProducts',
  timestamp: '20260728_120000',
  description: 'Add stock to products',
  drift: beakSchemaDrift(schemas: schemas, tables: tables),
);

void main() {
  group('what it will write a migration for', () {
    test('a column a field declares', () {
      final drift = beakSchemaDrift(
        schemas: [
          schemaWith('Product', 'products', ['name', 'stock']),
        ],
        tables: [
          tableWith('products', ['id', 'name']),
        ],
      );

      expect(BeakDriftMigrationEmitter.addable(drift), hasLength(1));
      expect(
        BeakDriftMigrationEmitter.addable(drift).single.columnKey,
        'stock',
      );
    });

    test('not a table that does not exist', () {
      // A resource that was never migrated needs a create migration, which
      // `beak prepare` already writes.
      final drift = beakSchemaDrift(
        schemas: [
          schemaWith('Product', 'products', ['name']),
        ],
        tables: const [],
      );

      expect(BeakDriftMigrationEmitter.addable(drift), isEmpty);
    });

    test('not a column the schema implies rather than declares', () {
      // Turning `softDeletes` on changes more than the table, so the column
      // is reported and left to a person.
      final drift = beakSchemaDrift(
        schemas: [
          schemaWith('Product', 'products', ['name'], softDeletes: true),
        ],
        tables: [
          tableWith('products', ['id', 'name']),
        ],
      );

      expect(drift, isNotEmpty);
      expect(BeakDriftMigrationEmitter.addable(drift), isEmpty);
    });

    test('not a column the database has and no schema declares', () {
      final drift = beakSchemaDrift(
        schemas: [
          schemaWith('Product', 'products', ['name']),
        ],
        tables: [
          tableWith('products', ['id', 'name', 'legacy_sku']),
        ],
      );

      expect(drift, isNotEmpty);
      expect(BeakDriftMigrationEmitter.addable(drift), isEmpty);
    });
  });

  group('the migration it writes', () {
    test('adds the column through the same mapping the create used', () {
      final source = emitFor(
        schemas: [
          schemaWith('Product', 'products', ['name', 'stock']),
        ],
        tables: [
          tableWith('products', ['id', 'name']),
        ],
      );

      expect(source, isNotNull);
      // Not a spelled-out `table.integer('stock')`: that would be a second
      // answer to what SQL a Beak column becomes, free to drift from the one
      // the create migration used.
      expect(
        source,
        contains('BeakBlueprint.defineColumn(table, ProductColumns.stock)'),
      );
      expect(source, contains("schema.alter('products'"));
      expect(source, contains("String get name => '20260728_120000_add_stock"));
    });

    test('rolls back by dropping exactly what it added', () {
      final source = emitFor(
        schemas: [
          schemaWith('Product', 'products', ['name', 'stock']),
        ],
        tables: [
          tableWith('products', ['id', 'name']),
        ],
      );

      expect(source, contains("table.dropColumn('stock')"));
    });

    test('groups several tables into one migration, in a stable order', () {
      final source = emitFor(
        schemas: [
          schemaWith('Product', 'products', ['name', 'stock']),
          schemaWith('Order', 'orders', ['reference', 'total']),
        ],
        tables: [
          tableWith('products', ['id', 'name']),
          tableWith('orders', ['id', 'reference']),
        ],
      );

      expect(source, contains("schema.alter('orders'"));
      expect(source, contains("schema.alter('products'"));
      expect(
        source!.indexOf("schema.alter('orders'"),
        lessThan(source.indexOf("schema.alter('products'")),
      );
    });

    test('imports the model of every table it touches', () {
      final source = emitFor(
        schemas: [
          schemaWith('Product', 'products', ['name', 'stock']),
        ],
        tables: [
          tableWith('products', ['id', 'name']),
        ],
      );

      expect(source, contains("import '../models/product.dart'"));
    });

    test('is nothing at all when there is nothing to add', () {
      expect(
        emitFor(
          schemas: [
            schemaWith('Product', 'products', ['name']),
          ],
          tables: [
            tableWith('products', ['id', 'name']),
          ],
        ),
        isNull,
      );
    });

    test('is formatted, so `dart format` on the project is a no-op', () {
      final source = emitFor(
        schemas: [
          schemaWith('Product', 'products', ['name', 'stock']),
        ],
        tables: [
          tableWith('products', ['id', 'name']),
        ],
      );

      expect(BeakEmitters.format(source!), source);
    });
  });

  group('a column a live table cannot gain', () {
    List<BeakDrift> driftFor(BeakSchemaIr schema) => beakSchemaDrift(
      schemas: [schema],
      tables: [
        tableWith('products', ['id']),
      ],
    );

    test('a required column with no default is refused, not written', () {
      // Every database refuses a NOT NULL column on a table that already has
      // rows unless it is told what those rows should hold. Writing it anyway
      // hands someone a migration `beak migrate` rejects, after telling them
      // the fix was written.
      final drift = driftFor(
        schemaWith('Product', 'products', ['stock'], required: true),
      );

      expect(BeakDriftMigrationEmitter.addable(drift), isEmpty);
      expect(
        BeakDriftMigrationEmitter.unaddable(drift).values.single,
        contains('needs a value for the rows already there'),
      );
    });

    test('a required column with a default is written', () {
      final drift = driftFor(
        schemaWith(
          'Product',
          'products',
          ['stock'],
          required: true,
          options: const {'defaultValue': '0'},
        ),
      );

      expect(BeakDriftMigrationEmitter.addable(drift), hasLength(1));
      expect(BeakDriftMigrationEmitter.unaddable(drift), isEmpty);
    });

    test('a unique column is refused, with the three-step way round', () {
      final drift = driftFor(
        schemaWith(
          'Product',
          'products',
          ['sku'],
          options: const {'unique': 'true'},
        ),
      );

      expect(BeakDriftMigrationEmitter.addable(drift), isEmpty);
      expect(
        BeakDriftMigrationEmitter.unaddable(drift).values.single,
        contains('backfill'),
      );
    });

    test('nothing addable means no migration at all', () {
      expect(
        BeakDriftMigrationEmitter.emit(
          className: 'AddStock',
          timestamp: '20260728_120000',
          description: 'Add stock',
          drift: driftFor(
            schemaWith('Product', 'products', ['stock'], required: true),
          ),
        ),
        isNull,
      );
    });
  });
}
