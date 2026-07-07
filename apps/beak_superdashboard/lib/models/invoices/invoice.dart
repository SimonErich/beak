import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Settlement state of an invoice.
enum InvoiceStatus {
  /// Drafted, not yet sent.
  draft,

  /// Sent, awaiting payment.
  sent,

  /// Paid in full.
  paid,

  /// Partially paid.
  partial,

  /// Past due.
  overdue,

  /// Cancelled.
  cancelled,
}

/// Typed columns of the invoices resource.
abstract final class InvoiceColumns {
  /// Invoice number (unique).
  static const number = BeakStringColumn(
    key: 'number',
    label: 'Number',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakMaxLength(30)],
  );

  /// The billed user.
  static const userId = BeakStringColumn(
    key: 'user_id',
    label: 'Bill to',
    visibleOn: {BeakContext.form},
  );

  /// Settlement state, shown as a colored badge.
  static const status = BeakEnumColumn<InvoiceStatus>(
    key: 'status',
    label: 'Status',
    values: InvoiceStatus.values,
    defaultValue: InvoiceStatus.draft,
    filterable: true,
    badgeColors: {
      InvoiceStatus.draft: BeakColor.muted,
      InvoiceStatus.sent: BeakColor.info,
      InvoiceStatus.paid: BeakColor.success,
      InvoiceStatus.partial: BeakColor.warning,
      InvoiceStatus.overdue: BeakColor.error,
      InvoiceStatus.cancelled: BeakColor.secondary,
    },
  );

  /// Issue date.
  static const issueDate = BeakDateTimeColumn(
    key: 'issue_date',
    label: 'Issued',
    sortable: true,
  );

  /// Due date.
  static const dueDate = BeakDateTimeColumn(
    key: 'due_date',
    label: 'Due',
    sortable: true,
  );

  /// Line-item subtotal.
  static const subtotal = BeakDecimalColumn(
    key: 'subtotal',
    label: 'Subtotal',
    prefix: r'$',
  );

  /// Discount amount.
  static const discount = BeakDecimalColumn(
    key: 'discount',
    label: 'Discount',
    prefix: r'$',
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// Shipping charge.
  static const shipping = BeakDecimalColumn(
    key: 'shipping',
    label: 'Shipping',
    prefix: r'$',
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// Tax amount.
  static const tax = BeakDecimalColumn(
    key: 'tax',
    label: 'Tax',
    prefix: r'$',
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// Grand total.
  static const total = BeakDecimalColumn(
    key: 'total',
    label: 'Total',
    prefix: r'$',
    sortable: true,
  );

  /// Outstanding balance.
  static const balanceDue = BeakDecimalColumn(
    key: 'balance_due',
    label: 'Balance due',
    prefix: r'$',
    sortable: true,
  );

  /// Free-form note.
  static const note = BeakTextColumn(
    key: 'note',
    label: 'Note',
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    number,
    userId,
    status,
    issueDate,
    dueDate,
    subtotal,
    discount,
    shipping,
    tax,
    total,
    balanceDue,
    note,
  ];
}

/// Typed relationships of the invoices resource.
abstract final class InvoiceRelations {
  /// The billed user.
  static const user = BeakBelongsTo(
    key: 'user',
    label: 'Bill to',
    relatedTable: 'users',
    displayColumnKey: 'name',
    foreignKey: 'user_id',
    searchColumnKeys: ['name', 'email'],
  );

  /// The line items.
  static const items = BeakHasMany(
    key: 'items',
    label: 'Items',
    relatedTable: 'invoice_items',
    displayColumnKey: 'item',
    foreignKey: 'invoice_id',
  );
}

/// The invoices resource — a bill to a customer.
final class InvoiceModel extends BeakModel {
  /// Creates the invoices model.
  const InvoiceModel();

  @override
  String get table => 'invoices';

  @override
  String get displayColumnKey => 'number';

  @override
  List<BeakColumn> get columns => InvoiceColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    InvoiceRelations.user,
    InvoiceRelations.items,
  ];
}
