import 'package:beak_core/beak_core.dart';

/// Typed column constants of the orders resource.
abstract final class OrderColumns {
  /// Primary key.
  static const id = BeakStringColumn(
    key: 'id',
    label: 'Id',
    visibleOn: {BeakContext.detail},
  );

  /// Human-readable order number.
  static const reference = BeakStringColumn(
    key: 'reference',
    label: 'Reference',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakMaxLength(40)],
  );

  /// Order total in euros.
  static const total = BeakDecimalColumn(
    key: 'total',
    label: 'Total',
    prefix: '€',
    sortable: true,
    rules: [BeakMin(0)],
  );

  /// When the order was placed.
  static const placedAt = BeakDateTimeColumn(
    key: 'placed_at',
    label: 'Placed',
    sortable: true,
  );

  /// Foreign key owned by the `user` belongs-to relationship.
  static const userId = BeakStringColumn(
    key: 'user_id',
    label: 'Customer',
    visibleOn: {BeakContext.form},
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    id,
    reference,
    total,
    placedAt,
    userId,
  ];
}

/// Typed relationship constants of the orders resource.
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

  /// The order's line items.
  static const items = BeakHasMany(
    key: 'items',
    label: 'Items',
    relatedTable: 'order_items',
    displayColumnKey: 'label',
    foreignKey: 'order_id',
  );
}

/// The orders resource: one purchase with its line items.
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
  ];
}
