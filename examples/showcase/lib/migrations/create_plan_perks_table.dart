import 'package:beak/migrations.dart';

import '../resources/plans/models/plan_perk.dart';

/// Creates the plan_perks table.
///
/// Derived from PlanPerkModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreatePlanPerksTable extends Migration {
  /// Creates the migration.
  const CreatePlanPerksTable();

  @override
  String get name => '20260929_054959_create_plan_perks_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('plan_perks', (table) {
      BeakBlueprint.defineColumns(table, const PlanPerkModel());
      BeakBlueprint.defineForeignKeys(table, const PlanPerkModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('plan_perks', ifExists: true);
}
