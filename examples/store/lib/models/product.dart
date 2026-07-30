import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import 'category.dart';
import 'order_item.dart';
import 'roast_profile.dart';
import 'tag.dart';

part 'product.beak.dart';

/// Lifecycle states of a product.
enum ProductStatus {
  /// Being drafted, not on sale.
  draft,

  /// Live in the catalog.
  published,

  /// Withdrawn from the catalog.
  archived,
}

/// A product in the catalog — the showcase schema.
///
/// Every column kind Beak has appears here once, together with all four
/// relationship kinds, soft deletes and timestamps. Nothing below is repeated
/// anywhere else: `beak prepare` derives the columns, the model, both sides of
/// every relationship, the typed record view and the migration from it.
@Resource(softDeletes: true, timestamps: true)
final class Product extends BeakSchema {
  /// What the product is called.
  ///
  /// Non-nullable, so it is required — the form validator, the API's
  /// validation and the column's `NOT NULL` all follow from the type.
  @Display()
  @Column(
    searchable: true,
    sortable: true,
    indexed: true,
    rules: [BeakMaxLength(255)],
  )
  late final String name;

  /// The stock-keeping unit, unique across the catalog.
  @Column(
    label: 'SKU',
    searchable: true,
    unique: true,
    rules: [BeakMaxLength(40)],
  )
  late final String sku;

  /// The short description shown in listings.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakText? summary;

  /// The long description, edited as rich text.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakRichText? description;

  /// Sale price in euros.
  @Column(prefix: '€', sortable: true, filterable: true, rules: [BeakMin(0)])
  late final double price;

  /// Units in stock.
  @Column(suffix: ' pcs', min: 0, sortable: true)
  late final int stock;

  /// Whether the product is featured on the storefront.
  @Column(filterable: true)
  late final bool featured;

  /// Lifecycle state, rendered as a coloured badge.
  @Column(filterable: true)
  @Badges({
    ProductStatus.draft: BeakColor.muted,
    ProductStatus.published: BeakColor.success,
    ProductStatus.archived: BeakColor.warning,
  })
  late final ProductStatus status;

  /// When the product went on sale.
  @Column(sortable: true, format: BeakDateFormat.relative)
  late final DateTime? publishedAt;

  /// The swatch shown beside the name.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakHexColor? swatch;

  /// Storefront metadata the catalog importer round-trips untouched.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakJson? metadata;

  /// The product photo.
  ///
  /// The rules are enforced twice from this one declaration: in the browser
  /// before the upload starts, and again in the API — a client that skips the
  /// panel does not skip the check.
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

  /// The spec sheet customers download.
  @FileField(
    storagePath: 'products/specs',
    maxSizeInBytes: 10 * 1024 * 1024,
    allowedTypes: [BeakFileType.pdf],
  )
  late final BeakFileRef? specSheet;

  /// The stock indicator, drawn by the panel's registered renderer.
  @Custom('stock_bar')
  @Column(visibleOn: {BeakContext.table})
  late final Object? stockLevel;

  /// The category this product is filed under.
  @BelongsTo(onDelete: BeakOnDelete.setNull)
  late final Category? category;

  /// The roast profile for this product, if it is coffee.
  @HasOne()
  late final RoastProfile? roastProfile;

  /// The tags attached to this product.
  @BelongsToMany(allowCreate: true)
  late final List<Tag> tags;

  /// The order lines that sold this product.
  @HasMany(onDelete: BeakOnDelete.restrict)
  late final List<OrderItem> orderItems;
}
