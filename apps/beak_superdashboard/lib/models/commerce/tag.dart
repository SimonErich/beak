import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the tags resource.
abstract final class TagColumns {
  /// Tag name.
  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakMaxLength(60)],
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [SharedColumns.id, name];
}

/// Typed relationships of the tags resource.
abstract final class TagRelations {
  /// Products carrying this tag, via the `product_tag` pivot.
  static const products = BeakBelongsToMany(
    key: 'products',
    label: 'Products',
    relatedTable: 'products',
    displayColumnKey: 'name',
    pivotTable: 'product_tag',
    foreignPivotKey: 'tag_id',
    relatedPivotKey: 'product_id',
    searchColumnKeys: ['name'],
  );
}

/// The tags resource — free-form product labels.
final class TagModel extends BeakModel {
  /// Creates the tags model.
  const TagModel();

  @override
  String get table => 'tags';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => TagColumns.values;

  @override
  List<BeakRelationship> get relationships => const [TagRelations.products];
}
