# Related records

> Configure related editors while Beak manages their draft graph.

Declare a relationship on the schema and place its generated field in a form. Beak loads existing rows, tracks local changes and builds the save plan.

```dart title="examples/clean_beak_config/lib/resources/orders/models/order_item.dart"
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
  @Column(label: 'Quantity', rules: [BeakMin(1)])
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
```

A to-one input uses `.inputCombobox()`. A to-many field uses `.tableForm(...)`; galleries use `.galleryForm(...)`. Configure the related fields inside that section, and use an advanced form for less common options.

## Ownership and cancellation

Owned children belong to the parent's lifecycle. Shared records and pivot connections have different removal semantics. Declare ownership on the relationship, and choose detach or owned deletion in its editor. Removing a row from a draft does not immediately delete it remotely.

Related creation inside a picker stays in the parent draft. Modal cancellation restores its checkpoint. Finishing the parent resolves temporary identities and saves the graph through the source's commit capability.

## Dependent selections

Shared `BeakExists` rules with `BeakFieldMatch` describe eligible foreign keys. Standard pickers infer the matching filters and prerequisites, and recheck a selected value when dependencies change. The backend enforces the same rule independently.

The order example makes delivery profiles depend on the selected customer. A custom option query remains available when eligibility needs a genuinely application-specific query.

## Continue reading

- [Seeding and the API](04-seeding-and-the-api.md)
- [Relationship reference](../models/relationships.md)
