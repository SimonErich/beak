import 'package:beak/migrations.dart';

import '../models/product.dart';

/// Creates the product_tag pivot joining products and its
/// tags.
final class CreateProductTagTable extends Migration {
  /// Creates the migration.
  const CreateProductTagTable();

  @override
  String get name => '20260727_152401_create_product_tag_table';

  @override
  Future<void> upSchema(Schema schema) => BeakBlueprint.createPivot(
    schema,
    ProductRelations.tags,
    ownerTable: 'products',
  );

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('product_tag', ifExists: true);
}
