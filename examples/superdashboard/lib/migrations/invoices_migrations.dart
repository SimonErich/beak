import 'package:superdashboard/models/models.dart';
import 'package:beak/migrations.dart';

/// Creates the Invoices domain: invoices and their line items.
final class CreateInvoicesTables extends Migration {
  /// Creates the migration.
  const CreateInvoicesTables();

  @override
  String get name => '20260707_000800_create_invoices_tables';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create('invoices', (table) {
      BeakBlueprint.defineColumns(table, const InvoiceModel());
      table.unique(['number']);
      table.index(['status']);
      table.foreign(
        column: 'user_id',
        references: 'id',
        onTable: 'users',
        onDelete: OnDelete.setNull,
      );
    });
    await schema.create('invoice_items', (table) {
      BeakBlueprint.defineColumns(table, const InvoiceItemModel());
      table.foreign(
        column: 'invoice_id',
        references: 'id',
        onTable: 'invoices',
        onDelete: OnDelete.cascade,
      );
    });
  }

  @override
  Future<void> downSchema(Schema schema) async {
    for (final table in const ['invoice_items', 'invoices']) {
      await schema.drop(table, ifExists: true);
    }
  }
}
