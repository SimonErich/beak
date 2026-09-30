import 'package:beak/migrations.dart';
import '../resources/products/models/product_variant.dart';

/// Adds optional combination identities without replacing any catalog records.
final class AddVariantCombinations extends Migration {
  /// Creates the additive migration.
  const AddVariantCombinations();

  @override
  String get name => '20260927_230000_add_variant_combinations';

  @override
  Future<void> upSchema(Schema schema) async {
    final columns = await schema.adapter.introspectSchema();
    if (columns[const ProductVariantModel().table]?.contains(
          ProductVariantColumns.combinationKey.key,
        ) ??
        false) {
      return;
    }
    await schema.alter(const ProductVariantModel().table, (table) {
      BeakBlueprint.defineColumn(table, ProductVariantColumns.combinationKey);
      table.unique([
        ProductVariantColumns.productId.key,
        ProductVariantColumns.combinationKey.key,
      ]);
    });
  }

  @override
  Future<void> downSchema(
    Schema schema,
  ) async => throw IrreversibleMigrationException(
    migration: name,
    message:
        'Removing combination identities requires an explicit data migration.',
  );
}
