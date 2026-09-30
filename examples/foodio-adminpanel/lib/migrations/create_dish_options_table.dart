import 'package:beak/migrations.dart';

import '../models/dish_option.dart';

/// Creates the dish_options table.
///
/// Derived from DishOptionModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateDishOptionsTable extends Migration {
  /// Creates the migration.
  const CreateDishOptionsTable();

  @override
  String get name => '20260927_071049_create_dish_options_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('dish_options', (table) {
      BeakBlueprint.defineColumns(table, const DishOptionModel());
      BeakBlueprint.defineForeignKeys(table, const DishOptionModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('dish_options', ifExists: true);
}
