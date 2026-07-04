import 'package:beak_core/beak_core.dart';

/// Lifecycle states of a product.
enum ProductStatus {
  /// Being drafted, not on sale.
  draft,

  /// Live in the catalog.
  published,

  /// Withdrawn from the catalog.
  archived,
}

/// Typed column constants of the products resource — the showcase model:
/// every major column kind, Filament-style upload rules, and a transform
/// pipeline, declared exactly once.
abstract final class ProductColumns {
  /// Primary key.
  static const id = BeakStringColumn(
    key: 'id',
    label: 'Id',
    visibleOn: {BeakContext.detail},
  );

  /// Display name.
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakMaxLength(255)],
  );

  /// Long-form description.
  static const description = BeakTextColumn(
    key: 'description',
    label: 'Description',
    searchable: true,
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  /// Sale price in euros.
  static const price = BeakDecimalColumn(
    key: 'price',
    label: 'Price',
    prefix: '€',
    sortable: true,
    filterable: true,
    rules: [BeakRequired(), BeakMin(0)],
  );

  /// Units in stock.
  static const stock = BeakIntColumn(
    key: 'stock',
    label: 'Stock',
    min: 0,
    sortable: true,
    rules: [BeakMin(0)],
  );

  /// Lifecycle state, rendered as a colored badge.
  static const status = BeakEnumColumn<ProductStatus>(
    key: 'status',
    label: 'Status',
    values: ProductStatus.values,
    defaultValue: ProductStatus.draft,
    filterable: true,
    badgeColors: {
      ProductStatus.draft: BeakColor.muted,
      ProductStatus.published: BeakColor.success,
      ProductStatus.archived: BeakColor.warning,
    },
  );

  /// Product photo: max 5 MB, raster formats only, thumbnail + webp
  /// renditions generated on upload.
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

  /// Creation timestamp, stamped by the backend.
  static const createdAt = BeakDateTimeColumn(
    key: 'created_at',
    label: 'Created',
    sortable: true,
    visibleOn: {BeakContext.detail},
  );

  /// Last-update timestamp, rendered relatively in tables.
  static const updatedAt = BeakDateTimeColumn(
    key: 'updated_at',
    label: 'Updated',
    format: BeakDateFormat.relative,
    sortable: true,
    visibleOn: {BeakContext.table, BeakContext.detail},
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    id,
    name,
    description,
    price,
    stock,
    status,
    image,
    categoryId,
    createdAt,
    updatedAt,
  ];
}

/// Typed relationship constants of the products resource.
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
}

/// The products resource — the catalog's centerpiece.
///
/// The showcase model: it exposes every major column kind via
/// [ProductColumns], a belongs-to [ProductRelations.category] and a
/// belongs-to-many [ProductRelations.tags], and opts into soft deletes.
/// Registering it (see [referenceModels]) is all it takes to get a full
/// CRUD API and a table/detail/form panel page.
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
  ];

  @override
  bool get softDeletes => true;
}
