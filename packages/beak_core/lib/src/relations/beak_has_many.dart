part of 'beak_relationship.dart';

/// A parent-side to-many relationship: records in [relatedTable] hold
/// [foreignKey] pointing back at this model.
///
/// Renders as a badge list of related records; in forms the frontend maps
/// the intent to a relation manager/repeater.
///
/// ```dart
/// // An order's line items, each carrying `order_items.order_id`.
/// static const items = BeakHasMany(
///   key: 'items',
///   label: 'Items',
///   relatedTable: 'order_items',
///   displayColumnKey: 'label',
///   foreignKey: 'order_id',
/// );
/// ```
final class BeakHasMany extends BeakRelationship {
  /// Creates a has-many relationship resolved via [foreignKey].
  const BeakHasMany({
    required super.key,
    required super.label,
    required super.relatedTable,
    required super.displayColumnKey,
    required this.foreignKey,
    super.searchColumnKeys,
    this.onDelete = BeakOnDelete.restrict,
    this.owned = false,
  });

  /// The column on the related table pointing back at this model's id.
  final String foreignKey;

  /// Whether children belong exclusively to the parent and may be deleted by
  /// an explicitly configured relationship editor.
  final bool owned;

  /// What happens to the related rows when a record of this model is
  /// deleted. Defaults to [BeakOnDelete.restrict] — never orphan or drop
  /// child rows unless the model opts in.
  final BeakOnDelete onDelete;

  @override
  BeakRenderConfig get renderConfig =>
      const BeakRenderConfig.uniform(BeakRenderIntent.relationBadges);

  @override
  BeakRelationCardinality get cardinality => BeakRelationCardinality.many;
}
