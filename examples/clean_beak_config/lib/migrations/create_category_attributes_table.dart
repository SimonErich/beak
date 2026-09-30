import 'package:beak/migrations.dart';

import '../resources/categories/models/category_attribute.dart';

/// Creates the category_attributes table.
///
/// Derived from CategoryAttributeModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateCategoryAttributesTable extends Migration {
  /// Creates the migration.
  const CreateCategoryAttributesTable();

  @override
  String get name => '20260926_213334_create_category_attributes_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('category_attributes', (table) {
      BeakBlueprint.defineColumns(table, const CategoryAttributeModel());
      BeakBlueprint.defineForeignKeys(table, const CategoryAttributeModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('category_attributes', ifExists: true);
}
