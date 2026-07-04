part of 'beak_relationship.dart';

/// A child-side to-one relationship: this model's table holds [foreignKey]
/// pointing at one record in [relatedTable].
///
/// Renders as a link to the related record; in forms the frontend maps the
/// intent to a searchable single-select.
///
/// ```dart
/// // A product filed under one category, joined via `products.category_id`.
/// static const category = BeakBelongsTo(
///   key: 'category',
///   label: 'Category',
///   relatedTable: 'categories',
///   displayColumnKey: 'name',
///   foreignKey: 'category_id',
///   searchColumnKeys: ['name'],
/// );
/// ```
final class BeakBelongsTo extends BeakRelationship {
  /// Creates a belongs-to relationship stored via [foreignKey].
  const BeakBelongsTo({
    required super.key,
    required super.label,
    required super.relatedTable,
    required super.displayColumnKey,
    required this.foreignKey,
    super.searchColumnKeys,
  });

  /// The column on this model's table holding the related record's id.
  final String foreignKey;

  @override
  BeakRenderConfig get renderConfig =>
      const BeakRenderConfig.uniform(BeakRenderIntent.relationLink);

  @override
  BeakRelationCardinality get cardinality => BeakRelationCardinality.one;
}
