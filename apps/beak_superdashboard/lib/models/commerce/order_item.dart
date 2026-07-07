import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the order-items resource.
abstract final class OrderItemColumns {
  /// Line label, e.g. "2× Espresso Beans".
  static const label = BeakStringColumn(
    key: 'label',
    label: 'Item',
    searchable: true,
    rules: [BeakRequired(), BeakMaxLength(160)],
  );

  /// Quantity ordered.
  static const quantity = BeakIntColumn(
    key: 'quantity',
    label: 'Qty',
    min: 1,
    sortable: true,
    rules: [BeakRequired(), BeakMin(1)],
  );

  /// Unit price in dollars.
  static const unitPrice = BeakDecimalColumn(
    key: 'unit_price',
    label: 'Unit price',
    prefix: r'$',
    rules: [BeakRequired(), BeakMin(0)],
  );

  /// The owning order.
  static const orderId = BeakStringColumn(
    key: 'order_id',
    label: 'Order',
    visibleOn: {BeakContext.form},
  );

  /// The product sold.
  static const productId = BeakStringColumn(
    key: 'product_id',
    label: 'Product',
    visibleOn: {BeakContext.form},
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    label,
    quantity,
    unitPrice,
    orderId,
    productId,
  ];
}

/// Typed relationships of the order-items resource.
abstract final class OrderItemRelations {
  /// The owning order.
  static const order = BeakBelongsTo(
    key: 'order',
    label: 'Order',
    relatedTable: 'orders',
    displayColumnKey: 'reference',
    foreignKey: 'order_id',
    searchColumnKeys: ['reference'],
  );

  /// The product sold.
  static const product = BeakBelongsTo(
    key: 'product',
    label: 'Product',
    relatedTable: 'products',
    displayColumnKey: 'name',
    foreignKey: 'product_id',
    searchColumnKeys: ['name'],
  );
}

/// The order-items resource — one line of an order.
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
