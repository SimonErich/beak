import 'dart:io';

import '../../support/beak_cli_internals.dart';
import 'package:test/test.dart';

/// A schema over [table] declaring [fields].
BeakSchemaIr schemaWith(
  String className,
  String table,
  List<String> fields, {
  bool softDeletes = false,
  bool required = false,
  Map<String, String> options = const {},
  BeakColumnKind kind = BeakColumnKind.integer,
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
        kind: kind,
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

    test('imports a schema that lives in a resource folder', () {
      // It stripped a leading `models/` and prefixed `../models/` again, so a
      // schema under lib/resources/<feature>/models/ became
      // `../models/resources/products/models/product.dart`, which is no file.
      final BeakSchemaIr product = schemaWith('Product', 'products', [
        'name',
        'stock',
      ]);
      final source = emitFor(
        schemas: [
          BeakSchemaIr(
            className: product.className,
            table: product.table,
            libraryPath: 'resources/products/models/product.dart',
            columns: product.columns,
            relations: product.relations,
            displayColumnKey: product.displayColumnKey,
            softDeletes: false,
            timestamps: false,
            managesSchema: true,
          ),
        ],
        tables: [
          tableWith('products', ['id', 'name']),
        ],
      );

      expect(
        source,
        contains("import '../resources/products/models/product.dart'"),
      );
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

    test('a required bool is written, because it defaults to false', () {
      // Required boolean columns retain the conventional false default.
      final drift = driftFor(
        schemaWith(
          'Product',
          'products',
          ['active'],
          required: true,
          kind: BeakColumnKind.boolean,
        ),
      );

      expect(BeakDriftMigrationEmitter.addable(drift), hasLength(1));
      expect(BeakDriftMigrationEmitter.unaddable(drift), isEmpty);
    });

    test('a required enum with a declared default is written', () {
      final drift = driftFor(
        schemaWith(
          'Product',
          'products',
          ['status'],
          required: true,
          kind: BeakColumnKind.enumeration,
          options: const {'defaultValue': 'ProductStatus.draft'},
        ),
      );

      expect(BeakDriftMigrationEmitter.addable(drift), hasLength(1));
    });

    test('a required enum without one is refused, naming the option', () {
      final drift = driftFor(
        schemaWith(
          'Product',
          'products',
          ['status'],
          required: true,
          kind: BeakColumnKind.enumeration,
        ),
      );

      expect(
        BeakDriftMigrationEmitter.unaddable(drift).values.single,
        contains('@Column(defaultValue:'),
      );
    });

    test(
      'required scalar defaults allow safe backfilling of existing rows',
      () {
        final withoutDefault = driftFor(
          schemaWith('Product', 'products', ['stock'], required: true),
        );
        expect(
          BeakDriftMigrationEmitter.unaddable(withoutDefault).values.single,
          contains('@Column(defaultValue:'),
        );
        final withDefault = driftFor(
          schemaWith(
            'Product',
            'products',
            ['stock'],
            required: true,
            options: const {'defaultValue': '0'},
          ),
        );
        expect(BeakDriftMigrationEmitter.addable(withDefault), hasLength(1));
        final nullableBool = driftFor(
          schemaWith(
            'Product',
            'products',
            ['active'],
            required: true,
            kind: BeakColumnKind.boolean,
            options: const {'tristate': 'true'},
          ),
        );
        expect(BeakDriftMigrationEmitter.addable(nullableBool), isEmpty);
      },
    );

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
      final String why = BeakDriftMigrationEmitter.unaddable(
        drift,
      ).values.single;
      expect(why, contains('backfill'));
      // The remedy must break the loop: a nullable column still carrying
      // `unique: true` would be refused again.
      expect(why, contains('without `unique: true`'));
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

  group('against a schema class the reader really parsed', () {
    /// The IR `BeakSchemaReader` produces for a `Product` declaring [fields].
    ///
    /// Uses the same schema reader as production generation.
    BeakSchemaIr parsedProduct(String fields) {
      final root = Directory.systemTemp.createTempSync('beak_ir_');
      addTearDown(() => root.deleteSync(recursive: true));
      File('${root.path}/lib/models/product.dart')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('''
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'product.beak.dart';

/// Something for sale.
@Resource()
final class Product extends BeakSchema {
  /// What it is called.
  @Display()
  late final String name;
$fields}
''');
      final (schemas, issues) = BeakSchemaReader(root).read();
      expect(issues, isEmpty, reason: '${issues.map((i) => i.message)}');
      return schemas.single;
    }

    test('`@Column(unique: true)` reaches isUnique', () {
      final schema = parsedProduct('''
  /// A unique code.
  @Column(unique: true)
  late final String? code;
''');

      expect(
        schema.columns.firstWhere((c) => c.fieldName == 'code').isUnique,
        isTrue,
        reason: 'the refusal for a unique column never fires without this',
      );
    });

    test('a plain required field carries no default, so it is refused', () {
      final schema = parsedProduct('''
  /// Units in stock.
  late final int stock;
''');
      final drift = beakSchemaDrift(
        schemas: [schema],
        tables: [
          tableWith('products', ['id', 'name']),
        ],
      );

      expect(
        BeakDriftMigrationEmitter.unaddable(drift).keys.map((p) => p.columnKey),
        contains('stock'),
      );
    });

    test('a required bool is addable, as the blueprint would emit it', () {
      final schema = parsedProduct('''
  /// Whether it is on sale.
  late final bool active;
''');
      final drift = beakSchemaDrift(
        schemas: [schema],
        tables: [
          tableWith('products', ['id', 'name']),
        ],
      );

      expect(
        BeakDriftMigrationEmitter.addable(drift).map((p) => p.columnKey),
        contains('active'),
      );
    });
  });
}
