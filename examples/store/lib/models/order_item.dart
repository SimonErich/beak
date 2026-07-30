import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'order.dart';
import 'product.dart';

part 'order_item.beak.dart';

/// One line of an order.
@Resource()
final class OrderItem extends BeakSchema {
  /// What the line reads on the invoice.
  @Display()
  @Column(searchable: true, rules: [BeakMaxLength(160)])
  late final String label;

  /// How many units were bought.
  @Column(min: 1, rules: [BeakMin(1)])
  late final int quantity;

  /// What one unit cost, in euros.
  @Column(prefix: '€', rules: [BeakMin(0)])
  late final double unitPrice;

  /// The order this line belongs to.
  @BelongsTo(onDelete: BeakOnDelete.cascade, inverse: false)
  late final Order order;

  /// The product this line sells.
  @BelongsTo(onDelete: BeakOnDelete.restrict, inverse: false)
  late final Product product;
}
