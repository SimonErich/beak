import 'package:beak_core/beak_core.dart';

/// Lifecycle states used by the fixture product.
enum ProductStatus {
  /// Not yet on sale.
  draft,

  /// Live in the catalog.
  published,
}

/// Typed columns of the fixture products table.
abstract final class ProductColumns {
  /// Primary key.
  static const id = BeakStringColumn(key: 'id', label: 'Id');

  /// Display name.
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakMaxLength(60)],
  );

  /// Sale price.
  static const price = BeakDecimalColumn(
    key: 'price',
    label: 'Price',
    sortable: true,
    rules: [BeakMin(1), BeakMax(500)],
  );

  /// Units in stock.
  static const stock = BeakIntColumn(
    key: 'stock',
    label: 'Stock',
    min: 0,
    max: 99,
  );

  /// Lifecycle state.
  static const status = BeakEnumColumn<ProductStatus>(
    key: 'status',
    label: 'Status',
    values: ProductStatus.values,
  );

  /// Owning category id.
  static const categoryId = BeakStringColumn(
    key: 'category_id',
    label: 'Category',
  );

  /// Soft-delete marker.
  static const deletedAt = BeakDateTimeColumn(
    key: 'deleted_at',
    label: 'Deleted',
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    id,
    name,
    price,
    stock,
    status,
    categoryId,
    deletedAt,
  ];
}

/// Relationships of the fixture products table.
abstract final class ProductRelations {
  /// The category a product belongs to.
  static const category = BeakBelongsTo(
    key: 'category',
    label: 'Category',
    relatedTable: 'categories',
    displayColumnKey: 'name',
    foreignKey: 'category_id',
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
  );
}

/// A soft-deleting products model with one of each relationship kind.
final class ProductModel extends BeakModel {
  /// Creates the fixture model.
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

/// Typed columns of the fixture categories table.
abstract final class CategoryColumns {
  /// Primary key.
  static const id = BeakStringColumn(key: 'id', label: 'Id');

  /// Display name.
  static const name = BeakStringColumn(key: 'name', label: 'Name');

  /// All columns, in display order.
  static const List<BeakColumn> values = [id, name];
}

/// A hard-deleting lookup model, the inverse side of the belongs-to.
final class CategoryModel extends BeakModel {
  /// Creates the fixture model.
  const CategoryModel();

  @override
  String get table => 'categories';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => CategoryColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    BeakHasMany(
      key: 'products',
      label: 'Products',
      relatedTable: 'products',
      displayColumnKey: 'name',
      foreignKey: 'category_id',
    ),
  ];
}

/// A plain lookup model reached through the pivot.
final class TagModel extends BeakModel {
  /// Creates the fixture model.
  const TagModel();

  @override
  String get table => 'tags';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => CategoryColumns.values;
}

/// A registry over the three fixture models.
BeakModelRegistry buildContractRegistry() => BeakModelRegistry()
  ..register(const ProductModel())
  ..register(const CategoryModel())
  ..register(const TagModel());
