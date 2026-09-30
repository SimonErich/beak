import 'package:beak/migrations.dart';

import '../resources/products/models/product_variant.dart';

/// Creates the product_variants table.
///
/// Derived from ProductVariantModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateProductVariantsTable extends Migration {
  /// Creates the migration.
  const CreateProductVariantsTable();

  @override
  String get name => '20260926_213337_create_product_variants_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('product_variants', (table) {
      BeakBlueprint.defineColumns(table, const ProductVariantModel());
      BeakBlueprint.defineForeignKeys(table, const ProductVariantModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('product_variants', ifExists: true);
}
