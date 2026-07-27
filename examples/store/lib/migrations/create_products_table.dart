import 'package:beak/migrations.dart';

import '../models/product.dart';

/// Creates the products table.
///
/// Derived from ProductModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateProductsTable extends Migration {
  /// Creates the migration.
  const CreateProductsTable();

  @override
  String get name => '20260727_152057_create_products_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('products', (table) {
      BeakBlueprint.defineColumns(table, const ProductModel());
      BeakBlueprint.defineForeignKeys(table, const ProductModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('products', ifExists: true);
}
