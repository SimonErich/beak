import 'package:beak_core/beak_core.dart';

/// Typed column constants of the categories resource.
abstract final class CategoryColumns {
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
    rules: [BeakRequired(), BeakMaxLength(120)],
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [id, name];
}

/// Typed relationship constants of the categories resource.
abstract final class CategoryRelations {
  /// The products filed under a category.
  static const products = BeakHasMany(
    key: 'products',
    label: 'Products',
    relatedTable: 'products',
    displayColumnKey: 'name',
    foreignKey: 'category_id',
  );
}

/// The categories resource: a flat lookup table products point at.
final class CategoryModel extends BeakModel {
  /// Creates the categories model.
  const CategoryModel();

  @override
  String get table => 'categories';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => CategoryColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    CategoryRelations.products,
  ];
}
