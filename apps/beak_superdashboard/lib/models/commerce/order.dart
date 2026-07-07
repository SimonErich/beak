import 'package:beak_core/beak_core.dart';

import '../shared/enums.dart';
import '../shared/shared_columns.dart';

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

/// Typed columns of the orders resource.
abstract final class OrderColumns {
  /// Human-readable order reference (unique).
  static const reference = BeakStringColumn(
    key: 'reference',
    label: 'Reference',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakMaxLength(40)],
  );

  /// The customer.
  static const userId = BeakStringColumn(
    key: 'user_id',
    label: 'Customer',
    visibleOn: {BeakContext.form},
  );

  /// Fulfilment state, shown as a colored badge.
  static const status = BeakEnumColumn<OrderStatus>(
    key: 'status',
    label: 'Status',
    values: OrderStatus.values,
    defaultValue: OrderStatus.pending,
    filterable: true,
    badgeColors: {
      OrderStatus.pending: BeakColor.warning,
      OrderStatus.processing: BeakColor.info,
      OrderStatus.shipped: BeakColor.primary,
      OrderStatus.delivered: BeakColor.success,
      OrderStatus.cancelled: BeakColor.muted,
      OrderStatus.refunded: BeakColor.error,
    },
  );

  /// Payment settlement state.
  static const paymentStatus = BeakEnumColumn<PaymentStatus>(
    key: 'payment_status',
    label: 'Payment',
    values: PaymentStatus.values,
    defaultValue: PaymentStatus.pending,
    filterable: true,
    badgeColors: {
      PaymentStatus.pending: BeakColor.warning,
      PaymentStatus.paid: BeakColor.success,
      PaymentStatus.failed: BeakColor.error,
      PaymentStatus.refunded: BeakColor.muted,
    },
  );

  /// Where the purchase originated (feeds the dashboard donut).
  static const source = BeakEnumColumn<PurchaseSource>(
    key: 'source',
    label: 'Source',
    values: PurchaseSource.values,
    defaultValue: PurchaseSource.direct,
    filterable: true,
    badgeColors: {
      PurchaseSource.direct: BeakColor.primary,
      PurchaseSource.social: BeakColor.info,
      PurchaseSource.email: BeakColor.success,
      PurchaseSource.affiliate: BeakColor.warning,
      PurchaseSource.search: BeakColor.secondary,
    },
  );

  /// Line-item subtotal.
  static const subtotal = BeakDecimalColumn(
    key: 'subtotal',
    label: 'Subtotal',
    prefix: r'$',
    sortable: true,
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

  /// When the order was placed.
  static const placedAt = BeakDateTimeColumn(
    key: 'placed_at',
    label: 'Placed',
    format: BeakDateFormat.relative,
    sortable: true,
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    reference,
    userId,
    status,
    paymentStatus,
    source,
    subtotal,
    shipping,
    tax,
    total,
    placedAt,
  ];
}

/// Typed relationships of the orders resource.
abstract final class OrderRelations {
  /// The customer who placed the order.
  static const user = BeakBelongsTo(
    key: 'user',
    label: 'Customer',
    relatedTable: 'users',
    displayColumnKey: 'name',
    foreignKey: 'user_id',
    searchColumnKeys: ['name', 'email'],
  );

  /// The line items on the order.
  static const items = BeakHasMany(
    key: 'items',
    label: 'Items',
    relatedTable: 'order_items',
    displayColumnKey: 'label',
    foreignKey: 'order_id',
  );

  /// The settling transaction.
  static const transaction = BeakHasOne(
    key: 'transaction',
    label: 'Transaction',
    relatedTable: 'transactions',
    displayColumnKey: 'reference',
    foreignKey: 'order_id',
  );
}

/// The orders resource — a customer's purchase.
final class OrderModel extends BeakModel {
  /// Creates the orders model.
  const OrderModel();

  @override
  String get table => 'orders';

  @override
  String get displayColumnKey => 'reference';

  @override
  List<BeakColumn> get columns => OrderColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    OrderRelations.user,
    OrderRelations.items,
    OrderRelations.transaction,
  ];
}
