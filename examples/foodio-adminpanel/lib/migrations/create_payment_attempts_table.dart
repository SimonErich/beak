import 'package:beak/migrations.dart';

import '../models/payment_attempt.dart';

/// Creates the payment_attempts table.
///
/// Derived from PaymentAttemptModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreatePaymentAttemptsTable extends Migration {
  /// Creates the migration.
  const CreatePaymentAttemptsTable();

  @override
  String get name => '20260927_072335_create_payment_attempts_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('payment_attempts', (table) {
      BeakBlueprint.defineColumns(table, const PaymentAttemptModel());
      BeakBlueprint.defineForeignKeys(table, const PaymentAttemptModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('payment_attempts', ifExists: true);
}
