import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../people/user.dart';
import 'invoice_item.dart';

part 'invoice.beak.dart';

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

/// The invoices resource — a bill to a customer.
@Resource()
final class Invoice extends BeakSchema {
  /// Invoice number (unique).
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(30)])
  late final String number;

  /// The billed user.
  @BelongsTo(label: 'Bill to', searchOn: ['name', 'email'])
  late final User? user;

  /// Settlement state, shown as a colored badge.
  @Column(filterable: true, defaultValue: InvoiceStatus.draft)
  @Badges({
    InvoiceStatus.draft: BeakColor.muted,
    InvoiceStatus.sent: BeakColor.info,
    InvoiceStatus.paid: BeakColor.success,
    InvoiceStatus.partial: BeakColor.warning,
    InvoiceStatus.overdue: BeakColor.error,
    InvoiceStatus.cancelled: BeakColor.secondary,
  })
  late final InvoiceStatus? status;

  /// Issue date.
  @Column(label: 'Issued', sortable: true)
  late final DateTime? issueDate;

  /// Due date.
  @Column(label: 'Due', sortable: true)
  late final DateTime? dueDate;

  /// Line-item subtotal.
  @Column(prefix: r'$')
  late final double? subtotal;

  /// Discount amount.
  @Column(prefix: r'$', visibleOn: {BeakContext.form, BeakContext.detail})
  late final double? discount;

  /// Shipping charge.
  @Column(prefix: r'$', visibleOn: {BeakContext.form, BeakContext.detail})
  late final double? shipping;

  /// Tax amount.
  @Column(prefix: r'$', visibleOn: {BeakContext.form, BeakContext.detail})
  late final double? tax;

  /// Grand total.
  @Column(prefix: r'$', sortable: true)
  late final double? total;

  /// Outstanding balance.
  @Column(label: 'Balance due', prefix: r'$', sortable: true)
  late final double? balanceDue;

  /// Free-form note.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakText? note;

  /// The line items.
  @HasMany()
  late final List<InvoiceItem> items;
}
