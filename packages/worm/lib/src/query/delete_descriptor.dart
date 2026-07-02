/// Immutable descriptor for DELETE operations.
library;

import 'predicate_tree.dart';

/// Describes a DELETE without database-specific
/// syntax.
final class DeleteDescriptor {
  /// Creates a [DeleteDescriptor].
  const DeleteDescriptor({required this.table, this.where});

  /// Target table name.
  final String table;

  /// Optional WHERE predicate tree.
  final PredicateTree? where;

  /// Serializes to a map for golden snapshots.
  Map<String, Object?> toMap() => <String, Object?>{
    'type': 'delete',
    'table': table,
    if (where != null) 'where': where!.toMap(),
  };
}
