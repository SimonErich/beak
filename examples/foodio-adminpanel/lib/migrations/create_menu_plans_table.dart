import 'package:beak/migrations.dart';

import '../models/menu_plan.dart';

/// Creates the menu_plans table.
///
/// Derived from MenuPlanModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateMenuPlansTable extends Migration {
  /// Creates the migration.
  const CreateMenuPlansTable();

  @override
  String get name => '20260927_071039_create_menu_plans_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('menu_plans', (table) {
      BeakBlueprint.defineColumns(table, const MenuPlanModel());
      BeakBlueprint.defineForeignKeys(table, const MenuPlanModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('menu_plans', ifExists: true);
}
