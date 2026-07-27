import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'order.dart';

part 'order_event.beak.dart';

/// A step in an order's lifecycle timeline.
enum OrderEventKind {
  /// The order was placed.
  placed,

  /// Payment was confirmed.
  paid,

  /// The order was packed.
  packed,

  /// The order was handed to the carrier.
  shipped,

  /// The order was delivered.
  delivered,

  /// The order was cancelled.
  cancelled,

  /// The order was refunded.
  refunded,

  /// A free-text note was recorded.
  note,
}

/// The order-events resource — one entry in an order's history timeline.
@Resource()
final class OrderEvent extends BeakSchema {
  /// The kind of event.
  @Column(label: 'Event', defaultValue: OrderEventKind.note, filterable: true)
  @Badges({
    OrderEventKind.placed: BeakColor.info,
    OrderEventKind.paid: BeakColor.success,
    OrderEventKind.packed: BeakColor.secondary,
    OrderEventKind.shipped: BeakColor.primary,
    OrderEventKind.delivered: BeakColor.success,
    OrderEventKind.cancelled: BeakColor.error,
    OrderEventKind.refunded: BeakColor.warning,
    OrderEventKind.note: BeakColor.muted,
  })
  late final OrderEventKind? kind;

  /// What happened.
  @Display()
  @Column(searchable: true)
  late final BeakText? description;

  /// Who or what performed the event.
  @Column(label: 'By')
  late final String? actor;

  /// When the event occurred.
  @Column(label: 'When', sortable: true)
  late final DateTime? createdAt;

  /// The owning order.
  @BelongsTo()
  late final Order? order;
}
