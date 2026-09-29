# Columns and validation

> Use typed fields, semantic metadata and shared model constraints.

Declare each field's type and shared constraints on the schema. Beak uses that information for controls, formatting, filters and authoritative validation.

```dart title="examples/clean_beak_config/lib/resources/products/models/product_variant.dart"
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'product.dart';
import 'variant_attribute.dart';
part 'product_variant.beak.dart';

/// A sellable product choice with its own price, SKU and inventory.
@Resource()
final class ProductVariant extends BeakSchema {
  /// A product can sell a particular attribute combination only once.
  static List<BeakRecordRule> get validationRules => [
    BeakUnique(
      ProductVariantModel.combinationKey,
      scope: [ProductVariantModel.productId],
    ),
    BeakDistinct(ProductVariantModel.attributes, VariantAttributeModel.name),
  ];

  /// Canonical server-derived combination identity; null for unconfigured variants.
  @Column(visibleOn: {})
  late final String? combinationKey;

  /// Choice title, such as 1 kg whole bean.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String name;

  /// Unique stock-keeping identifier.
  @Column(searchable: true, unique: true)
  late final String sku;

  /// Net unit price in euros.
  @Column(label: 'Net price', prefix: '€', sortable: true, rules: [BeakMin(0)])
  late final double price;

  /// Available units in this demonstration inventory.
  @Column(sortable: true, rules: [BeakMin(0)])
  late final int stock;

  /// Whether this variant can be added to a new invoice.
  late final bool active;

  /// Catalog product this variant belongs to.
  @BelongsTo(onDelete: BeakOnDelete.cascade)
  late final Product product;

  /// Values distinguishing this choice from the parent product.
  @HasMany(
    foreignKey: 'variant_id',
    owned: true,
    onDelete: BeakOnDelete.cascade,
  )
  late final List<VariantAttribute> attributes;
}
```

Non-nullable fields become required. `rules` adds reusable scalar constraints. `unique` is enforced by the database as well as preflight validation. Relationship identity types follow the related model's primary key.

## Rich values

The fulfillment policy demonstrates exact money, per-record currency, percentages, units, dates, durations, lists and structured objects. These use semantic metadata on existing storage columns. Their generated field references preserve the public Dart value type.

Read [Semantic fields](../models/semantic-fields.md) for the complete storage and formatting contract. Configure the panel's formatting policy once to control date patterns, locale, currency and empty values.

## Cross-field constraints

A schema's static `validationRules` getter declares conditional requirements, field comparisons, distinct collection values and relationship eligibility. These rules run through the common validation engine. A rule that must hold for all callers belongs here or in shared model behavior.

Placement validators can add screen-specific feedback. They do not replace the server's invariants. Missing, pending and invalid values remain visible in the draft until corrected.

## Continue reading

- [Relationships](03-relationships.md)
- [Validation rules](../models/validation.md)
