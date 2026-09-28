import 'dart:io';

import 'package:beak_cli/beak_cli.dart';
import 'package:test/test.dart';

/// Writes [files] (path relative to the project root) into a temp project.
Directory projectWith(Map<String, String> files) {
  final root = Directory.systemTemp.createTempSync('beak_discovery_');
  addTearDown(() => root.deleteSync(recursive: true));
  for (final MapEntry(key: path, value: contents) in files.entries) {
    final file = File('${root.path}/$path');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }
  return root;
}

/// A minimal model declaration.
String model(String name, String table) =>
    '''
import 'package:beak_core/beak_core.dart';

final class $name extends BeakModel {
  const $name();
  @override
  String get table => '$table';
  @override
  String get displayColumnKey => 'name';
  @override
  List<BeakColumn> get columns => const [];
}
''';

void main() {
  test('resource-local models are registered without becoming overrides', () {
    final discovery = BeakProjectScanner(
      projectWith({
        'lib/resources/orders/models/order.dart': model('OrderModel', 'orders'),
        'lib/resources/orders/order_resource.dart':
            'class OrderResource extends BeakResource {}',
        'lib/resources/orders/screens/order_form.dart': 'class OrderForm {}',
      }),
    ).scan();
    expect(discovery.issues, isEmpty);
    expect(discovery.models.single.name, 'OrderModel');
    expect(discovery.resourceOverrides, isEmpty);
  });
  group('models', () {
    test('are found by their supertype, in path order', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/models/product.dart': model('ProductModel', 'products'),
          'lib/models/category.dart': model('CategoryModel', 'categories'),
        }),
      ).scan();

      expect(discovery.issues, isEmpty);
      expect(discovery.models.map((model) => model.name), [
        'CategoryModel',
        'ProductModel',
      ]);
      expect(discovery.models.first.importPath, 'models/category.dart');
      expect(discovery.models.first.expression, 'const CategoryModel()');
    });

    test('are found one inheritance hop away, via a shared local base', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/models/base.dart': '''
import 'package:beak_core/beak_core.dart';

abstract base class AppModel extends BeakModel {
  const AppModel();
}
''',
          'lib/models/product.dart': '''
import 'base.dart';

final class ProductModel extends AppModel {
  const ProductModel();
}
''',
        }),
      ).scan();

      expect(
        discovery.models.map((model) => model.name),
        contains('ProductModel'),
      );
    });

    test('are reported, not skipped, when they cannot be instantiated', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/models/product.dart': '''
import 'package:beak_core/beak_core.dart';

final class ProductModel extends BeakModel {
  ProductModel({required this.table});
  @override
  final String table;
}
''',
        }),
      ).scan();

      expect(discovery.models, isEmpty);
      expect(discovery.issues, hasLength(1));
      expect(discovery.issues.single.message, contains('const ProductModel()'));
      expect(discovery.issues.single.path, 'lib/models/product.dart');
    });

    test('reject two models with the same class name', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/models/a/product.dart': model('ProductModel', 'products'),
          'lib/models/b/product.dart': model('ProductModel', 'other'),
        }),
      ).scan();

      expect(discovery.issues.single.message, contains('already declared'));
    });

    test('ignore private and generated files', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/models/_draft.dart': model('DraftModel', 'drafts'),
          'lib/models/gen.g.dart': model('GenModel', 'gens'),
          'lib/models/product.dart': model('ProductModel', 'products'),
        }),
      ).scan();

      expect(discovery.models.map((model) => model.name), ['ProductModel']);
    });

    test('a project with no models directory scans cleanly', () {
      final discovery = BeakProjectScanner(projectWith({})).scan();
      expect(discovery.models, isEmpty);
      expect(discovery.issues, isEmpty);
    });
  });

  group('screens', () {
    test('are found as a top-level variable or a nullary function', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/screens/reports.dart': '''
import 'package:beak_frontend/beak_frontend.dart';

final BeakScreen reportsScreen = BeakScreen();
BeakScreen buildAuditScreen() => BeakScreen();
''',
        }),
      ).scan();

      expect(discovery.screens.map((screen) => screen.name), [
        'buildAuditScreen()',
        'reportsScreen',
      ]);
      expect(discovery.screens.first.expression, 'buildAuditScreen()');
    });

    test('a builder taking required arguments is reported', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/screens/reports.dart': '''
import 'package:beak_frontend/beak_frontend.dart';

BeakScreen buildReports(String title) => BeakScreen();
''',
        }),
      ).scan();

      expect(discovery.screens, isEmpty);
      expect(discovery.issues.single.message, contains('required arguments'));
    });

    test('non-screen declarations are ignored', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/screens/helpers.dart': '''
const String title = 'Reports';
int add(int a, int b) => a + b;
''',
        }),
      ).scan();

      expect(discovery.screens, isEmpty);
      expect(discovery.issues, isEmpty);
    });
  });

  group('overrides', () {
    test('are detected only when the expected symbol is declared', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/theme.dart': 'OiThemeData beakLightTheme() => OiThemeData();',
          // Present but does not declare `beakPanel` — not an override.
          'lib/panel.dart': 'const String unrelated = "x";',
        }),
      ).scan();

      expect(discovery.overrides.keys, [BeakOverrideKind.theme]);
      expect(
        discovery.overrides[BeakOverrideKind.theme]?.importPath,
        'theme.dart',
      );
    });

    test('an absent file is simply not an override', () {
      final discovery = BeakProjectScanner(projectWith({})).scan();
      expect(discovery.overrides, isEmpty);
    });
  });

  group('migrations and seeders', () {
    test('are found by supertype', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/migrations/create_notes.dart': '''
import 'package:worm/worm.dart';

final class CreateNotesTable extends Migration {
  const CreateNotesTable();
}
''',
          'lib/seeders/demo.dart': '''
import 'package:worm/worm.dart';

final class DemoSeeder extends Seeder {
  const DemoSeeder();
}
''',
        }),
      ).scan();

      expect(discovery.migrations.single.name, 'CreateNotesTable');
      expect(discovery.seeders.single.name, 'DemoSeeder');
    });

    test('migrations register in declared-name order, not file order', () {
      // worm runs migrations in registration order, and the timestamp lives
      // in the `name` getter. By path, `create_order_items_table.dart` sorts
      // before `create_orders_table.dart` and its foreign key would reference
      // a table that does not exist yet.
      String migration(String className, String name) =>
          '''
import 'package:worm/worm.dart';

final class $className extends Migration {
  const $className();

  @override
  String get name => '$name';
}
''';

      final discovery = BeakProjectScanner(
        projectWith({
          'lib/migrations/create_order_items_table.dart': migration(
            'CreateOrderItemsTable',
            '20260726_120200_create_order_items_table',
          ),
          'lib/migrations/create_orders_table.dart': migration(
            'CreateOrdersTable',
            '20260726_120100_create_orders_table',
          ),
        }),
      ).scan();

      expect(discovery.migrations.map((m) => m.name), [
        'CreateOrdersTable',
        'CreateOrderItemsTable',
      ]);
    });

    test('a migration with no declared name still sorts by path', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/migrations/b.dart':
              "import 'package:worm/worm.dart';\n"
              'final class BMigration extends Migration { const BMigration(); }',
          'lib/migrations/a.dart':
              "import 'package:worm/worm.dart';\n"
              'final class AMigration extends Migration { const AMigration(); }',
        }),
      ).scan();

      expect(discovery.migrations.map((m) => m.name), [
        'AMigration',
        'BMigration',
      ]);
    });
  });

  group('migrated tables', () {
    test('a create and an alter both count as coverage', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/migrations/create_products_table.dart': '''
import 'package:beak/migrations.dart';

final class CreateProductsTable extends Migration {
  @override
  String get name => '20260101_000000_create_products_table';
  @override
  Future<void> upSchema(Schema schema) => schema.create('products', (t) {
    t.idUuid();
  });
  @override
  Future<void> downSchema(Schema schema) => schema.drop('products');
}
''',
          'lib/migrations/add_stock.dart': '''
import 'package:beak/migrations.dart';

final class AddStock extends Migration {
  @override
  String get name => '20260101_000001_add_stock';
  @override
  Future<void> upSchema(Schema schema) =>
      schema.alter('orders', (t) => t.integer('stock').makeNullable());
  @override
  Future<void> downSchema(Schema schema) async {}
}
''',
        }),
      ).scan();

      expect(
        discovery.migratedTables,
        containsAll(<String>['products', 'orders']),
      );
    });

    test('a pivot counts through the relation constant it names', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/migrations/create_product_tag_table.dart': '''
import 'package:beak/migrations.dart';
import 'package:acme/models/product.dart';

final class CreateProductTagTable extends Migration {
  @override
  String get name => '20260101_000002_create_product_tag_table';
  @override
  Future<void> upSchema(Schema schema) => BeakBlueprint.createPivot(
    schema,
    ProductRelations.tags,
    ownerTable: 'products',
  );
  @override
  Future<void> downSchema(Schema schema) => schema.drop('product_tag');
}
''',
        }),
      ).scan();

      expect(discovery.migratedTables, contains('ProductRelations.tags'));
    });

    test('a pivot does not vouch for the table that owns it', () {
      // `createPivot(…, ownerTable: 'products')` names which side owns the
      // relationship, not a table the migration creates. Counting it meant a
      // project could delete create_products_table.dart and have `prepare`
      // decline to write it back, with `doctor` reporting all clear — gap A
      // returning through the very check meant to prevent it.
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/migrations/create_product_tag_table.dart': '''
import 'package:beak/migrations.dart';
import 'package:acme/models/product.dart';

final class CreateProductTagTable extends Migration {
  @override
  String get name => '20260101_000002_create_product_tag_table';
  @override
  Future<void> upSchema(Schema schema) => BeakBlueprint.createPivot(
    schema,
    ProductRelations.tags,
    ownerTable: 'products',
  );
  @override
  Future<void> downSchema(Schema schema) => schema.drop('product_tag');
}
''',
        }),
      ).scan();

      expect(discovery.migratedTables, isNot(contains('products')));
    });
  });

  group('summary', () {
    test('reports what was found, so a miss is visible', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/models/product.dart': model('ProductModel', 'products'),
          'lib/theme.dart': 'OiThemeData beakLightTheme() => OiThemeData();',
        }),
      ).scan();

      expect(discovery.summary, '1 model · 0 screens · 1 override');
    });

    test('pluralises correctly', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/models/product.dart': model('ProductModel', 'products'),
          'lib/models/category.dart': model('CategoryModel', 'categories'),
        }),
      ).scan();

      expect(discovery.summary, '2 models · 0 screens · 0 overrides');
    });

    test('counts a per-resource override too', () {
      // `beak eject resource products` writes one of these, and the summary
      // printed "0 overrides" straight afterwards — which reads as "your file
      // was not picked up" to the one person guaranteed to be looking.
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/models/product.dart': model('ProductModel', 'products'),
          'lib/resources/products.dart':
              'import \'package:beak/panel.dart\';\n'
              'BeakResource beakResource(BeakResource generated) => generated;',
        }),
      ).scan();

      expect(discovery.resourceOverrides.keys, <String>['products']);
      expect(discovery.summary, '1 model · 0 screens · 1 override');
    });
  });
}
