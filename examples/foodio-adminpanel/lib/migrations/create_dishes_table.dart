import 'package:beak/migrations.dart';

import '../models/dish.dart';

/// Creates the dishes table.
///
/// Derived from DishModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateDishesTable extends Migration {
  /// Creates the migration.
  const CreateDishesTable();

  @override
  String get name => '20260927_071104_create_dishes_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('dishes', (table) {
      BeakBlueprint.defineColumns(table, const DishModel());
      BeakBlueprint.defineForeignKeys(table, const DishModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('dishes', ifExists: true);
}
