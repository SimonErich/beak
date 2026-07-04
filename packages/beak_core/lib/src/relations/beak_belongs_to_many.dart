part of 'beak_relationship.dart';

/// A many-to-many relationship joined through [pivotTable]: pivot rows pair
/// [foreignPivotKey] (this model's id) with [relatedPivotKey] (the related
/// record's id).
///
/// Renders as a badge list of related records; in forms the frontend maps
/// the intent to a searchable multi-select.
///
/// ```dart
/// // Products and tags joined through the `product_tag` pivot table.
/// static const tags = BeakBelongsToMany(
///   key: 'tags',
///   label: 'Tags',
///   relatedTable: 'tags',
///   displayColumnKey: 'name',
///   pivotTable: 'product_tag',
///   foreignPivotKey: 'product_id',
///   relatedPivotKey: 'tag_id',
///   searchColumnKeys: ['name'],
/// );
/// ```
final class BeakBelongsToMany extends BeakRelationship {
  /// Creates a belongs-to-many relationship joined through [pivotTable].
  const BeakBelongsToMany({
    required super.key,
    required super.label,
    required super.relatedTable,
    required super.displayColumnKey,
    required this.pivotTable,
    required this.foreignPivotKey,
    required this.relatedPivotKey,
    super.searchColumnKeys,
    this.allowCreate = false,
    this.maxAllowed,
    this.onDelete = BeakOnDelete.cascade,
  });

  /// Physical name of the join table holding the record pairs.
  final String pivotTable;

  /// The pivot column pointing at this model's id.
  final String foreignPivotKey;

  /// The pivot column pointing at the related record's id.
  final String relatedPivotKey;

  /// Whether form pickers may create a new related record inline.
  final bool allowCreate;

  /// Maximum number of related records that may be attached, if capped.
  final int? maxAllowed;

  /// What happens to the pivot rows when a record of this model is deleted.
  /// Defaults to [BeakOnDelete.cascade] — pivot rows are pure join data and
  /// are detached with their owner.
  final BeakOnDelete onDelete;

  @override
  BeakRenderConfig get renderConfig =>
      const BeakRenderConfig.uniform(BeakRenderIntent.relationBadges);

  @override
  BeakRelationCardinality get cardinality => BeakRelationCardinality.many;
}
