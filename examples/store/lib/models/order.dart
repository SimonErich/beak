import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'order_item.dart';
import 'user.dart';

part 'order.beak.dart';

/// Where an order is in its lifecycle.
enum OrderStatus {
  /// Placed, not yet paid.
  pending,

  /// Paid and being packed.
  paid,

  /// Handed to the courier.
  shipped,

  /// Money returned.
  refunded,
}

/// One purchase, with its lines.
@Resource(timestamps: true)
final class Order extends BeakSchema {
  /// The human-readable order number.
  @Display()
  @Column(
    searchable: true,
    sortable: true,
    unique: true,
    rules: [BeakMaxLength(40)],
  )
  late final String reference;

  /// Where the order is in its lifecycle.
  @Column(filterable: true)
  @Badges({
    OrderStatus.pending: BeakColor.warning,
    OrderStatus.paid: BeakColor.info,
    OrderStatus.shipped: BeakColor.success,
    OrderStatus.refunded: BeakColor.error,
  })
  late final OrderStatus status;

  /// Order total in euros.
  @Column(prefix: '€', sortable: true, rules: [BeakMin(0)])
  late final double total;

  /// When the order was placed.
  @Column(sortable: true, filterable: true)
  late final DateTime placedAt;

  /// Delivery notes for the courier.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakText? notes;

  /// The customer who placed it.
  @BelongsTo(onDelete: BeakOnDelete.cascade)
  late final User customer;

  /// The lines on the order.
  @HasMany(onDelete: BeakOnDelete.cascade)
  late final List<OrderItem> items;
}
