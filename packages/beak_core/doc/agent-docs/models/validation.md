# Validation

> Share scalar, record and relationship constraints between client and server.

Column rules validate individual values. Static schema `validationRules` describe cross-field and relationship constraints. The shared engine handles required values, bounds, patterns, collections, comparisons, conditional requirements and eligible references.

Use `BeakExists` for references and `BeakFieldMatch` for scoped relationships. `BeakCount` constrains collection size and `BeakDistinct` prevents repeated child values. Database uniqueness remains authoritative when two requests race. A frontend check provides feedback but cannot replace that boundary.

Screen placement validators can refine the current workflow. Wizard steps validate before advancing; the final save validates the complete graph. Server errors retain field and relation paths so the form can reveal the relevant group. Async checks must complete before submission.

```dart title="examples/clean_beak_config/lib/resources/invoices/models/invoice.dart"
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../../users/models/user.dart';
import '../../orders/models/order.dart';
import 'invoice_item.dart';
import 'invoice_voucher.dart';
part 'invoice.beak.dart';

/// Supported demonstration invoice states.
enum InvoiceStatus {
  /// Editable document before issue.
  draft,

  /// Issued document with locked contents.
  issued,

  /// Issued document marked paid.
  paid,

  /// Cancelled document retained for reference.
  cancelled,
}

/// The invoice's business commands, each declared once and referenced by
/// object wherever a screen, list or server rule mentions it.
abstract final class InvoiceActions {
  /// Issues a draft invoice and locks its contents.
  static final issue = BeakModelAction(
    name: 'issue',
    allowOnCreate: true,
    label: 'Issue invoice',
    description:
        'Issue this invoice and lock its customer, prices, discounts and taxes.',
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
    description: 'Record that this invoice has been paid.',
    availableWhen: (record) =>
        InvoiceModel.status.readFrom(record) == InvoiceStatus.issued,
    values: [
      BeakValueBehavior.derived(
        field: InvoiceModel.status,
        resolve: (_) => InvoiceStatus.paid,
      ),
    ],
  );

  /// Closes an invoice without payment while keeping it for reference.
  static final cancel = BeakModelAction(
    name: 'cancel',
    label: 'Cancel invoice',
    description:
        'Keep this invoice for reference and close it without payment.',
    availableWhen: (record) => {
      InvoiceStatus.draft,
      InvoiceStatus.issued,
    }.contains(InvoiceModel.status.readFrom(record)),
    values: [
      BeakValueBehavior.derived(
        field: InvoiceModel.status,
        resolve: (_) => InvoiceStatus.cancelled,
      ),
    ],
  );
}

/// An invoice whose saved values snapshot the catalog at save time.
@Resource(timestamps: true)
final class Invoice extends BeakSchema {
  /// Shared collection, date and customer constraints across every presentation.
  static List<BeakRecordRule> get validationRules => [
    BeakCount(InvoiceModel.items, min: 1),
    BeakDistinct(InvoiceModel.vouchers, InvoiceVoucherModel.position),
    BeakDistinct(InvoiceModel.vouchers, InvoiceVoucherModel.voucherId),
    BeakAfterField(InvoiceModel.dueAt, InvoiceModel.issuedAt, inclusive: true),
    BeakExists(
      InvoiceModel.orderId,
      OrderModel.id,
      matching: [
        BeakFieldMatch(
          target: OrderModel.customerId,
          source: InvoiceModel.customerId,
        ),
      ],
    ),
  ];

  /// Named business transitions run through the same atomic save protocol.
  static BeakModelBehavior get behavior => BeakModelBehavior(
    editableWhen: (record) =>
        (InvoiceModel.status.readFrom(record) ?? InvoiceStatus.draft) ==
        InvoiceStatus.draft,
    deletableWhen: (_) => false,
    actions: [
      InvoiceActions.issue,
      InvoiceActions.markPaid,
      InvoiceActions.cancel,
    ],
  );

  /// Unique document reference entered by the administrator.
  @Display()
  @Column(searchable: true, sortable: true, unique: true)
  late final String number;

  /// Drafts can change; issued documents retain their line snapshots.
  @Column(defaultValue: InvoiceStatus.draft)
  late final InvoiceStatus status;

  /// Customer receiving the invoice.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final User customer;

  /// Optional order being invoiced.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final Order? order;

  /// Invoice date, including historical invoices.
  @Column(format: BeakDateFormat.dateOnly, sortable: true)
  late final DateTime issuedAt;

  /// Optional payment due date.
  @Column(format: BeakDateFormat.dateOnly, sortable: true)
  late final DateTime? dueAt;

  /// Snapshot of the billed customer's name.
  @Column(visibleOn: {BeakContext.detail})
  late final String? customerName;

  /// Snapshot of the billed customer's email.
  @Column(visibleOn: {BeakContext.detail})
  late final String? customerEmail;

  /// Optional billing address saved with the document.
  late final String? customerAddress;

  /// Net line subtotal after line discounts, before vouchers, in cents.
  @Column(visibleOn: {BeakContext.detail})
  late final int? subtotalCents;

  /// Total voucher discount in cents.
  @Column(visibleOn: {BeakContext.detail})
  late final int? discountCents;

  /// Rounded exclusive tax in cents.
  @Column(visibleOn: {BeakContext.detail})
  late final int? taxCents;

  /// Payable total in cents.
  @Column(visibleOn: {BeakContext.detail})
  late final int? totalCents;

  /// Owned product, variant and custom service lines.
  @HasMany(owned: true, onDelete: BeakOnDelete.cascade)
  late final List<InvoiceItem> items;

  /// Ordered voucher applications.
  @HasMany(owned: true, onDelete: BeakOnDelete.cascade)
  late final List<InvoiceVoucher> vouchers;
}
```

## Continue reading

- [Validation reference](../reference/validation-rules.md)
- [Model behavior](behavior.md)
