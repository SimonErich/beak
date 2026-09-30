import 'package:beak/migrations.dart';

import '../resources/products/models/product_attribute.dart';

/// Creates the product_attributes table.
///
/// Derived from ProductAttributeModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateProductAttributesTable extends Migration {
  /// Creates the migration.
  const CreateProductAttributesTable();

  @override
  String get name => '20260926_213341_create_product_attributes_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('product_attributes', (table) {
      BeakBlueprint.defineColumns(table, const ProductAttributeModel());
      BeakBlueprint.defineForeignKeys(table, const ProductAttributeModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('product_attributes', ifExists: true);
}
