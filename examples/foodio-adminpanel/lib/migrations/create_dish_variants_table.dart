import 'package:beak/migrations.dart';

import '../models/dish_variant.dart';

/// Creates the dish_variants table.
///
/// Derived from DishVariantModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateDishVariantsTable extends Migration {
  /// Creates the migration.
  const CreateDishVariantsTable();

  @override
  String get name => '20260927_071050_create_dish_variants_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('dish_variants', (table) {
      BeakBlueprint.defineColumns(table, const DishVariantModel());
      BeakBlueprint.defineForeignKeys(table, const DishVariantModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('dish_variants', ifExists: true);
}
