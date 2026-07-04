part of 'beak_relationship.dart';

/// A parent-side to-one relationship: one record in [relatedTable] holds
/// [foreignKey] pointing back at this model.
///
/// Renders as a link to the related record; in forms the frontend maps the
/// intent to a searchable single-select.
///
/// ```dart
/// // A user's one profile row, which carries `profiles.user_id`.
/// static const profile = BeakHasOne(
///   key: 'profile',
///   label: 'Profile',
///   relatedTable: 'profiles',
///   displayColumnKey: 'headline',
///   foreignKey: 'user_id',
/// );
/// ```
final class BeakHasOne extends BeakRelationship {
  /// Creates a has-one relationship resolved via [foreignKey].
  const BeakHasOne({
    required super.key,
    required super.label,
    required super.relatedTable,
    required super.displayColumnKey,
    required this.foreignKey,
    super.searchColumnKeys,
  });

  /// The column on the related table pointing back at this model's id.
  final String foreignKey;

  @override
  BeakRenderConfig get renderConfig =>
      const BeakRenderConfig.uniform(BeakRenderIntent.relationLink);

  @override
  BeakRelationCardinality get cardinality => BeakRelationCardinality.one;
}
