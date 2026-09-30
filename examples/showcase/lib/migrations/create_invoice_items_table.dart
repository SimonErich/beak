import 'package:beak/migrations.dart';

import '../resources/invoices/models/invoice_item.dart';

/// Creates the invoice_items table.
///
/// Derived from InvoiceItemModel the first time `beak prepare` ran, and yours from
/// then on — Beak never rewrites a migration it has written.
final class CreateInvoiceItemsTable extends Migration {
  /// Creates the migration.
  const CreateInvoiceItemsTable();

  @override
  String get name => '20260929_054955_create_invoice_items_table';

  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('invoice_items', (table) {
      BeakBlueprint.defineColumns(table, const InvoiceItemModel());
      BeakBlueprint.defineForeignKeys(table, const InvoiceItemModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('invoice_items', ifExists: true);
}
