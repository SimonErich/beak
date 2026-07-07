import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the product-images resource — one image in a product's
/// gallery.
abstract final class ProductImageColumns {
  /// The image URL.
  static const url = BeakImageColumn(
    key: 'url',
    label: 'Image',
    storagePath: 'product-images',
    rules: [BeakRequired()],
  );

  /// Alt text / caption.
  static const alt = BeakStringColumn(
    key: 'alt',
    label: 'Caption',
    searchable: true,
    rules: [BeakMaxLength(160)],
  );

  /// Ordering within the gallery.
  static const sortIndex = BeakIntColumn(
    key: 'sort_index',
    label: 'Order',
    min: 0,
    sortable: true,
  );

  /// Whether this is the primary (hero) image.
  static const isPrimary = BeakBoolColumn(key: 'is_primary', label: 'Primary');

  /// The owning product.
  static const productId = BeakStringColumn(
    key: 'product_id',
    label: 'Product',
    visibleOn: {BeakContext.form},
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    url,
    alt,
    sortIndex,
    isPrimary,
    productId,
  ];
}

/// Typed relationships of the product-images resource.
abstract final class ProductImageRelations {
  /// The owning product.
  static const product = BeakBelongsTo(
    key: 'product',
    label: 'Product',
    relatedTable: 'products',
    displayColumnKey: 'name',
    foreignKey: 'product_id',
    searchColumnKeys: ['name'],
  );
}

/// The product-images resource — one image in a product's gallery.
final class ProductImageModel extends BeakModel {
  /// Creates the product-images model.
  const ProductImageModel();

  @override
  String get table => 'product_images';

  @override
  String get displayColumnKey => 'alt';

  @override
  List<BeakColumn> get columns => ProductImageColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    ProductImageRelations.product,
  ];
}
