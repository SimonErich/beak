import 'package:beak/migrations.dart';

import '../resources/invoices/models/invoice.dart';

/// Creates the invoices table.
///
/// Derived from InvoiceModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateInvoicesTable extends Migration {
  /// Creates the migration.
  const CreateInvoicesTable();

  @override
  String get name => '20260926_213335_create_invoices_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('invoices', (table) {
      BeakBlueprint.defineColumns(table, const InvoiceModel());
      BeakBlueprint.defineForeignKeys(table, const InvoiceModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('invoices', ifExists: true);
}
