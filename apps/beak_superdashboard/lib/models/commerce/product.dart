import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

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

/// Typed columns of the products resource — the catalog's centerpiece.
abstract final class ProductColumns {
  /// Display name.
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakMaxLength(255)],
  );

  /// Stock-keeping unit.
  static const sku = BeakStringColumn(
    key: 'sku',
    label: 'SKU',
    searchable: true,
    rules: [BeakMaxLength(40)],
  );

  /// Long-form description.
  static const description = BeakTextColumn(
    key: 'description',
    label: 'Description',
    searchable: true,
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// Sale price in dollars.
  static const price = BeakDecimalColumn(
    key: 'price',
    label: 'Price',
    prefix: r'$',
    sortable: true,
    filterable: true,
    rules: [BeakRequired(), BeakMin(0)],
  );

  /// Unit cost in dollars.
  static const cost = BeakDecimalColumn(
    key: 'cost',
    label: 'Cost',
    prefix: r'$',
    visibleOn: {BeakContext.form, BeakContext.detail},
    rules: [BeakMin(0)],
  );

  /// Units in stock.
  static const stock = BeakIntColumn(
    key: 'stock',
    label: 'Stock',
    min: 0,
    sortable: true,
    rules: [BeakMin(0)],
  );

  /// Lifecycle state, shown as a colored badge.
  static const status = BeakEnumColumn<ProductStatus>(
    key: 'status',
    label: 'Status',
    values: ProductStatus.values,
    defaultValue: ProductStatus.draft,
    filterable: true,
    badgeColors: {
      ProductStatus.draft: BeakColor.muted,
      ProductStatus.published: BeakColor.success,
      ProductStatus.scheduled: BeakColor.info,
      ProductStatus.inactive: BeakColor.warning,
    },
  );

  /// Product photo: max 5 MB, raster formats, thumbnail + webp on upload.
  static const image = BeakImageColumn(
    key: 'image',
    label: 'Image',
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
  );

  /// Foreign key owned by the `category` belongs-to relationship.
  static const categoryId = BeakStringColumn(
    key: 'category_id',
    label: 'Category',
    visibleOn: {BeakContext.form},
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    name,
    sku,
    description,
    price,
    cost,
    stock,
    status,
    image,
    categoryId,
    SharedColumns.createdAt,
    SharedColumns.updatedAt,
  ];
}

/// Typed relationships of the products resource.
abstract final class ProductRelations {
  /// The category a product is filed under.
  static const category = BeakBelongsTo(
    key: 'category',
    label: 'Category',
    relatedTable: 'categories',
    displayColumnKey: 'name',
    foreignKey: 'category_id',
    searchColumnKeys: ['name'],
  );

  /// The tags attached to a product.
  static const tags = BeakBelongsToMany(
    key: 'tags',
    label: 'Tags',
    relatedTable: 'tags',
    displayColumnKey: 'name',
    pivotTable: 'product_tag',
    foreignPivotKey: 'product_id',
    relatedPivotKey: 'tag_id',
    searchColumnKeys: ['name'],
  );

  /// The order line items referencing this product.
  static const items = BeakHasMany(
    key: 'items',
    label: 'Order items',
    relatedTable: 'order_items',
    displayColumnKey: 'label',
    foreignKey: 'product_id',
  );
}

/// The products resource — the showcase model (soft-deleting, every column
/// kind, belongs-to + belongs-to-many + has-many).
final class ProductModel extends BeakModel {
  /// Creates the products model.
  const ProductModel();

  @override
  String get table => 'products';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => ProductColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    ProductRelations.category,
    ProductRelations.tags,
    ProductRelations.items,
  ];

  @override
  bool get softDeletes => true;
}
