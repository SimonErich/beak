import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the invoice-items resource.
abstract final class InvoiceItemColumns {
  /// The owning invoice.
  static const invoiceId = BeakStringColumn(
    key: 'invoice_id',
    label: 'Invoice',
    visibleOn: {BeakContext.form},
  );

  /// Line item name.
  static const item = BeakStringColumn(
    key: 'item',
    label: 'Item',
    searchable: true,
    rules: [BeakRequired(), BeakMaxLength(160)],
  );

  /// Line description.
  static const description = BeakTextColumn(
    key: 'description',
    label: 'Description',
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// Unit price in dollars.
  static const price = BeakDecimalColumn(
    key: 'price',
    label: 'Price',
    prefix: r'$',
    rules: [BeakRequired(), BeakMin(0)],
  );

  /// Quantity billed.
  static const quantity = BeakIntColumn(
    key: 'quantity',
    label: 'Qty',
    min: 1,
    rules: [BeakRequired(), BeakMin(1)],
  );

  /// Line total in dollars.
  static const total = BeakDecimalColumn(
    key: 'total',
    label: 'Total',
    prefix: r'$',
    sortable: true,
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    invoiceId,
    item,
    description,
    price,
    quantity,
    total,
  ];
}

/// Typed relationships of the invoice-items resource.
abstract final class InvoiceItemRelations {
  /// The owning invoice.
  static const invoice = BeakBelongsTo(
    key: 'invoice',
    label: 'Invoice',
    relatedTable: 'invoices',
    displayColumnKey: 'number',
    foreignKey: 'invoice_id',
    searchColumnKeys: ['number'],
  );
}

/// The invoice-items resource — one line of an invoice.
final class InvoiceItemModel extends BeakModel {
  /// Creates the invoice-items model.
  const InvoiceItemModel();

  @override
  String get table => 'invoice_items';

  @override
  String get displayColumnKey => 'item';

  @override
  List<BeakColumn> get columns => InvoiceItemColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    InvoiceItemRelations.invoice,
  ];
}
