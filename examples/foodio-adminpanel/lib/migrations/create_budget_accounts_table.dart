import 'package:beak/migrations.dart';

import '../models/budget_account.dart';

/// Creates the budget_accounts table.
///
/// Derived from BudgetAccountModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateBudgetAccountsTable extends Migration {
  /// Creates the migration.
  const CreateBudgetAccountsTable();

  @override
  String get name => '20260927_071041_create_budget_accounts_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('budget_accounts', (table) {
      BeakBlueprint.defineColumns(table, const BudgetAccountModel());
      BeakBlueprint.defineForeignKeys(table, const BudgetAccountModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('budget_accounts', ifExists: true);
}
