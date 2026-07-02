/// Many-to-many relationship via a pivot table.
library;

import '../adapter/database_adapter.dart';
import '../model/model.dart';
import '../query/field.dart';
import '../query/field_operators.dart';
import '../query/predicate_tree.dart';
import '../query/query_descriptor.dart';
import 'relation_base.dart';

/// A `BelongsToMany` relationship: parents and
/// related models are joined via a pivot table.
///
/// Eager loading executes exactly two queries: one
/// to load pivot rows for every parent, then one to
/// load the related rows whose primary keys appear
/// in the collected pivot rows.
final class BelongsToManyRelation<Parent extends Model, Related extends Model>
    extends Relation<Parent, Related> {
  /// Creates a [BelongsToManyRelation].
  const BelongsToManyRelation({
    required super.name,
    required this.relatedTable,
    required this.pivotTable,
    required this.parentPivotKey,
    required this.relatedPivotKey,
    required this.hydrateRelated,
    this.parentKey = 'id',
    this.relatedKey = 'id',
  });

  /// Snake_case table holding the related rows.
  final String relatedTable;

  /// Snake_case pivot table connecting the two
  /// sides.
  final String pivotTable;

  /// Column on the pivot that references the parent.
  final String parentPivotKey;

  /// Column on the pivot that references the related
  /// row.
  final String relatedPivotKey;

  /// Parent-side primary key column.
  final String parentKey;

  /// Related-side primary key column.
  final String relatedKey;

  /// Hydrator producing a [Related] from a row.
  final Related Function(Map<String, Object?>) hydrateRelated;

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
    final parentIds = parents.map((p) => p.id).toList();
    if (parentIds.isEmpty) {
      return RelationLoadResult<Parent>(
        setOnParent: (_) {},
        stats: const LoadStats(queriesExecuted: 0),
      );
    }
    final pivots = await _selectPivots(adapter, parentIds);
    final relatedIds = <Object?>{
      for (final p in pivots) p[relatedPivotKey],
    }.toList();
    final relatedRows = relatedIds.isEmpty
        ? const <Map<String, Object?>>[]
        : await _selectRelated(adapter, relatedIds, extraFilter);
    final relatedById = <Object?, Related>{
      for (final row in relatedRows) row[relatedKey]: hydrateRelated(row),
    };
    final groups = _groupByParent(pivots, relatedById);
    return RelationLoadResult<Parent>(
      setOnParent: (parent) {
        parent.relations[name] = groups[parent.id] ?? const <Object>[];
      },
      stats: const LoadStats(queriesExecuted: 2),
    );
  }

  Future<List<Map<String, Object?>>> _selectPivots(
    DatabaseAdapter adapter,
    List<Object?> parentIds,
  ) {
    final field = Field<Object?>(parentPivotKey);
    return adapter.select(
      QueryDescriptor(table: pivotTable, where: field.inList(parentIds)),
    );
  }

  Future<List<Map<String, Object?>>> _selectRelated(
    DatabaseAdapter adapter,
    List<Object?> relatedIds,
    PredicateTree? extraFilter,
  ) {
    final field = Field<Object?>(relatedKey);
    final inClause = field.inList(relatedIds);
    final where = extraFilter == null ? inClause : inClause.and(extraFilter);
    return adapter.select(QueryDescriptor(table: relatedTable, where: where));
  }

  Map<Object?, List<Related>> _groupByParent(
    List<Map<String, Object?>> pivots,
    Map<Object?, Related> relatedById,
  ) {
    final out = <Object?, List<Related>>{};
    for (final p in pivots) {
      final relatedId = p[relatedPivotKey];
      final model = relatedById[relatedId];
      if (model == null) continue;
      out.putIfAbsent(p[parentPivotKey], () => <Related>[]).add(model);
    }
    return out;
  }
}
