import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../../categories/models/category.dart';
import '../../taxes/models/tax_rate.dart';
import 'product_attribute.dart';
import 'product_variant.dart';
import 'product_image.dart';

part 'product.beak.dart';

/// Product schema; all metadata and typed helpers are generated.
@Resource()
final class Product extends BeakSchema {
  // --8<-- [start:ProductFields]
  /// Product name used in picker suggestions.
  @Display()
  @Column(searchable: true, sortable: true)
  late final String name;

  // --8<-- [start:productPrice]
  /// Current catalog unit price, exact and in euros.
  @Column(
    label: 'Net price',
    semantic: BeakSemantic.money(currency: 'EUR'),
    sortable: true,
    rules: [BeakMin(0)],
  )
  late final BeakDecimal price;
  // --8<-- [end:productPrice]

  /// Optional stock-keeping identifier for the base product.
  @Column(searchable: true)
  late final String? sku;

  /// Catalog description.
  late final String? description;

  /// Whether this product can be sold.
  @Column(defaultValue: true)
  late final bool active;
  // --8<-- [end:ProductFields]

  // --8<-- [start:ProductCategory]
  /// Category and its attribute definitions.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.setNull)
  late final Category? category;
  // --8<-- [end:ProductCategory]

  /// Default exclusive tax rate.
  @BelongsTo(inverse: false, onDelete: BeakOnDelete.setNull)
  late final TaxRate? taxRate;

  /// Product-specific attribute values.
  @HasMany(owned: true, onDelete: BeakOnDelete.cascade)
  late final List<ProductAttribute> attributes;

  /// Ordered product gallery, saved with the product draft.
  @HasMany(owned: true, onDelete: BeakOnDelete.cascade)
  late final List<ProductImage> images;

  /// Sellable variants with separate prices and stock.
  @HasMany(owned: true, onDelete: BeakOnDelete.cascade)
  late final List<ProductVariant> variants;
}
