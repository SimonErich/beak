import 'package:beak/migrations.dart';

import '../resources/plans/models/plan.dart';

/// Creates the plans table.
///
/// Derived from PlanModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreatePlansTable extends Migration {
  /// Creates the migration.
  const CreatePlansTable();

  @override
  String get name => '20260929_054958_create_plans_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('plans', (table) {
      BeakBlueprint.defineColumns(table, const PlanModel());
      BeakBlueprint.defineForeignKeys(table, const PlanModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('plans', ifExists: true);
}
