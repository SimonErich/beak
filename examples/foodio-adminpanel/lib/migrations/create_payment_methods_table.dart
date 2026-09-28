import 'package:beak/migrations.dart';

import '../models/payment_method.dart';

/// Creates the payment_methods table.
///
/// Derived from PaymentMethodModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreatePaymentMethodsTable extends Migration {
  /// Creates the migration.
  const CreatePaymentMethodsTable();

  @override
  String get name => '20260927_071044_create_payment_methods_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('payment_methods', (table) {
      BeakBlueprint.defineColumns(table, const PaymentMethodModel());
      BeakBlueprint.defineForeignKeys(table, const PaymentMethodModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('payment_methods', ifExists: true);
}
