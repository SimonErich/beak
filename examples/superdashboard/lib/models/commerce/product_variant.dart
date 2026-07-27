import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'product.dart';

part 'product_variant.beak.dart';

/// The product-variants resource — one purchasable variation of a product.
@Resource()
final class ProductVariant extends BeakSchema {
  /// Variant name, e.g. "500g · Whole bean".
  @Display()
  @Column(label: 'Variant', searchable: true, rules: [BeakMaxLength(120)])
  late final String name;

  /// Stock-keeping unit.
  @Column(label: 'SKU', rules: [BeakMaxLength(60)])
  late final String sku;

  /// Variant price in dollars.
  @Column(prefix: r'$', rules: [BeakMin(0)])
  late final double price;

  /// Units in stock.
  @Column(min: 0, sortable: true)
  late final int? stock;

  /// Whether this is the default variant shown first.
  @Column(label: 'Default')
  late final bool? isDefault;

  /// The owning product.
  @BelongsTo()
  late final Product? product;
}
