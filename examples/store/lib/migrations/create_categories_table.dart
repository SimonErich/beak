import 'package:beak/migrations.dart';

import '../models/category.dart';

/// Creates the categories table.
///
/// Derived from CategoryModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateCategoriesTable extends Migration {
  /// Creates the migration.
  const CreateCategoriesTable();

  @override
  String get name => '20260727_152054_create_categories_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('categories', (table) {
      BeakBlueprint.defineColumns(table, const CategoryModel());
      BeakBlueprint.defineForeignKeys(table, const CategoryModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('categories', ifExists: true);
}
