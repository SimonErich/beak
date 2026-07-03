import 'package:beak_core/beak_core.dart';

/// Typed column constants of the order-items resource.
abstract final class OrderItemColumns {
  /// Primary key.
  static const id = BeakStringColumn(
    key: 'id',
    label: 'Id',
    visibleOn: {BeakContext.detail},
  );

  /// Human-readable line label (e.g. "2× Espresso Cup").
  static const label = BeakStringColumn(
    key: 'label',
    label: 'Line',
    searchable: true,
    rules: [BeakRequired(), BeakMaxLength(160)],
  );

  /// Number of units ordered.
  static const quantity = BeakIntColumn(
    key: 'quantity',
    label: 'Quantity',
    min: 1,
    rules: [BeakRequired(), BeakMin(1)],
  );

  /// Price of one unit in euros.
  static const unitPrice = BeakDecimalColumn(
    key: 'unit_price',
    label: 'Unit price',
    prefix: '€',
    rules: [BeakRequired(), BeakMin(0)],
  );

  /// Foreign key owned by the `order` belongs-to relationship.
  static const orderId = BeakStringColumn(
    key: 'order_id',
    label: 'Order',
    visibleOn: {BeakContext.form},
  );

  /// Foreign key owned by the `product` belongs-to relationship.
  static const productId = BeakStringColumn(
    key: 'product_id',
    label: 'Product',
    visibleOn: {BeakContext.form},
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    id,
    label,
    quantity,
    unitPrice,
    orderId,
    productId,
  ];
}

/// Typed relationship constants of the order-items resource.
abstract final class OrderItemRelations {
  /// The order the line belongs to.
  static const order = BeakBelongsTo(
    key: 'order',
    label: 'Order',
    relatedTable: 'orders',
    displayColumnKey: 'reference',
    foreignKey: 'order_id',
    searchColumnKeys: ['reference'],
  );

  /// The product the line sells.
  static const product = BeakBelongsTo(
    key: 'product',
    label: 'Product',
    relatedTable: 'products',
    displayColumnKey: 'name',
    foreignKey: 'product_id',
    searchColumnKeys: ['name'],
  );
}

/// The order-items resource: one line of an order.
final class OrderItemModel extends BeakModel {
  /// Creates the order-items model.
  const OrderItemModel();

  @override
  String get table => 'order_items';

  @override
  String get displayColumnKey => 'label';

  @override
  List<BeakColumn> get columns => OrderItemColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    OrderItemRelations.order,
    OrderItemRelations.product,
  ];
}
