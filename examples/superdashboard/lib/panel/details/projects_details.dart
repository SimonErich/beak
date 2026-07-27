import 'package:beak_frontend/beak_frontend.dart';
import 'package:superdashboard/models/models.dart';

/// The invoice layout, shared by the show page and the create/edit form:
/// status and dates up top, the bill-to and the money breakdown side by side,
/// and the line items in their own card.
const BeakBlock invoiceDetail = BeakColumnBlock(
  gapInPixels: 20,
  children: [
    BeakCardBlock(
      title: 'Invoice',
      child: BeakFieldGroupBlock([
        InvoiceColumns.number,
        InvoiceColumns.status,
        InvoiceColumns.issueDate,
        InvoiceColumns.dueDate,
      ], columnCount: 4),
    ),
    BeakGridBlock(
      columns: 12,
      children: [
        BeakCardBlock(
          span: BeakSpan(columns: 5),
          title: 'Bill to',
          child: BeakColumnBlock(
            children: [
              BeakFieldBlock(InvoiceColumns.userId),
              BeakFieldBlock(InvoiceColumns.note),
            ],
          ),
        ),
        BeakCardBlock(
          span: BeakSpan(columns: 7),
          title: 'Amounts',
          child: BeakFieldGroupBlock([
            InvoiceColumns.subtotal,
            InvoiceColumns.discount,
            InvoiceColumns.shipping,
            InvoiceColumns.tax,
            InvoiceColumns.total,
            InvoiceColumns.balanceDue,
          ]),
        ),
      ],
    ),
    BeakCardBlock(
      title: 'Line items',
      child: BeakRelationBlock(InvoiceRelations.items),
    ),
  ],
);
