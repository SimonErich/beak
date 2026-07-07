import 'package:beak_frontend/beak_frontend.dart';
import 'package:beak_superdashboard/models/models.dart';
import 'package:beak_superdashboard/seeders/seed_ids.dart';
import 'package:obers_ui/obers_ui.dart';

/// The invoice-detail page — a composed invoice document (header meta,
/// bill-to, a line-item table, and a totals summary) for the fixed seeded
/// invoice.
BeakScreen buildInvoiceScreen() => const BeakScreen(
  path: '/invoice',
  title: 'Invoice',
  icon: BeakIconToken(OiIcons.fileText),
  section: 'Apps',
  body: BeakInvoiceBlock(
    model: InvoiceModel(),
    recordId: SeedIds.invoice,
    lineItemsModel: InvoiceItemModel(),
    lineItemsForeignKey: InvoiceItemColumns.invoiceId,
    toFields: [
      InvoiceColumns.number,
      InvoiceColumns.status,
      InvoiceColumns.issueDate,
      InvoiceColumns.dueDate,
    ],
    subtotalField: InvoiceColumns.subtotal,
    discountField: InvoiceColumns.discount,
    shippingField: InvoiceColumns.shipping,
    taxField: InvoiceColumns.tax,
    totalField: InvoiceColumns.total,
  ),
);
