/// Immutable descriptor for UPDATE operations.
library;

import 'predicate_tree.dart';

/// Describes an UPDATE without database-specific
/// syntax.
final class UpdateDescriptor {
  /// Creates an [UpdateDescriptor].
  const UpdateDescriptor({
    required this.table,
    required this.values,
    this.where,
  });

  /// Target table name.
  final String table;

  /// Column-value pairs to update.
  final Map<String, Object?> values;

  /// Optional WHERE predicate tree.
  final PredicateTree? where;

  /// Serializes to a map for golden snapshots.
  Map<String, Object?> toMap() => <String, Object?>{
    'type': 'update',
    'table': table,
    'values': values,
    if (where != null) 'where': where!.toMap(),
  };
}
