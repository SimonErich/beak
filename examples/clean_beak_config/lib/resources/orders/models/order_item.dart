import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'order.dart';
import '../../products/models/product.dart';
import '../../products/models/product_variant.dart';
import '../../taxes/models/tax_rate.dart';

part 'order_item.beak.dart';

/// OrderItem schema; all metadata and typed helpers are generated.
@Resource()
final class OrderItem extends BeakSchema {
  /// Catalog suggestions follow selection changes until explicitly overridden.
  static BeakModelBehavior get behavior => BeakModelBehavior(
    values: [
      BeakValueBehavior.suggested(
        field: OrderItemModel.overwritePrice,
        dependencies: [
          OrderItemModel.variant.price,
          OrderItemModel.product.price,
        ],
        resolve: (state) =>
            state.read(OrderItemModel.variant.price) ??
            state.read(OrderItemModel.product.price),
      ),
      BeakValueBehavior.suggested(
        field: OrderItemModel.label,
        dependencies: [
          OrderItemModel.variant.name,
          OrderItemModel.product.name,
        ],
        resolve: (state) => switch ((
          state.read(OrderItemModel.product.name),
          state.read(OrderItemModel.variant.name),
        )) {
          (final String name, final String variant) => '$name — $variant',
          (final String name, _) => name,
          _ => null,
        },
      ),
    ],
  );

  /// Custom lines require their own description and price; variants match products.
  static List<BeakRecordRule> get validationRules => [
    BeakRequiredIf(
      OrderItemModel.label,
      when: BeakWhen.present(OrderItemModel.productId).not,
      message: 'Describe this custom item.',
    ),
    BeakRequiredIf(
      OrderItemModel.overwritePrice,
      when: BeakWhen.present(OrderItemModel.productId).not,
      message: 'Enter a price for this custom item.',
    ),
    BeakExists(
      OrderItemModel.variantId,
      ProductVariantModel.id,
      matching: [
        BeakFieldMatch(
          target: ProductVariantModel.productId,
          source: OrderItemModel.productId,
        ),
      ],
    ),
  ];

  /// Optional label overriding the product name.
  @Display()
  late final String? label;

  /// Positive quantity of the selected product.
  @Column(label: 'Quantity', min: 1, rules: [BeakMin(1)])
  late final int quantity;

  /// Owning order; wired automatically when the graph is saved.
  @BelongsTo(onDelete: BeakOnDelete.cascade)
  late final Order order;

  /// Catalog product for this row.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final Product? product;

  /// Optional variant belonging to the selected catalog product.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final ProductVariant? variant;

  /// Optional tax rate for the order line.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.restrict)
  late final TaxRate? taxRate;

  /// Optional negotiated unit price in euros.
  @Column(prefix: '€', rules: [BeakMin(0)])
  late final double? overwritePrice;

  /// Optional discount on the complete line in euros.
  @Column(prefix: '€', rules: [BeakMin(0)])
  late final double? discount;
}
