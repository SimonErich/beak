import 'package:beak/migrations.dart';

import '../resources/products/models/product_image.dart';

/// Creates the product_images table.
///
/// Derived from ProductImageModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateProductImagesTable extends Migration {
  /// Creates the migration.
  const CreateProductImagesTable();

  @override
  String get name => '20260927_012942_create_product_images_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('product_images', (table) {
      BeakBlueprint.defineColumns(table, const ProductImageModel());
      BeakBlueprint.defineForeignKeys(table, const ProductImageModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('product_images', ifExists: true);
}
