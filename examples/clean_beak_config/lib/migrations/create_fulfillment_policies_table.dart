import 'package:beak/migrations.dart';

import '../resources/fulfillment/models/fulfillment_policy.dart';

/// Creates the fulfillment_policies table.
///
/// Derived from FulfillmentPolicyModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateFulfillmentPoliciesTable extends Migration {
  /// Creates the migration.
  const CreateFulfillmentPoliciesTable();

  @override
  String get name => '20260927_012941_create_fulfillment_policies_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('fulfillment_policies', (table) {
      BeakBlueprint.defineColumns(table, const FulfillmentPolicyModel());
      BeakBlueprint.defineForeignKeys(table, const FulfillmentPolicyModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('fulfillment_policies', ifExists: true);
}
