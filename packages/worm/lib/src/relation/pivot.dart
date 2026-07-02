/// Pivot operations for many-to-many relations.
library;

import '../adapter/database_adapter.dart';
import '../query/delete_descriptor.dart';
import '../query/field.dart';
import '../query/field_operators.dart';
import '../query/insert_descriptor.dart';
import '../query/query_descriptor.dart';
import 'belongs_to_many.dart';

/// Manager exposing `attach` / `detach` / `sync` on
/// the pivot table of a [BelongsToManyRelation].
final class PivotManager {
  /// Creates a [PivotManager].
  const PivotManager({
    required this.adapter,
    required this.pivotTable,
    required this.parentPivotKey,
    required this.relatedPivotKey,
    required this.parentId,
  });

  /// Adapter executing the operations.
  final DatabaseAdapter adapter;

  /// Snake_case pivot table.
  final String pivotTable;

  /// Column on the pivot referencing the parent.
  final String parentPivotKey;

  /// Column on the pivot referencing the related
  /// row.
  final String relatedPivotKey;

  /// Parent primary-key value.
  final Object parentId;

  /// Inserts a pivot row linking this parent to
  /// [relatedId]. Optionally writes extra [pivotData]
  /// columns alongside the foreign keys.
  Future<void> attach(
    Object relatedId, {
    Map<String, Object?> pivotData = const <String, Object?>{},
  }) async {
    await adapter.insert(
      InsertDescriptor(
        table: pivotTable,
        values: <String, Object?>{
          parentPivotKey: parentId,
          relatedPivotKey: relatedId,
          ...pivotData,
        },
      ),
    );
  }

  /// Removes pivot rows linking this parent to
  /// [relatedId]. Returns the number of rows
  /// removed.
  Future<int> detach(Object relatedId) async {
    final parentField = Field<Object?>(parentPivotKey);
    final relatedField = Field<Object?>(relatedPivotKey);
    return adapter.delete(
      DeleteDescriptor(
        table: pivotTable,
        where: parentField.eq(parentId).and(relatedField.eq(relatedId)),
      ),
    );
  }

  /// Replaces this parent's pivot rows so they
  /// reference exactly [relatedIds].
  ///
  /// Returns a [PivotSyncResult] describing which
  /// pivot rows were attached or detached.
  Future<PivotSyncResult> sync(List<Object> relatedIds) async {
    final existing = await _currentRelatedIds();
    final desired = relatedIds.toSet();
    final toDetach = existing.difference(desired);
    final toAttach = desired.difference(existing);
    for (final id in toDetach) {
      await detach(id);
    }
    for (final id in toAttach) {
      await attach(id);
    }
    return PivotSyncResult(
      attached: toAttach.toList(),
      detached: toDetach.toList(),
    );
  }

  Future<Set<Object>> _currentRelatedIds() async {
    final field = Field<Object?>(parentPivotKey);
    final where = field.eq(parentId);
    final rows = await adapter.select(
      QueryDescriptor(table: pivotTable, where: where),
    );
    return <Object>{
      for (final row in rows)
        if (row[relatedPivotKey] case final Object id) id,
    };
  }
}

/// Result of [PivotManager.sync].
final class PivotSyncResult {
  /// Creates a [PivotSyncResult].
  const PivotSyncResult({required this.attached, required this.detached});

  /// IDs newly inserted into the pivot table.
  final List<Object> attached;

  /// IDs removed from the pivot table.
  final List<Object> detached;
}
