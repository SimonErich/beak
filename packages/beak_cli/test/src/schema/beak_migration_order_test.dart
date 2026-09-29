import 'package:test/test.dart';

import '../../support/beak_cli_internals.dart';
import 'beak_schema_test.dart' show categorySchema, productSchema, readSchemas;

BeakDiscoveredSymbol _migration(String name, String stamp) =>
    BeakDiscoveredSymbol(
      name: name,
      importPath: 'migrations/${name.toLowerCase()}.dart',
      isConstructible: true,
      sortKey: '${stamp}_$name',
    );

/// [migrations] as the host registers them, with every migration in [creates]
/// declaring its foreign keys from the model unless [frozen] names it.
List<String> _order(
  List<BeakDiscoveredSymbol> migrations, {
  required Map<String, Set<String>> creates,
  required Map<String, Set<String>> references,
  Set<String> frozen = const {},
}) => [
  for (final migration in BeakMigrationOrder.of(
    migrations: migrations,
    tablesCreatedBy: creates,
    declaresKeys: {...creates.keys}.difference(frozen),
    tablesReferencedBy: references,
  ))
    migration.name,
];

void main() {
  group('BeakMigrationOrder', () {
    final products = _migration('CreateProducts', '20260101_000000');
    final categories = _migration('CreateCategories', '20260201_000000');
    final tags = _migration('CreateTags', '20260301_000000');
    final creates = {
      'CreateProducts': {'products'},
      'CreateCategories': {'categories'},
      'CreateTags': {'tags'},
    };

    test('puts a table behind the table its foreign key points at, however '
        'late that table was created', () {
      // The products table was created first, from a model that only later
      // gained a category. A fresh database replays the migrations in order
      // and reads the model as it is now, so the constraint would point at a
      // table that does not exist yet. SQLite lets that pass; Postgres does
      // not.
      expect(
        _order(
          [products, categories],
          creates: creates,
          references: {
            'products': {'categories'},
          },
        ),
        ['CreateCategories', 'CreateProducts'],
      );
    });

    test('keeps the order of names when every table is already after the '
        'tables it references', () {
      expect(
        _order(
          [categories, products, tags],
          creates: creates,
          references: {
            'products': {'categories'},
          },
        ),
        ['CreateCategories', 'CreateProducts', 'CreateTags'],
      );
    });

    test('pulls the referenced table forward and leaves the rest where it '
        'was', () {
      expect(
        _order(
          [products, tags, categories],
          creates: creates,
          references: {
            'products': {'categories'},
          },
        ),
        ['CreateCategories', 'CreateProducts', 'CreateTags'],
      );
    });

    test('leaves alone a migration frozen to the columns its table had on day '
        'one', () {
      // It names no foreign key, so it does not need the table the model
      // points at today. Moving it would put every later migration that
      // reads or alters that table out of step with the release that
      // shipped it.
      expect(
        _order(
          [products, categories],
          creates: creates,
          references: {
            'products': {'categories'},
          },
          frozen: {'CreateProducts'},
        ),
        ['CreateProducts', 'CreateCategories'],
      );
    });

    test('keeps a migration that alters a table behind the migration that '
        'creates it', () {
      // Pushing products back would strand this alter in front of it, which
      // is a failure on every database rather than only on Postgres.
      final addStock = _migration('AddStockToProducts', '20260102_000000');

      expect(
        _order(
          [products, addStock, categories],
          creates: creates,
          references: {
            'products': {'categories'},
          },
        ),
        ['CreateCategories', 'CreateProducts', 'AddStockToProducts'],
      );
    });

    test('follows a chain of references', () {
      final orderItems = _migration('CreateOrderItems', '20260101_000000');
      final orders = _migration('CreateOrders', '20260102_000000');
      final customers = _migration('CreateCustomers', '20260103_000000');

      expect(
        _order(
          [orderItems, orders, customers],
          creates: {
            'CreateOrderItems': {'order_items'},
            'CreateOrders': {'orders'},
            'CreateCustomers': {'customers'},
          },
          references: {
            'order_items': {'orders'},
            'orders': {'customers'},
          },
        ),
        ['CreateCustomers', 'CreateOrders', 'CreateOrderItems'],
      );
    });

    test('treats a migration that creates several tables as one step', () {
      final commerce = _migration('CreateCommerce', '20260101_000000');
      final audit = _migration('CreateAudit', '20260102_000000');
      final users = _migration('CreateUsers', '20260103_000000');

      expect(
        _order(
          [commerce, audit, users],
          creates: {
            'CreateCommerce': {'orders', 'order_items'},
            'CreateAudit': {'audits'},
            'CreateUsers': {'users'},
          },
          references: {
            // Inside its own migration: nothing to wait for.
            'order_items': {'orders'},
            'orders': {'users'},
            'audits': {'orders'},
          },
        ),
        ['CreateUsers', 'CreateCommerce', 'CreateAudit'],
      );
    });

    test('leaves tables that two migrations point at each other to their '
        'names', () {
      final a = _migration('CreateA', '20260101_000000');
      final b = _migration('CreateB', '20260102_000000');

      expect(
        _order(
          [a, b],
          creates: {
            'CreateA': {'a'},
            'CreateB': {'b'},
          },
          references: {
            'a': {'b'},
            'b': {'a'},
          },
        ),
        ['CreateA', 'CreateB'],
      );
    });

    test('ignores a reference to a table no migration creates, and a '
        'migration that creates nothing', () {
      final backfill = _migration('BackfillSlugs', '20260101_000000');

      expect(
        _order(
          [backfill, products],
          creates: {
            'CreateProducts': {'products'},
          },
          references: {
            'products': {'suppliers'},
          },
        ),
        ['BackfillSlugs', 'CreateProducts'],
      );
    });

    test('a table that references itself waits for nothing', () {
      final categoriesFirst = _migration('CreateCats', '20260101_000000');

      expect(
        _order(
          [categoriesFirst],
          creates: {
            'CreateCats': {'cats'},
          },
          references: {
            'cats': {'cats'},
          },
        ),
        ['CreateCats'],
      );
    });
  });

  group('foreign key targets', () {
    test('are the tables a belongs-to points at', () {
      final (schemas, issues) = readSchemas({
        'category.dart': categorySchema,
        'product.dart': productSchema,
      });
      expect(issues, isEmpty);

      expect(BeakSchemaEmitter.foreignKeyTargets(schemas), {
        'categories': isEmpty,
        'products': {'categories'},
      });
    });

    test('include the belongs-to a has-many on the far side implies', () {
      // The generated model of the far side registers that relationship, and
      // `defineForeignKeys` makes a constraint of every one it finds.
      final (schemas, issues) = readSchemas({
        'category.dart': categorySchema.replaceFirst(
          'late final String name;',
          'late final String name;\n\n  @HasMany()\n  late final List<Product> products;',
        ),
        'product.dart': productSchema
            .replaceFirst('@BelongsTo()\n  late final Category? category;', '')
            .replaceFirst(
              "part 'product.beak.dart';",
              "part 'product.beak.dart';\nimport 'category.dart';",
            ),
      });
      expect(issues, isEmpty);

      expect(BeakSchemaEmitter.foreignKeyTargets(schemas)['products'], {
        'categories',
      });
    });
  });
}
