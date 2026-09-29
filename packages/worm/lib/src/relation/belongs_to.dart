/// BelongsTo (inverse of HasOne / HasMany).
library;

import '../adapter/database_adapter.dart';
import '../model/model.dart';
import '../query/field.dart';
import '../query/field_operators.dart';
import '../query/predicate_tree.dart';
import '../query/query_descriptor.dart';
import 'relation_base.dart';

/// A `BelongsTo` relationship: each child belongs
/// to a single parent. The foreign key lives on the
/// child; the owner key on the parent.
final class BelongsToRelation<Child extends Model, Parent extends Model>
    extends Relation<Child, Parent> {
  /// Creates a [BelongsToRelation].
  const BelongsToRelation({
    required super.name,
    required this.parentTable,
    required this.foreignKey,
    required this.hydrateParent,
    this.ownerKey = 'id',
  });

  /// Snake_case table holding the parent rows.
  final String parentTable;

  /// Foreign-key column on the child table.
  final String foreignKey;

  /// Owner-key column on the parent table.
  final String ownerKey;

  /// Hydrator producing a [Parent] from a row.
  final Parent Function(Map<String, Object?>) hydrateParent;

  @override
  String get targetTable => parentTable;

  @override
  Future<RelationLoadResult<Child>> load(
    DatabaseAdapter adapter,
    List<Child> children,
  ) => loadWithFilter(adapter, children);

  /// Loads the parents with [extraFilter] AND-merged into the parent
  /// SELECT: a child whose parent the filter rejects gets `null`, exactly as
  /// if it had no parent.
  @override
  Future<RelationLoadResult<Child>> loadWithFilter(
    DatabaseAdapter adapter,
    List<Child> children, {
    PredicateTree? extraFilter,
  }) async {
    final foreignIds = <Object?>{
      for (final c in children)
        if (c.toRow()[foreignKey] != null) c.toRow()[foreignKey],
    }.toList();
    if (foreignIds.isEmpty) {
      return RelationLoadResult<Child>(
        setOnParent: (_) {},
        stats: const LoadStats(queriesExecuted: 0),
      );
    }
    final inClause = Field<Object?>(ownerKey).inList(foreignIds);
    final where = extraFilter == null ? inClause : inClause.and(extraFilter);
    final rows = await adapter.select(
      QueryDescriptor(table: parentTable, where: where),
    );
    final byOwner = <Object?, Parent>{
      for (final row in rows) row[ownerKey]: hydrateParent(row),
    };
    return RelationLoadResult<Child>(
      setOnParent: (child) {
        final fk = child.toRow()[foreignKey];
        child.relations[name] = byOwner[fk];
      },
      stats: const LoadStats(queriesExecuted: 1),
    );
  }
}
