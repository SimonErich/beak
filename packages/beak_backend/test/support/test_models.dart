/// Shared Beak model fixtures and the worm in-memory test harness for the
/// backend suites: a small Products/Categories/Tags/Reviews domain covering
/// every relationship kind and soft deletes.
library;

import 'package:beak_core/beak_core.dart';
import 'package:worm/worm.dart';

/// Column constants of the products fixture model.
abstract final class ProductColumns {
  /// Primary key.
  static const id = BeakIntColumn(key: 'id', label: 'Id');

  /// Display name; searchable and sortable.
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    sortable: true,
  );

  /// Price in euro; sortable.
  static const price = BeakDecimalColumn(
    key: 'price',
    label: 'Price',
    sortable: true,
  );

  /// Whether the product is on sale.
  static const active = BeakBoolColumn(key: 'active', label: 'Active');

  /// Creation timestamp.
  static const createdAt = BeakDateTimeColumn(
    key: 'created_at',
    label: 'Created at',
    sortable: true,
  );

  /// Foreign key to the owning category.
  static const categoryId = BeakIntColumn(
    key: 'category_id',
    label: 'Category id',
    filterable: true,
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    id,
    name,
    price,
    active,
    createdAt,
    categoryId,
  ];
}

/// The products fixture model: soft-deleting, with every relationship kind.
final class ProductModel extends BeakModel {
  /// Creates the products model.
  const ProductModel();

  /// Typed reference to the primary key.
  static const id = BeakScalarField<int>(
    model: ProductModel(),
    column: ProductColumns.id,
  );

  /// Typed reference to the display name.
  static const name = BeakScalarField<String>(
    model: ProductModel(),
    column: ProductColumns.name,
  );

  /// The belongs-to relationship to the owning category.
  static const BeakBelongsTo categoryRelation = BeakBelongsTo(
    key: 'category',
    label: 'Category',
    relatedTable: 'categories',
    displayColumnKey: 'name',
    foreignKey: 'category_id',
  );

  /// Typed reference to the owning category.
  static const category = BeakToOneField(
    model: ProductModel(),
    relation: categoryRelation,
    target: CategoryModel(),
  );

  /// Typed reference to the price.
  static const price = BeakScalarField<double>(
    model: ProductModel(),
    column: ProductColumns.price,
  );

  @override
  String get table => 'products';

  @override
  String get displayColumnKey => 'name';

  @override
  bool get softDeletes => true;

  @override
  List<BeakColumn> get columns => ProductColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    categoryRelation,
    BeakHasMany(
      key: 'reviews',
      label: 'Reviews',
      relatedTable: 'reviews',
      displayColumnKey: 'body',
      foreignKey: 'product_id',
    ),
    BeakBelongsToMany(
      key: 'tags',
      label: 'Tags',
      relatedTable: 'tags',
      displayColumnKey: 'name',
      pivotTable: 'product_tag',
      foreignPivotKey: 'product_id',
      relatedPivotKey: 'tag_id',
    ),
  ];
}

/// The categories fixture model, with a has-many back to products so nested
/// relation paths (`category.products`) can be exercised.
final class CategoryModel extends BeakModel {
  /// Creates the categories model.
  const CategoryModel();

  /// Typed reference to the primary key.
  static const id = BeakScalarField<int>(model: CategoryModel(), column: _id);

  static const BeakColumn _id = BeakIntColumn(key: 'id', label: 'Id');

  @override
  String get table => 'categories';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    _id,
    BeakStringColumn(key: 'name', label: 'Name', searchable: true),
  ];

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

/// The tags fixture model.
final class TagModel extends BeakModel {
  /// Creates the tags model.
  const TagModel();

  @override
  String get table => 'tags';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => const [
    BeakIntColumn(key: 'id', label: 'Id'),
    BeakStringColumn(key: 'name', label: 'Name'),
  ];
}

/// The reviews fixture model.
final class ReviewModel extends BeakModel {
  /// Creates the reviews model.
  const ReviewModel();

  /// Typed reference to the owning product's key.
  static const productId = BeakScalarField<int>(
    model: ReviewModel(),
    column: _productId,
  );

  /// Typed reference to the star rating.
  static const rating = BeakScalarField<int>(
    model: ReviewModel(),
    column: _rating,
  );

  /// Typed reference to the review text.
  static const body = BeakScalarField<String>(
    model: ReviewModel(),
    column: _body,
  );

  static const BeakColumn _productId = BeakIntColumn(
    key: 'product_id',
    label: 'Product id',
  );

  static const BeakColumn _rating = BeakIntColumn(
    key: 'rating',
    label: 'Rating',
    sortable: true,
  );

  static const BeakColumn _body = BeakTextColumn(key: 'body', label: 'Body');

  @override
  String get table => 'reviews';

  @override
  String get displayColumnKey => 'body';

  @override
  List<BeakColumn> get columns => const [
    BeakIntColumn(key: 'id', label: 'Id'),
    _productId,
    _rating,
    _body,
  ];
}

/// A registry holding every fixture model.
BeakModelRegistry createTestRegistry() => BeakModelRegistry()
  ..register(const ProductModel())
  ..register(const CategoryModel())
  ..register(const TagModel())
  ..register(const ReviewModel());

/// The in-memory schema backing the fixture domain.
const List<SchemaDescriptor> testSchema = [
  SchemaDescriptor.createTable(
    table: 'products',
    columns: [
      SchemaColumn(name: 'id', type: ColumnType.integer, isPrimaryKey: true),
      SchemaColumn(name: 'name', type: ColumnType.text),
      SchemaColumn(name: 'price', type: ColumnType.decimal),
      SchemaColumn(name: 'active', type: ColumnType.boolean),
      SchemaColumn(name: 'created_at', type: ColumnType.dateTime),
      SchemaColumn(name: 'category_id', type: ColumnType.integer),
      SchemaColumn(name: 'deleted_at', type: ColumnType.dateTime),
    ],
  ),
  SchemaDescriptor.createTable(
    table: 'categories',
    columns: [
      SchemaColumn(name: 'id', type: ColumnType.integer, isPrimaryKey: true),
      SchemaColumn(name: 'name', type: ColumnType.text),
    ],
  ),
  SchemaDescriptor.createTable(
    table: 'tags',
    columns: [
      SchemaColumn(name: 'id', type: ColumnType.integer, isPrimaryKey: true),
      SchemaColumn(name: 'name', type: ColumnType.text),
    ],
  ),
  SchemaDescriptor.createTable(
    table: 'product_tag',
    columns: [
      SchemaColumn(name: 'product_id', type: ColumnType.integer),
      SchemaColumn(name: 'tag_id', type: ColumnType.integer),
    ],
  ),
  SchemaDescriptor.createTable(
    table: 'reviews',
    columns: [
      SchemaColumn(name: 'id', type: ColumnType.integer, isPrimaryKey: true),
      SchemaColumn(name: 'product_id', type: ColumnType.integer),
      SchemaColumn(name: 'rating', type: ColumnType.integer),
      SchemaColumn(name: 'body', type: ColumnType.text),
    ],
  ),
];

/// Connects a fresh [InMemoryAdapter], creates the fixture schema, and
/// initializes worm on it — pair with `tearDown(Worm.reset)`.
Future<InMemoryAdapter> createTestDatabase() async {
  final adapter = InMemoryAdapter();
  await adapter.connect();
  for (final descriptor in testSchema) {
    await adapter.executeSchema(descriptor);
  }
  await Worm.initialize(
    config: const WormConfig(),
    adapters: <String, DatabaseAdapter>{'default': adapter},
  );
  return adapter;
}
