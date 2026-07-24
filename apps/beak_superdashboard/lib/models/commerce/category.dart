import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the categories resource.
abstract final class CategoryColumns {
  /// Category name.
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakMaxLength(120)],
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [SharedColumns.id, name];
}

/// Typed relationships of the categories resource.
abstract final class CategoryRelations {
  /// Products filed under this category.
  static const products = BeakHasMany(
    key: 'products',
    label: 'Products',
    relatedTable: 'products',
    displayColumnKey: 'name',
    foreignKey: 'category_id',
  );
}

/// The categories resource — the product catalog's top-level grouping.
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
