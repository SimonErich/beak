import 'package:beak/migrations.dart';

import '../resources/invoices/models/invoice_voucher.dart';

/// Creates the invoice_vouchers table.
///
/// Derived from InvoiceVoucherModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateInvoiceVouchersTable extends Migration {
  /// Creates the migration.
  const CreateInvoiceVouchersTable();

  @override
  String get name => '20260926_213340_create_invoice_vouchers_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('invoice_vouchers', (table) {
      BeakBlueprint.defineColumns(table, const InvoiceVoucherModel());
      BeakBlueprint.defineForeignKeys(table, const InvoiceVoucherModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('invoice_vouchers', ifExists: true);
}
