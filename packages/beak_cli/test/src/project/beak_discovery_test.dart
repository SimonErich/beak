import 'dart:io';

import '../../support/beak_cli_internals.dart';
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

/// A resource class for [modelClass], with a zero-argument constructor.
String resource(String name, String modelClass, {bool isConst = false}) =>
    '''
import 'package:beak/panel.dart';

final class $name extends BeakResource {
  ${isConst ? 'const ' : ''}$name() : super(model: const $modelClass());
}
''';

void main() {
  test('resource-local models and their resource classes are both found', () {
    final discovery = BeakProjectScanner(
      projectWith({
        'lib/resources/orders/models/order.dart': model('OrderModel', 'orders'),
        'lib/resources/orders/order_resource.dart': resource(
          'OrderResource',
          'OrderModel',
        ),
        'lib/resources/orders/screens/order_form.dart': 'class OrderForm {}',
      }),
    ).scan();
    expect(discovery.issues, isEmpty);
    expect(discovery.models.single.name, 'OrderModel');
    expect(discovery.resources.single.className, 'OrderResource');
    expect(
      discovery.resources.single.importPath,
      'resources/orders/order_resource.dart',
    );
  });

  group('resource classes', () {
    test('are found anywhere under lib/, with the model they configure', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/models/product.dart': model('ProductModel', 'products'),
          'lib/panel/catalog.dart': resource('CatalogResource', 'ProductModel'),
        }),
      ).scan();

      expect(discovery.issues, isEmpty);
      final BeakDiscoveredResource found = discovery.resources.single;
      expect(found.className, 'CatalogResource');
      expect(found.importPath, 'panel/catalog.dart');
      expect(found.modelClass, 'ProductModel');
      expect(found.isConst, isFalse);
      expect(found.expression, 'CatalogResource()');
    });

    test('a const constructor is constructed const', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/resources/products/product_resource.dart': resource(
            'ProductResource',
            'ProductModel',
            isConst: true,
          ),
        }),
      ).scan();

      expect(discovery.resources.single.isConst, isTrue);
      expect(discovery.resources.single.expression, 'const ProductResource()');
    });

    test('are found one hop from a shared local base, which is skipped', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/resources/base.dart': """
import 'package:beak/panel.dart';

abstract base class ShopResource extends BeakResource {
  ShopResource({required super.model});
}
""",
          'lib/resources/products/product_resource.dart': """
import '../base.dart';

final class ProductResource extends ShopResource {
  ProductResource() : super(model: const ProductModel());
}
""",
        }),
      ).scan();

      expect(discovery.issues, isEmpty);
      expect(discovery.resources.map((found) => found.className), [
        'ProductResource',
      ]);
      expect(discovery.resources.single.modelClass, 'ProductModel');
    });

    test('one that needs constructor arguments is left to its author', () {
      // A parameterised resource is composed by hand; the generated panel
      // cannot know what to pass, so it keeps the default instead.
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/resources/orders/order_resource.dart': """
import 'package:beak/panel.dart';

final class OrderResource extends BeakResource {
  OrderResource(String title) : super(model: const OrderModel(), title: title);
}
""",
        }),
      ).scan();

      expect(discovery.issues, isEmpty);
      expect(discovery.resources, isEmpty);
    });

    test('one declaring only named constructors is left to its author', () {
      // `OrderResource()` would not compile: declaring any constructor
      // removes the implicit unnamed one.
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/resources/orders/order_resource.dart': """
import 'package:beak/panel.dart';

final class OrderResource extends BeakResource {
  const OrderResource.compact() : super(model: const OrderModel());
}
""",
        }),
      ).scan();

      expect(discovery.issues, isEmpty);
      expect(discovery.resources, isEmpty);
    });

    test('one declaring no constructor is built by its implicit one', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/resources/base.dart': """
import 'package:beak/panel.dart';

abstract base class OrdersResource extends BeakResource {
  OrdersResource() : super(model: const OrderModel());
}
""",
          'lib/resources/orders/order_resource.dart': """
import '../base.dart';

final class OrderResource extends OrdersResource {}
""",
        }),
      ).scan();

      expect(discovery.issues, isEmpty);
      final BeakDiscoveredResource found = discovery.resources.single;
      expect(found.className, 'OrderResource');
      expect(found.expression, 'OrderResource()');
      expect(found.modelClass, isNull);
    });

    test('a model the constructor does not name literally is unknown', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/resources/orders/order_resource.dart': """
import 'package:beak/panel.dart';

const orders = OrderModel();

final class OrderResource extends BeakResource {
  OrderResource() : super(model: orders);
}
""",
        }),
      ).scan();

      expect(discovery.resources.single.modelClass, isNull);
    });

    test('a private class is not one the generated panel can import', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/resources/orders/order_resource.dart': resource(
            '_OrderResource',
            'OrderModel',
          ),
        }),
      ).scan();

      expect(discovery.issues, isEmpty);
      expect(discovery.resources, isEmpty);
    });

    test('a model passed without const is read too', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/resources/orders/order_resource.dart': """
import 'package:beak/panel.dart';

final class OrderResource extends BeakResource {
  OrderResource() : super(model: OrderModel());
}
""",
        }),
      ).scan();

      expect(discovery.resources.single.modelClass, 'OrderModel');
    });

    test('a super.model parameter default names the model', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/resources/orders/order_resource.dart': """
import 'package:beak/panel.dart';

final class OrderResource extends BeakResource {
  const OrderResource({super.model = const OrderModel()});
}
""",
        }),
      ).scan();

      expect(discovery.resources.single.modelClass, 'OrderModel');
      expect(discovery.resources.single.isConst, isTrue);
    });

    test('configure a model by name, or by convention when unnamed', () {
      const named = BeakDiscoveredResource(
        className: 'CatalogResource',
        importPath: 'panel/catalog.dart',
        isConst: false,
        modelClass: 'ProductModel',
      );
      const unnamed = BeakDiscoveredResource(
        className: 'OrderResource',
        importPath: 'resources/orders/order_resource.dart',
        isConst: false,
      );

      expect(named.configures('ProductModel'), isTrue);
      expect(named.configures('CatalogModel'), isFalse);
      // The source did not name its model, so the scaffold's naming
      // convention is the best evidence there is.
      expect(unnamed.configures('OrderModel'), isTrue);
      expect(unnamed.configures('ProductModel'), isFalse);
      expect(
        BeakDiscoveredResource.conventionalNameFor('OrderItemModel'),
        'OrderItemResource',
      );
      expect(
        BeakDiscoveredResource.conventionalNameFor('Audit'),
        'AuditResource',
      );
      expect(named.toString(), 'CatalogResource (panel/catalog.dart)');
    });

    test('reject two with the same class name', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/a/product_resource.dart': resource(
            'ProductResource',
            'ProductModel',
          ),
          'lib/b/product_resource.dart': resource(
            'ProductResource',
            'ProductModel',
          ),
        }),
      ).scan();

      expect(discovery.issues.single.path, 'lib/b/product_resource.dart');
      expect(discovery.issues.single.message, contains('ProductResource'));
    });
  });

  group('removed override files', () {
    test('a per-table resource override names the class replacing it', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/models/product.dart': model('ProductModel', 'products'),
          'lib/resources/products.dart':
              "import 'package:beak/panel.dart';\n"
              'BeakResource beakResource(BeakResource generated) => generated;',
        }),
      ).scan();

      expect(discovery.issues.single.path, 'lib/resources/products.dart');
      expect(
        discovery.issues.single.message,
        allOf(
          contains('BeakResource subclass'),
          contains('beak eject resource products'),
        ),
      );
    });

    test('a dashboard override names the screen replacing it', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/dashboard.dart':
              "import 'package:beak/panel.dart';\n"
              'BeakScreen beakDashboard() => throw UnimplementedError();',
        }),
      ).scan();

      expect(discovery.issues.single.path, 'lib/dashboard.dart');
      expect(
        discovery.issues.single.message,
        allOf(contains('BeakScreen'), contains("path: '/'")),
      );
    });

    test(
      'a file under lib/resources/ that overrides nothing is left alone',
      () {
        final discovery = BeakProjectScanner(
          projectWith({
            'lib/resources/products.dart': 'const String catalog = "x";',
            'lib/dashboard.dart': 'const String dashboard = "x";',
          }),
        ).scan();

        expect(discovery.issues, isEmpty);
      },
    );
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

    test('only a const variable is a constant expression', () {
      // An authored entrypoint writes `const BeakPanelConfig(...)` exactly
      // when everything in it is constant, so it has to know.
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/screens/reports.dart': '''
import 'package:beak_frontend/beak_frontend.dart';

const BeakScreen auditScreen = BeakScreen();
final BeakScreen reportsScreen = BeakScreen();
BeakScreen buildStockScreen() => BeakScreen();
''',
        }),
      ).scan();

      expect(
        {
          for (final screen in discovery.screens)
            screen.name: screen.isConstVariable,
        },
        {
          'auditScreen': true,
          'buildStockScreen()': false,
          'reportsScreen': false,
        },
      );
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
      expect(discovery.storageRegistry, isNull);
    });

    test('a storage registry is found without a server override', () {
      // It used to count only as an extra of `beakServer`, so a project that
      // registered a driver and was otherwise happy with the default server
      // silently kept the local disk.
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/server.dart': """
import 'package:beak/server.dart';

BeakStorageRegistry beakStorageRegistry() => BeakStorageRegistry();
""",
        }),
      ).scan();

      expect(discovery.overrides, isEmpty);
      expect(discovery.storageRegistry?.name, 'beakStorageRegistry');
      expect(discovery.storageRegistry?.importPath, 'server.dart');
    });

    test('a server override and a storage registry are found together', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/server.dart': """
import 'package:beak/server.dart';

BeakServer beakServer(BeakServerDefaults defaults) => defaults.build();

BeakStorageRegistry beakStorageRegistry() => BeakStorageRegistry();
""",
        }),
      ).scan();

      expect(discovery.overrides.keys, [BeakOverrideKind.server]);
      expect(discovery.storageRegistry, isNotNull);
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

      expect(
        discovery.summary,
        '1 model · 0 resource classes · 0 screens · 1 override',
      );
    });

    test('pluralises correctly', () {
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/models/product.dart': model('ProductModel', 'products'),
          'lib/models/category.dart': model('CategoryModel', 'categories'),
        }),
      ).scan();

      expect(
        discovery.summary,
        '2 models · 0 resource classes · 0 screens · 0 overrides',
      );
    });

    test('counts resource classes too', () {
      // `beak eject resource products` writes one of these, and a summary
      // that did not count it would read as "your file was not picked up" to
      // the one person guaranteed to be looking.
      final discovery = BeakProjectScanner(
        projectWith({
          'lib/models/product.dart': model('ProductModel', 'products'),
          'lib/resources/products/product_resource.dart': resource(
            'ProductResource',
            'ProductModel',
          ),
        }),
      ).scan();

      expect(
        discovery.summary,
        '1 model · 1 resource class · 0 screens · 0 overrides',
      );
    });
  });
}
