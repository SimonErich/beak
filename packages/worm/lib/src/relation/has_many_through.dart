/// HasManyThrough relationship (parent → through →
/// many final children via two foreign-key hops).
library;

import '../adapter/database_adapter.dart';
import '../model/model.dart';
import '../query/field.dart';
import '../query/field_operators.dart';
import '../query/query_descriptor.dart';
import 'relation_base.dart';

/// A `HasManyThrough` relationship.
///
/// Eager loading executes exactly two queries: one
/// to fetch the through-table rows for the parents,
/// then one to fetch every child row referencing
/// those through-rows.
final class HasManyThroughRelation<Parent extends Model, Child extends Model>
    extends Relation<Parent, Child> {
  /// Creates a [HasManyThroughRelation].
  const HasManyThroughRelation({
    required super.name,
    required this.throughTable,
    required this.childTable,
    required this.firstKey,
    required this.secondKey,
    required this.hydrateChild,
    this.localKey = 'id',
    this.throughKey = 'id',
  });

  /// Intermediate (through) table.
  final String throughTable;

  /// Final child table.
  final String childTable;

  /// FK on the through table referencing the parent.
  final String firstKey;

  /// FK on the child table referencing the through.
  final String secondKey;

  /// Parent-side primary-key column.
  final String localKey;

  /// Primary-key column on the through table.
  final String throughKey;

  /// Hydrator turning a raw child row into [Child].
  final Child Function(Map<String, Object?>) hydrateChild;

  @override
  String get targetTable => childTable;

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
    final firstField = Field<Object?>(firstKey);
    final throughRows = await adapter.select(
      QueryDescriptor(table: throughTable, where: firstField.inList(parentIds)),
    );
    final throughToParent = <Object?, Object?>{
      for (final row in throughRows) row[throughKey]: row[firstKey],
    };
    final throughIds = throughToParent.keys.whereType<Object>().toList();
    final childRows = throughIds.isEmpty
        ? const <Map<String, Object?>>[]
        : await adapter.select(
            QueryDescriptor(
              table: childTable,
              where: Field<Object?>(secondKey).inList(throughIds),
            ),
          );
    final grouped = <Object?, List<Child>>{};
    for (final row in childRows) {
      final parentId = throughToParent[row[secondKey]];
      grouped.putIfAbsent(parentId, () => <Child>[]).add(hydrateChild(row));
    }
    return RelationLoadResult<Parent>(
      setOnParent: (parent) {
        parent.relations[name] = grouped[parent.id] ?? const <Object>[];
      },
      stats: const LoadStats(queriesExecuted: 2),
    );
  }
}
