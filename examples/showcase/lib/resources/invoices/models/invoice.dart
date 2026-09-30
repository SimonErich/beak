import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../../keepers/models/keeper.dart';
import 'invoice_item.dart';

part 'invoice.beak.dart';

/// Where an invoice stands.
enum InvoiceStatus {
  /// Still being written.
  draft,

  /// Sent to the supplier.
  sent,

  /// Paid in full.
  paid,
}

/// A feed supplier's invoice, drawn by the invoice block.
@Resource()
final class Invoice extends BeakSchema {
  /// The invoice number.
  @Display()
  @Column(searchable: true, unique: true)
  late final String number;

  /// The supplier's name.
  late final String supplier;

  /// Where the invoice stands.
  @Column(defaultValue: InvoiceStatus.draft, filterable: true)
  @Badges<InvoiceStatus>({
    InvoiceStatus.draft: BeakColor.muted,
    InvoiceStatus.sent: BeakColor.info,
    InvoiceStatus.paid: BeakColor.success,
  })
  late final InvoiceStatus status;

  /// The issue date.
  late final DateTime issuedOn;

  /// The due date.
  late final DateTime dueOn;

  /// Sum of the lines.
  @Column(prefix: '€', precision: 2)
  late final double subtotal;

  /// Discount granted.
  @Column(prefix: '€', precision: 2)
  late final double discount;

  /// Delivery charge.
  @Column(prefix: '€', precision: 2)
  late final double shipping;

  /// Tax on the goods.
  @Column(prefix: '€', precision: 2)
  late final double tax;

  /// What is owed.
  @Column(prefix: '€', precision: 2)
  late final double total;

  /// The keeper who placed the order.
  @BelongsTo(onDelete: BeakOnDelete.setNull, inverse: false)
  late final Keeper? orderedBy;

  /// The invoice lines.
  @HasMany(owned: true, onDelete: BeakOnDelete.cascade)
  late final List<InvoiceItem> items;
}
