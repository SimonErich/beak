import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'category.dart';
import 'order_item.dart';
import 'price_rule.dart';
import 'product_image.dart';
import 'product_review.dart';
import 'product_variant.dart';
import 'tag.dart';

part 'product.beak.dart';

/// Lifecycle state of a product.
enum ProductStatus {
  /// Being drafted, not on sale.
  draft,

  /// Live in the catalog.
  published,

  /// Scheduled to publish later.
  scheduled,

  /// Withdrawn from the catalog.
  inactive,
}

/// The products resource — the showcase model (soft-deleting, every column
/// kind, belongs-to + belongs-to-many + has-many).
@Resource(softDeletes: true, timestamps: true)
final class Product extends BeakSchema {
  /// Display name.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(255)])
  late final String name;

  /// Stock-keeping unit.
  @Column(label: 'SKU', searchable: true, rules: [BeakMaxLength(40)])
  late final String? sku;

  /// Long-form description.
  @Column(searchable: true, visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakText? description;

  /// Sale price in dollars.
  @Column(prefix: r'$', sortable: true, filterable: true, rules: [BeakMin(0)])
  late final double price;

  /// Unit cost in dollars.
  @Column(
    prefix: r'$',
    visibleOn: {BeakContext.form, BeakContext.detail},
    rules: [BeakMin(0)],
  )
  late final double? cost;

  /// Units in stock.
  @Column(min: 0, sortable: true, rules: [BeakMin(0)])
  late final int? stock;

  /// Lifecycle state, shown as a colored badge.
  @Column(defaultValue: ProductStatus.draft, filterable: true)
  @Badges({
    ProductStatus.draft: BeakColor.muted,
    ProductStatus.published: BeakColor.success,
    ProductStatus.scheduled: BeakColor.info,
    ProductStatus.inactive: BeakColor.warning,
  })
  late final ProductStatus? status;

  /// Product photo: max 5 MB, raster formats, thumbnail + webp on upload.
  @Image(
    storagePath: 'products',
    maxSizeInBytes: 5 * 1024 * 1024,
    allowedTypes: [BeakFileType.jpeg, BeakFileType.png, BeakFileType.webp],
    thumbnail: BeakDimensions(widthInPixels: 160, heightInPixels: 160),
    transforms: [
      BeakThumbnailTransform(
        size: BeakDimensions(widthInPixels: 160, heightInPixels: 160),
      ),
      BeakFormatTransform.webp(),
    ],
  )
  late final BeakImageRef? image;

  /// The category a product is filed under.
  @BelongsTo()
  late final Category? category;

  /// The tags attached to a product.
  @BelongsToMany()
  late final List<Tag> tags;

  /// The order line items referencing this product.
  @HasMany(label: 'Order items')
  late final List<OrderItem> items;

  /// The purchasable variations of this product.
  @HasMany()
  late final List<ProductVariant> variants;

  /// The gallery images of this product.
  @HasMany(label: 'Gallery')
  late final List<ProductImage> images;

  /// The customer reviews of this product.
  @HasMany()
  late final List<ProductReview> reviews;

  /// The conditional pricing rules on this product.
  @HasMany(label: 'Price rules')
  late final List<PriceRule> priceRules;
}
