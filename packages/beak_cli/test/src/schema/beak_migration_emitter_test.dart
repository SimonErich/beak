import 'package:beak_cli/beak_cli.dart';
import 'package:test/test.dart';

/// A schema over [table] with one string column, plus any [relations].
BeakSchemaIr schemaFor(
  String className,
  String table, {
  List<BeakRelationIr> relations = const [],
  bool managesSchema = true,
}) => BeakSchemaIr(
  className: className,
  table: table,
  libraryPath: 'models/${table.replaceAll(RegExp(r's$'), '')}.dart',
  columns: const [
    BeakColumnIr(
      fieldName: 'name',
      columnKey: 'name',
      label: 'Name',
      kind: BeakColumnKind.string,
      isRequired: true,
      arguments: {},
    ),
  ],
  relations: relations,
  displayColumnKey: 'name',
  softDeletes: false,
  timestamps: false,
  managesSchema: managesSchema,
);

/// A many-to-many from the owning side.
const BeakRelationIr tagsRelation = BeakRelationIr(
  fieldName: 'tags',
  key: 'tags',
  label: 'Tags',
  kind: BeakRelationKind.belongsToMany,
  relatedSchema: 'Tag',
  arguments: {},
);

/// The discovered symbol a schema class produces.
BeakDiscoveredSymbol symbolFor(String className, String table) =>
    BeakDiscoveredSymbol(
      name: '${className}Model',
      importPath: 'models/$table.dart',
      isConstructible: true,
      table: table,
    );

List<BeakMigrationFile> missingFor({
  required List<BeakSchemaIr> schemas,
  Set<String> coveredTables = const {},
}) => BeakMigrationEmitter.missing(
  models: [for (final s in schemas) symbolFor(s.className, s.table)],
  schemas: schemas,
  coveredTables: coveredTables,
  now: DateTime.utc(2026),
);

void main() {
  group('what is missing', () {
    test('a table with no migration gets one', () {
      final files = missingFor(schemas: [schemaFor('Product', 'products')]);

      expect(files.map((f) => f.table), <String>['products']);
      expect(files.single.path, contains('create_products_table.dart'));
      expect(files.single.contents, contains("schema.create('products'"));
    });

    test('a table a migration already creates gets nothing', () {
      final files = missingFor(
        schemas: [schemaFor('Product', 'products')],
        coveredTables: const {'products'},
      );

      expect(files, isEmpty);
    });

    test('a table another system migrates is never generated for', () {
      final files = missingFor(
        schemas: [schemaFor('Ledger', 'ledgers', managesSchema: false)],
      );

      expect(files, isEmpty);
    });

    test('timestamps step one second apart, so dependencies keep order', () {
      final files = missingFor(
        schemas: [
          schemaFor('Category', 'categories'),
          schemaFor('Tag', 'tags'),
        ],
      );

      // The path is not timestamped; the migration's own `name` getter is,
      // and that is what worm orders by.
      final stamps = <String>[
        for (final file in files)
          if (RegExp(r'(\d{8}_\d{6})').firstMatch(file.contents)
              case final RegExpMatch match)
            match.group(1)!,
      ];
      expect(stamps, hasLength(2));
      expect(stamps.first, isNot(stamps.last));
      expect(List<String>.of(stamps)..sort(), stamps);
    });
  });

  group('pivots', () {
    List<BeakMigrationFile> forProductAndTag({
      Set<String> coveredTables = const {},
    }) => missingFor(
      schemas: [
        schemaFor('Product', 'products', relations: const [tagsRelation]),
        schemaFor('Tag', 'tags'),
      ],
      coveredTables: coveredTables,
    );

    test('a many-to-many gets a pivot migration, written last', () {
      final files = forProductAndTag();

      expect(files.map((f) => f.table), <String>[
        'products',
        'tags',
        'product_tag',
      ]);
      expect(files.last.contents, contains('BeakBlueprint.createPivot'));
    });

    test('a pivot already created by its relation constant is skipped', () {
      // A hand-written `createPivot(schema, ProductRelations.tags, …)` names
      // its table through the constant, which unresolved AST cannot resolve —
      // so coverage records the constant itself.
      final files = forProductAndTag(
        coveredTables: const {'ProductRelations.tags'},
      );

      expect(files.map((f) => f.table), isNot(contains('product_tag')));
    });

    test('a covered pivot does not make its owner look covered', () {
      // The regression: the pivot migration passes `ownerTable: 'products'`,
      // and coverage detection used to record that as a table the migration
      // creates. Deleting create_products_table.dart then left `products`
      // looking covered, so `beak prepare` never wrote it back and
      // `beak doctor` reported all clear — gap A, through the check meant to
      // prevent it.
      final files = forProductAndTag(
        coveredTables: const {'tags', 'ProductRelations.tags'},
      );

      expect(files.map((f) => f.table), <String>['products']);
    });
  });
}
