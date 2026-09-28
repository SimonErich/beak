import 'package:beak/migrations.dart';

import '../resources/products/models/product.dart';

/// Creates the products table.
///
/// Derived from ProductModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateProductsTable extends Migration {
  /// Creates the migration.
  const CreateProductsTable();

  @override
  String get name => '20260926_201258_create_products_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Freeze the original shape: additive changes belong in later migrations.
    await schema.create('products', (table) {
      table.idUuid();
      BeakBlueprint.defineColumn(table, ProductColumns.name);
      BeakBlueprint.defineColumn(table, ProductColumns.price);
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('products', ifExists: true);
}
