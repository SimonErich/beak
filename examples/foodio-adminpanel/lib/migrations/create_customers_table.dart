import 'package:beak/migrations.dart';

import '../models/customer.dart';

/// Creates the customers table.
///
/// Derived from CustomerModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateCustomersTable extends Migration {
  /// Creates the migration.
  const CreateCustomersTable();

  @override
  String get name => '20260927_071035_create_customers_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('customers', (table) {
      BeakBlueprint.defineColumns(table, const CustomerModel());
      BeakBlueprint.defineForeignKeys(table, const CustomerModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('customers', ifExists: true);
}
