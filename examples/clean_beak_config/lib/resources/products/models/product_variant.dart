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
