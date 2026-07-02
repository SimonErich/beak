/// Abstract relationship base.
library;

import '../adapter/database_adapter.dart';
import '../model/model.dart';
import '../query/predicate_tree.dart';

/// Statistics about an eager load operation.
final class LoadStats {
  /// Creates a [LoadStats].
  const LoadStats({required this.queriesExecuted});

  /// Number of underlying queries executed.
  final int queriesExecuted;
}

/// Result of loading a relation for a batch of
/// parents.
///
/// [setOnParent] is called once per parent and
/// installs the related model(s) under the relation
/// name on the parent's `relations` map.
final class RelationLoadResult<Parent extends Model> {
  /// Creates a [RelationLoadResult].
  const RelationLoadResult({required this.setOnParent, required this.stats});

  /// Function the eager loader calls to install
  /// loaded relations on a parent.
  final void Function(Parent parent) setOnParent;

  /// Diagnostics from the load.
  final LoadStats stats;
}

/// Abstract base for every relationship type.
///
/// Subclasses encapsulate the query-shape for
/// HasOne, HasMany, BelongsTo, etc., and implement
/// batched eager loading via [load].
abstract class Relation<Parent extends Model, Child extends Model> {
  /// Creates a [Relation].
  const Relation({required this.name});

  /// Stable name of this relation on the parent.
  final String name;

  /// Eager-load this relation for every parent in [parents], using
  /// [adapter].
  ///
  /// Implementations must use a batched IN-clause query (single
  /// round-trip) — never N queries.
  Future<RelationLoadResult<Parent>> load(
    DatabaseAdapter adapter,
    List<Parent> parents,
  );

  /// Eager-load this relation with an optional [extraFilter]
  /// AND-merged into the child SELECT.
  ///
  /// The default implementation forwards to [load] for backwards
  /// compatibility; relations that support filtering override this
  /// method to thread [extraFilter] into their child query.
  Future<RelationLoadResult<Parent>> loadWithFilter(
    DatabaseAdapter adapter,
    List<Parent> parents, {
    PredicateTree? extraFilter,
  }) => load(adapter, parents);
}
