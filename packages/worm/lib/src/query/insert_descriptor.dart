/// Immutable descriptors for INSERT operations.
library;

/// Describes a single-row INSERT.
final class InsertDescriptor {
  /// Creates an [InsertDescriptor].
  const InsertDescriptor({
    required this.table,
    required this.values,
    this.returning,
  });

  /// Target table name.
  final String table;

  /// Column-value pairs to insert.
  final Map<String, Object?> values;

  /// Columns to return. `null` returns all columns.
  final List<String>? returning;

  /// Serializes to a map for golden snapshots.
  Map<String, Object?> toMap() => <String, Object?>{
    'type': 'insert',
    'table': table,
    'values': values,
    if (returning != null) 'returning': returning,
  };
}

/// Describes a multi-row INSERT.
final class InsertManyDescriptor {
  /// Creates an [InsertManyDescriptor].
  const InsertManyDescriptor({
    required this.table,
    required this.rows,
    this.returning,
  });

  /// Target table name.
  final String table;

  /// Rows to insert as column-value maps.
  final List<Map<String, Object?>> rows;

  /// Columns to return. `null` returns all columns.
  final List<String>? returning;

  /// Serializes to a map for golden snapshots.
  Map<String, Object?> toMap() => <String, Object?>{
    'type': 'insertMany',
    'table': table,
    'rows': rows,
    if (returning != null) 'returning': returning,
  };
}
