import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../people/user.dart';
import '../shared/enums.dart';
import 'order_comment.dart';
import 'order_event.dart';
import 'order_item.dart';
import 'transaction.dart';

part 'order.beak.dart';

/// Fulfilment state of an order.
enum OrderStatus {
  /// Placed, awaiting processing.
  pending,

  /// Being prepared.
  processing,

  /// Handed to the carrier.
  shipped,

  /// Received by the customer.
  delivered,

  /// Cancelled before fulfilment.
  cancelled,

  /// Refunded after fulfilment.
  refunded,
}

/// The orders resource — a customer's purchase.
@Resource()
final class Order extends BeakSchema {
  /// Human-readable order reference (unique).
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(40)])
  late final String reference;

  /// The customer who placed the order.
  @BelongsTo(label: 'Customer', searchOn: ['name', 'email'])
  late final User? user;

  /// Fulfilment state, shown as a colored badge.
  @Column(defaultValue: OrderStatus.pending, filterable: true)
  @Badges({
    OrderStatus.pending: BeakColor.warning,
    OrderStatus.processing: BeakColor.info,
    OrderStatus.shipped: BeakColor.primary,
    OrderStatus.delivered: BeakColor.success,
    OrderStatus.cancelled: BeakColor.muted,
    OrderStatus.refunded: BeakColor.error,
  })
  late final OrderStatus? status;

  /// Payment settlement state.
  @Column(
    label: 'Payment',
    defaultValue: PaymentStatus.pending,
    filterable: true,
  )
  @Badges({
    PaymentStatus.pending: BeakColor.warning,
    PaymentStatus.paid: BeakColor.success,
    PaymentStatus.failed: BeakColor.error,
    PaymentStatus.refunded: BeakColor.muted,
  })
  late final PaymentStatus? paymentStatus;

  /// Where the purchase originated (feeds the dashboard donut).
  @Column(defaultValue: PurchaseChannel.direct, filterable: true)
  @Badges({
    PurchaseChannel.direct: BeakColor.primary,
    PurchaseChannel.social: BeakColor.info,
    PurchaseChannel.email: BeakColor.success,
    PurchaseChannel.affiliate: BeakColor.warning,
    PurchaseChannel.search: BeakColor.secondary,
  })
  late final PurchaseChannel? source;

  /// Line-item subtotal.
  @Column(prefix: r'$', sortable: true)
  late final double? subtotal;

  /// Shipping charge.
  @Column(prefix: r'$', visibleOn: {BeakContext.form, BeakContext.detail})
  late final double? shipping;

  /// Tax amount.
  @Column(prefix: r'$', visibleOn: {BeakContext.form, BeakContext.detail})
  late final double? tax;

  /// Grand total.
  @Column(prefix: r'$', sortable: true)
  late final double? total;

  /// When the order was placed.
  @Column(label: 'Placed', format: BeakDateFormat.relative, sortable: true)
  late final DateTime? placedAt;

  /// The line items on the order.
  @HasMany()
  late final List<OrderItem> items;

  /// The settling transaction.
  @HasOne()
  late final Transaction? transaction;

  /// The order's lifecycle/history timeline.
  @HasMany(label: 'History')
  late final List<OrderEvent> events;

  /// Internal and customer-facing notes on the order.
  @HasMany()
  late final List<OrderComment> comments;
}
