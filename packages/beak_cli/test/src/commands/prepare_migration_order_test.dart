import 'dart:io';

import 'package:test/test.dart';

import '../../support/beak_cli_internals.dart';
import 'prepare_command_test.dart' show environmentFor, projectWith, read;

/// A create-table migration. It reads the model, foreign keys included, unless
/// [frozen] says it names its first columns one by one.
String _createTable(
  String className,
  String table,
  String stamp, {
  String model = 'Model',
  bool frozen = false,
}) =>
    '''
import 'package:beak/migrations.dart';

final class $className extends Migration {
  const $className();

  @override
  String get name => '${stamp}_create_${table}_table';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create('$table', (t) {
      ${frozen ? "t.idUuid();\n      BeakBlueprint.defineColumn(t, ${model.replaceAll('Model', 'Columns')}.name);" : "BeakBlueprint.defineColumns(t, const $model());\n      BeakBlueprint.defineForeignKeys(t, const $model());"}
    });
  }

  @override
  Future<void> downSchema(Schema schema) async => schema.drop('$table');
}
''';

const String _category = '''
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'category.beak.dart';

/// A grouping.
@Resource()
final class Category extends BeakSchema {
  /// Its name.
  @Display()
  late final String name;
}
''';

const String _product = '''
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'category.dart';

part 'product.beak.dart';

/// Something for sale.
@Resource()
final class Product extends BeakSchema {
  /// Its name.
  @Display()
  late final String name;

  /// What it is filed under.
  @BelongsTo()
  late final Category? category;
}
''';

/// The migration classes the generated host registers, in order.
List<String> _registered(Directory root) => [
  for (final match in RegExp(
    r'^\s+(Create\w+Table)\(\),',
    multiLine: true,
  ).allMatches(read(root, 'lib/beak/server.g.dart')))
    match.group(1)!,
];

void main() {
  group('the migrations a generated host registers', () {
    test('put a table after the table its foreign key points at, even when '
        'that table was created later', () {
      // Week one made products, week three made categories, and products has
      // pointed at categories since. Name order replays products first, and
      // on Postgres its CREATE TABLE names a table that is not there yet.
      final root = projectWith({
        'lib/models/category.dart': _category,
        'lib/models/product.dart': _product,
        'lib/migrations/create_products_table.dart': _createTable(
          'CreateProductsTable',
          'products',
          '20260101_000000',
          model: 'ProductModel',
        ),
        'lib/migrations/create_categories_table.dart': _createTable(
          'CreateCategoriesTable',
          'categories',
          '20260122_000000',
          model: 'CategoryModel',
        ),
      });

      runPrepare(environmentFor(root));

      expect(_registered(root), [
        'CreateCategoriesTable',
        'CreateProductsTable',
      ]);
    });

    test('leave a create migration frozen to its first columns where its name '
        'puts it', () {
      // The shop freezes its products migration to two columns and adds the
      // category key in a later one, so nothing in it needs categories.
      final root = projectWith({
        'lib/models/category.dart': _category,
        'lib/models/product.dart': _product,
        'lib/migrations/create_products_table.dart': _createTable(
          'CreateProductsTable',
          'products',
          '20260101_000000',
          model: 'ProductModel',
          frozen: true,
        ),
        'lib/migrations/create_categories_table.dart': _createTable(
          'CreateCategoriesTable',
          'categories',
          '20260122_000000',
          model: 'CategoryModel',
        ),
      });

      runPrepare(environmentFor(root));

      expect(_registered(root), [
        'CreateProductsTable',
        'CreateCategoriesTable',
      ]);
    });

    test('keep the order of names when nothing points backwards', () {
      final root = projectWith({
        'lib/models/category.dart': _category,
        'lib/models/product.dart': _product,
        'lib/migrations/create_categories_table.dart': _createTable(
          'CreateCategoriesTable',
          'categories',
          '20260101_000000',
          model: 'CategoryModel',
        ),
        'lib/migrations/create_products_table.dart': _createTable(
          'CreateProductsTable',
          'products',
          '20260122_000000',
          model: 'ProductModel',
        ),
      });

      runPrepare(environmentFor(root));

      expect(_registered(root), [
        'CreateCategoriesTable',
        'CreateProductsTable',
      ]);
    });

    test('are the ones beak doctor expects, so it does not call the host '
        'stale', () async {
      final root = projectWith({
        'lib/models/category.dart': _category,
        'lib/models/product.dart': _product,
        'lib/migrations/create_products_table.dart': _createTable(
          'CreateProductsTable',
          'products',
          '20260101_000000',
          model: 'ProductModel',
        ),
        'lib/migrations/create_categories_table.dart': _createTable(
          'CreateCategoriesTable',
          'categories',
          '20260122_000000',
          model: 'CategoryModel',
        ),
      });
      runPrepare(environmentFor(root));

      final checks = await diagnose(
        environmentFor(root),
        readSchema: (url, {String schema = 'public'}) async => const [],
      );

      expect(
        checks
            .firstWhere((check) => check.label.startsWith('generated files'))
            .label,
        'generated files up to date',
      );
    });
  });
}
