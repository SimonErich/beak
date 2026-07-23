part of 'beak_block.dart';

/// A composed invoice document: a header (logo + from/to blocks), a
/// line-items table, and a totals column.
///
/// obers_ui has no invoice widget, so this block composes existing pieces —
/// `OiImage`, `OiKeyValue`, and a reused [BeakTableBlock] — rather than
/// wrapping one. The invoice record ([model] + [recordId]) supplies the
/// header and total fields; [lineItemsModel] supplies the itemized rows,
/// scoped to this invoice through [lineItemsForeignKey].
///
/// ```dart
/// BeakInvoiceBlock(
///   model: const InvoiceModel(),
///   recordId: 'inv-1001',
///   logoField: InvoiceColumns.logoUrl,
///   fromFields: [InvoiceColumns.fromName, InvoiceColumns.fromAddress],
///   toFields: [InvoiceColumns.toName, InvoiceColumns.toAddress],
///   lineItemsModel: const InvoiceLineModel(),
///   lineItemsForeignKey: InvoiceLineColumns.invoiceId,
///   subtotalField: InvoiceColumns.subtotal,
///   taxField: InvoiceColumns.tax,
///   totalField: InvoiceColumns.total,
/// );
/// ```
final class BeakInvoiceBlock extends BeakBlock {
  /// Creates an invoice block for [recordId] of [model].
  const BeakInvoiceBlock({
    required this.model,
    required this.recordId,
    required this.lineItemsModel,
    required this.totalField,
    this.logoField,
    this.fromFields = const [],
    this.toFields = const [],
    this.metaFields = const [],
    this.toRelation,
    this.toPartyFields = const [],
    this.lineItemsForeignKey,
    this.subtotalField,
    this.discountField,
    this.shippingField,
    this.taxField,
    this.title = 'Invoice',
    super.span,
  });

  /// The invoice header/totals model.
  final BeakModel model;

  /// Primary key of the invoice record.
  final Object recordId;

  /// The line-items model listed in the itemized table.
  final BeakModel lineItemsModel;

  /// Column supplying the grand total.
  final BeakColumn totalField;

  /// Column supplying the header logo URL, when bound.
  final BeakColumn? logoField;

  /// Columns rendered in the "from" (issuer) block, in order.
  final List<BeakColumn> fromFields;

  /// Columns rendered in the "to" (recipient) block, in order.
  final List<BeakColumn> toFields;

  /// Invoice columns rendered in a "Details" block (number, status, dates)
  /// — distinct from the recipient, which [toFields]/[toPartyFields] name.
  final List<BeakColumn> metaFields;

  /// The belongs-to relation to the billed party; when bound (with
  /// [toPartyFields]) the "To" block renders the related record's fields.
  final BeakBelongsTo? toRelation;

  /// The related party model's columns rendered in the "To" block.
  final List<BeakColumn> toPartyFields;

  /// The line-items foreign key scoping the itemized table to this invoice,
  /// when bound.
  final BeakColumn? lineItemsForeignKey;

  /// Column supplying the pre-adjustment subtotal, when bound.
  final BeakColumn? subtotalField;

  /// Column supplying the discount total, when bound.
  final BeakColumn? discountField;

  /// Column supplying the shipping total, when bound.
  final BeakColumn? shippingField;

  /// Column supplying the tax total, when bound.
  final BeakColumn? taxField;

  /// The document heading.
  final String title;
}
