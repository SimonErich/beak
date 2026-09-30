import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'models.dart';

part 'invoice.beak.dart';

/// The invoice commands, each declared once and referenced by object wherever
/// a screen, list or server rule mentions it.
abstract final class InvoiceActions {
  /// Issues a draft invoice and locks its amounts and recipient.
  static final issue = BeakModelAction(
    name: 'issue',
    label: 'Issue invoice',
    availableWhen: (record) =>
        InvoiceModel.status.readFrom(record) == InvoiceStatus.draft,
    values: [
      BeakValueBehavior.derived(
        field: InvoiceModel.status,
        resolve: (_) => InvoiceStatus.issued,
      ),
    ],
  );

  /// Records that an issued invoice has been paid.
  static final markPaid = BeakModelAction(
    name: 'markPaid',
    label: 'Mark paid',
    availableWhen: (record) =>
        InvoiceModel.status.readFrom(record) == InvoiceStatus.issued,
    values: [
      BeakValueBehavior.derived(
        field: InvoiceModel.status,
        resolve: (_) => InvoiceStatus.paid,
      ),
    ],
  );

  /// Closes an issued invoice without payment.
  static final cancel = BeakModelAction(
    name: 'cancel',
    label: 'Cancel invoice',
    availableWhen: (record) =>
        InvoiceModel.status.readFrom(record) == InvoiceStatus.issued,
    values: [
      BeakValueBehavior.derived(
        field: InvoiceModel.status,
        resolve: (_) => InvoiceStatus.cancelled,
      ),
    ],
  );
}

/// Invoice configuration shared by the panel and authoritative API.
@Resource(timestamps: true)
final class Invoice extends BeakSchema {
  /// Associated orders are visible without making invoice ownership destructive.
  @HasMany(foreignKey: 'invoice_id')
  late final List<Order> orders;

  /// Financial transitions lock amounts and recipient details after issue.
  static BeakModelBehavior get behavior => BeakModelBehavior(
    editableWhen: (record) =>
        InvoiceModel.status.readFrom(record) == InvoiceStatus.draft,
    deletableWhen: (record) =>
        InvoiceModel.status.readFrom(record) == InvoiceStatus.draft,
    actions: [
      InvoiceActions.issue,
      InvoiceActions.markPaid,
      InvoiceActions.cancel,
    ],
  );

  /// Reference.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String reference;

  /// Organization.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final Organization? organization;

  /// Customer.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final Customer? customer;

  /// Period.
  late final String period;

  /// Status.
  @Column(defaultValue: InvoiceStatus.draft, filterable: true)
  @EnumLabels<InvoiceStatus>({
    InvoiceStatus.draft: 'Draft',
    InvoiceStatus.issued: 'Issued',
    InvoiceStatus.paid: 'Paid',
    InvoiceStatus.cancelled: 'Cancelled',
  })
  @Badges<InvoiceStatus>({
    InvoiceStatus.draft: BeakColor.muted,
    InvoiceStatus.issued: BeakColor.info,
    InvoiceStatus.paid: BeakColor.success,
    InvoiceStatus.cancelled: BeakColor.error,
  })
  late final InvoiceStatus status;

  /// Gross cents.
  @Column(defaultValue: 0, rules: [BeakMin(0)])
  late final int grossCents;

  /// Net cents.
  @Column(defaultValue: 0, rules: [BeakMin(0)])
  late final int netCents;

  /// Tax cents.
  @Column(defaultValue: 0, rules: [BeakMin(0)])
  late final int taxCents;

  /// Issue date.
  @Column(sortable: true, filterable: true)
  late final BeakDate? issueDate;

  /// Due date.
  @Column(sortable: true, filterable: true)
  late final BeakDate? dueDate;

  /// Billing email.
  @Column(defaultValue: '')
  late final String? billingEmail;

  /// Billing address.
  @Column(defaultValue: '')
  late final String? billingAddress;
}
