import 'package:beak/migrations.dart';

import '../models/menu_plan_item.dart';

/// Creates the menu_plan_items table.
///
/// Derived from MenuPlanItemModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateMenuPlanItemsTable extends Migration {
  /// Creates the migration.
  const CreateMenuPlanItemsTable();

  @override
  String get name => '20260927_071051_create_menu_plan_items_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('menu_plan_items', (table) {
      BeakBlueprint.defineColumns(table, const MenuPlanItemModel());
      BeakBlueprint.defineForeignKeys(table, const MenuPlanItemModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('menu_plan_items', ifExists: true);
}
