import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'models.dart';

part 'invoice.beak.dart';

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
      BeakModelAction(
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
      ),
      BeakModelAction(
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
      ),
      BeakModelAction(
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
      ),
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
