import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

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

/// Typed columns of the order-events resource — one entry in an order's
/// history/audit timeline.
abstract final class OrderEventColumns {
  /// The kind of event.
  static const kind = BeakEnumColumn<OrderEventKind>(
    key: 'kind',
    label: 'Event',
    values: OrderEventKind.values,
    defaultValue: OrderEventKind.note,
    filterable: true,
    badgeColors: {
      OrderEventKind.placed: BeakColor.info,
      OrderEventKind.paid: BeakColor.success,
      OrderEventKind.packed: BeakColor.secondary,
      OrderEventKind.shipped: BeakColor.primary,
      OrderEventKind.delivered: BeakColor.success,
      OrderEventKind.cancelled: BeakColor.error,
      OrderEventKind.refunded: BeakColor.warning,
      OrderEventKind.note: BeakColor.muted,
    },
  );

  /// What happened.
  static const description = BeakTextColumn(
    key: 'description',
    label: 'Description',
    searchable: true,
  );

  /// Who or what performed the event.
  static const actor = BeakStringColumn(key: 'actor', label: 'By');

  /// When the event occurred.
  static const createdAt = BeakDateTimeColumn(
    key: 'created_at',
    label: 'When',
    sortable: true,
  );

  /// The owning order.
  static const orderId = BeakStringColumn(
    key: 'order_id',
    label: 'Order',
    visibleOn: {BeakContext.form},
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    kind,
    description,
    actor,
    createdAt,
    orderId,
  ];
}

/// Typed relationships of the order-events resource.
abstract final class OrderEventRelations {
  /// The owning order.
  static const order = BeakBelongsTo(
    key: 'order',
    label: 'Order',
    relatedTable: 'orders',
    displayColumnKey: 'reference',
    foreignKey: 'order_id',
    searchColumnKeys: ['reference'],
  );
}

/// The order-events resource — one entry in an order's history timeline.
final class OrderEventModel extends BeakModel {
  /// Creates the order-events model.
  const OrderEventModel();

  @override
  String get table => 'order_events';

  @override
  String get displayColumnKey => 'description';

  @override
  List<BeakColumn> get columns => OrderEventColumns.values;

  @override
  List<BeakRelationship> get relationships => const [OrderEventRelations.order];
}
