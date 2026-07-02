/// HasOne relationship (parent owns one child).
library;

import '../adapter/database_adapter.dart';
import '../model/model.dart';
import '../query/field.dart';
import '../query/field_operators.dart';
import '../query/predicate_tree.dart';
import '../query/query_descriptor.dart';
import 'relation_base.dart';

/// A `HasOne` relationship: each parent owns at
/// most one child, joined by the child's foreign
/// key referencing the parent's local key.
final class HasOneRelation<Parent extends Model, Child extends Model>
    extends Relation<Parent, Child> {
  /// Creates a [HasOneRelation].
  const HasOneRelation({
    required super.name,
    required this.childTable,
    required this.foreignKey,
    required this.hydrateChild,
    this.localKey = 'id',
  });

  /// Snake_case table holding the child rows.
  final String childTable;

  /// Foreign-key column on the child table.
  final String foreignKey;

  /// Local-key column on the parent table.
  final String localKey;

  /// Hydrator turning a raw row into [Child].
  final Child Function(Map<String, Object?>) hydrateChild;

  @override
  Future<RelationLoadResult<Parent>> load(
    DatabaseAdapter adapter,
    List<Parent> parents,
  ) => loadWithFilter(adapter, parents);

  @override
  Future<RelationLoadResult<Parent>> loadWithFilter(
    DatabaseAdapter adapter,
    List<Parent> parents, {
    PredicateTree? extraFilter,
  }) async {
    final keys = parents.map((p) => p.id).toList();
    if (keys.isEmpty) {
      return RelationLoadResult<Parent>(
        setOnParent: (_) {},
        stats: const LoadStats(queriesExecuted: 0),
      );
    }
    final field = Field<Object?>(foreignKey);
    final inClause = field.inList(keys);
    final where = extraFilter == null ? inClause : inClause.and(extraFilter);
    final rows = await adapter.select(
      QueryDescriptor(table: childTable, where: where),
    );
    final byParent = <Object?, Child>{
      for (final row in rows) row[foreignKey]: hydrateChild(row),
    };
    return RelationLoadResult<Parent>(
      setOnParent: (parent) {
        parent.relations[name] = byParent[parent.id];
      },
      stats: const LoadStats(queriesExecuted: 1),
    );
  }
}
