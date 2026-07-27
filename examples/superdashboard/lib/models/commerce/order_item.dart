import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'order.dart';
import 'product.dart';

part 'order_item.beak.dart';

/// The order-items resource — one line of an order.
@Resource()
final class OrderItem extends BeakSchema {
  /// Line label, e.g. "2× Espresso Beans".
  @Display()
  @Column(label: 'Item', searchable: true, rules: [BeakMaxLength(160)])
  late final String label;

  /// Quantity ordered.
  @Column(label: 'Qty', min: 1, sortable: true, rules: [BeakMin(1)])
  late final int quantity;

  /// Unit price in dollars.
  @Column(label: 'Unit price', prefix: r'$', rules: [BeakMin(0)])
  late final double unitPrice;

  /// The owning order.
  @BelongsTo()
  late final Order? order;

  /// The product sold.
  @BelongsTo()
  late final Product? product;
}
