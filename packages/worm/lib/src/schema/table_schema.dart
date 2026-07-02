/// Snapshot of a table schema used by the diff engine.
library;

import 'column_type.dart';

/// Snapshot of a single column in a [TableSchema].
final class ColumnSnapshot {
  /// Creates a [ColumnSnapshot].
  const ColumnSnapshot({
    required this.name,
    required this.type,
    this.nullable = false,
    this.isPrimaryKey = false,
  });

  /// Column name.
  final String name;

  /// Abstract column type.
  final ColumnType type;

  /// Whether the column allows `NULL`.
  final bool nullable;

  /// Whether the column is the primary key.
  final bool isPrimaryKey;

  /// Serializes the snapshot to a plain map.
  Map<String, Object?> toMap() => <String, Object?>{
    'name': name,
    'type': type.name,
    'nullable': nullable,
    if (isPrimaryKey) 'isPrimaryKey': true,
  };
}

/// An immutable snapshot of a table's columns.
final class TableSchema {
  /// Creates a [TableSchema].
  const TableSchema({required this.name, required this.columns});

  /// Table name.
  final String name;

  /// Columns in declaration order.
  final List<ColumnSnapshot> columns;

  /// Looks up a column by [columnName], or `null`.
  ColumnSnapshot? column(String columnName) {
    for (final c in columns) {
      if (c.name == columnName) return c;
    }
    return null;
  }

  /// Serializes the table schema to a plain map.
  Map<String, Object?> toMap() => <String, Object?>{
    'name': name,
    'columns': <Map<String, Object?>>[for (final c in columns) c.toMap()],
  };
}
