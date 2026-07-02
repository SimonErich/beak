/// Polymorphic one-to-many (parent owns many
/// polymorphic children) relationship.
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

/// A `MorphMany` relationship: the parent owns zero
/// or more polymorphic children where each child
/// carries `<morphName>_type` + `<morphName>_id`
/// columns.
final class MorphManyRelation<Parent extends Model, Child extends Model>
    extends Relation<Parent, Child> {
  /// Creates a [MorphManyRelation].
  const MorphManyRelation({
    required super.name,
    required this.childTable,
    required this.morphType,
    required this.parentMorphName,
    required this.hydrateChild,
    this.localKey = 'id',
  });

  /// Child table containing the morph columns.
  final String childTable;

  /// The morph-type string identifying this parent's
  /// table on the child.
  final String morphType;

  /// Morph-name prefix used to derive
  /// `<morphName>_type` / `<morphName>_id`.
  final String parentMorphName;

  /// Parent-side primary-key column.
  final String localKey;

  /// Hydrator turning a raw row into [Child].
  final Child Function(Map<String, Object?>) hydrateChild;

  /// Column on the child carrying the parent type.
  String get morphTypeColumn => '${parentMorphName}_type';

  /// Column on the child carrying the parent id.
  String get morphIdColumn => '${parentMorphName}_id';

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
    final idField = Field<Object?>(morphIdColumn);
    final where = idField
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
    final rows = await adapter.select(
      QueryDescriptor(table: childTable, where: where),
    );
    final grouped = <Object?, List<Child>>{};
    for (final row in rows) {
      grouped
          .putIfAbsent(row[morphIdColumn], () => <Child>[])
          .add(hydrateChild(row));
    }
    return RelationLoadResult<Parent>(
      setOnParent: (parent) {
        parent.relations[name] = grouped[parent.id] ?? const <Object>[];
      },
      stats: const LoadStats(queriesExecuted: 1),
    );
  }
}
