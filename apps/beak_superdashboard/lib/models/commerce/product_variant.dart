import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the product-variants resource — a purchasable variation
/// of a product (size/color/etc.) with its own SKU, price, and stock.
abstract final class ProductVariantColumns {
  /// Variant name, e.g. "500g · Whole bean".
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Variant',
    searchable: true,
    rules: [BeakRequired(), BeakMaxLength(120)],
  );

  /// Stock-keeping unit.
  static const sku = BeakStringColumn(
    key: 'sku',
    label: 'SKU',
    rules: [BeakRequired(), BeakMaxLength(60)],
  );

  /// Variant price in dollars.
  static const price = BeakDecimalColumn(
    key: 'price',
    label: 'Price',
    prefix: r'$',
    rules: [BeakRequired(), BeakMin(0)],
  );

  /// Units in stock.
  static const stock = BeakIntColumn(
    key: 'stock',
    label: 'Stock',
    min: 0,
    sortable: true,
  );

  /// Whether this is the default variant shown first.
  static const isDefault = BeakBoolColumn(key: 'is_default', label: 'Default');

  /// The owning product.
  static const productId = BeakStringColumn(
    key: 'product_id',
    label: 'Product',
    visibleOn: {BeakContext.form},
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    name,
    sku,
    price,
    stock,
    isDefault,
    productId,
  ];
}

/// Typed relationships of the product-variants resource.
abstract final class ProductVariantRelations {
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

/// The product-variants resource — one purchasable variation of a product.
final class ProductVariantModel extends BeakModel {
  /// Creates the product-variants model.
  const ProductVariantModel();

  @override
  String get table => 'product_variants';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => ProductVariantColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    ProductVariantRelations.product,
  ];
}
