/// Polymorphic many-to-many relationship through a
/// pivot table carrying morph-type / morph-id columns.
library;

import '../adapter/database_adapter.dart';
import '../model/model.dart';
import '../query/field.dart';
import '../query/field_operators.dart';
import '../query/operator.dart';
import '../query/predicate.dart';
import '../query/predicate_tree.dart' show LeafNode;
import '../query/query_descriptor.dart';
import 'relation_base.dart';

/// A `MorphToMany` relationship.
///
/// Eager loading executes exactly two queries: one
/// to load pivot rows matching the parents' ids and
/// morph type, then one to load related rows by id.
final class MorphToManyRelation<Parent extends Model, Related extends Model>
    extends Relation<Parent, Related> {
  /// Creates a [MorphToManyRelation].
  const MorphToManyRelation({
    required super.name,
    required this.relatedTable,
    required this.pivotTable,
    required this.parentMorphName,
    required this.morphType,
    required this.relatedPivotKey,
    required this.hydrateRelated,
    this.parentKey = 'id',
    this.relatedKey = 'id',
  });

  /// Related rows table.
  final String relatedTable;

  /// Pivot table carrying morph + related FKs.
  final String pivotTable;

  /// Morph-name prefix yielding `<morphName>_type`
  /// and `<morphName>_id` columns on the pivot.
  final String parentMorphName;

  /// Morph-type value identifying this parent.
  final String morphType;

  /// Pivot column referencing the related rows.
  final String relatedPivotKey;

  /// Parent primary-key column.
  final String parentKey;

  /// Related primary-key column.
  final String relatedKey;

  /// Hydrator turning a related row into [Related].
  final Related Function(Map<String, Object?>) hydrateRelated;

  /// Pivot column carrying the parent type.
  String get morphTypeColumn => '${parentMorphName}_type';

  /// Pivot column carrying the parent id.
  String get morphIdColumn => '${parentMorphName}_id';

  @override
  String get targetTable => relatedTable;

  @override
  Future<RelationLoadResult<Parent>> load(
    DatabaseAdapter adapter,
    List<Parent> parents,
  ) async {
    final parentIds = parents.map((p) => p.id).toList();
    if (parentIds.isEmpty) {
      return RelationLoadResult<Parent>(
        setOnParent: (_) {},
        stats: const LoadStats(queriesExecuted: 0),
      );
    }
    final morphIdField = Field<Object?>(morphIdColumn);
    final where = morphIdField
        .inList(parentIds)
        .and(
          LeafNode(
            Predicate(
              fieldName: morphTypeColumn,
              operator: Operator.eq,
              value: morphType,
            ),
          ),
        );
    final pivotRows = await adapter.select(
      QueryDescriptor(table: pivotTable, where: where),
    );
    final relatedIds = <Object?>{
      for (final row in pivotRows) row[relatedPivotKey],
    }.whereType<Object>().toList();
    final relatedRows = relatedIds.isEmpty
        ? const <Map<String, Object?>>[]
        : await adapter.select(
            QueryDescriptor(
              table: relatedTable,
              where: Field<Object?>(relatedKey).inList(relatedIds),
            ),
          );
    final byId = <Object?, Related>{
      for (final row in relatedRows) row[relatedKey]: hydrateRelated(row),
    };
    final grouped = <Object?, List<Related>>{};
    for (final pivot in pivotRows) {
      final model = byId[pivot[relatedPivotKey]];
      if (model == null) continue;
      grouped.putIfAbsent(pivot[morphIdColumn], () => <Related>[]).add(model);
    }
    return RelationLoadResult<Parent>(
      setOnParent: (parent) {
        parent.relations[name] = grouped[parent.id] ?? const <Object>[];
      },
      stats: const LoadStats(queriesExecuted: 2),
    );
  }
}
