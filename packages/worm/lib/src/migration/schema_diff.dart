/// Result types produced by the schema diff engine.
library;

import '../schema/column_type.dart';
import '../schema/table_schema.dart';

/// Kind of change detected by the schema diff engine.
enum SchemaChangeKind {
  /// A new table was declared.
  addTable,

  /// A table was removed.
  dropTable,

  /// A new column was added.
  addColumn,

  /// A column was removed.
  dropColumn,

  /// A column's type changed.
  changeColumnType,

  /// A column's nullability changed.
  changeColumnNullable,
}

/// A single change between two schemas.
final class SchemaChange {
  /// Creates a [SchemaChange].
  const SchemaChange({
    required this.kind,
    required this.table,
    this.column,
    this.previousType,
    this.newType,
    this.previousNullable,
    this.newNullable,
    this.destructive = false,
  });

  /// The kind of change.
  final SchemaChangeKind kind;

  /// The affected table.
  final String table;

  /// Affected column, when applicable.
  final String? column;

  /// Previous column type, when applicable.
  final ColumnType? previousType;

  /// New column type, when applicable.
  final ColumnType? newType;

  /// Previous nullable flag, when applicable.
  final bool? previousNullable;

  /// New nullable flag, when applicable.
  final bool? newNullable;

  /// Whether the change loses data.
  final bool destructive;

  /// Serializes the change to a plain map.
  Map<String, Object?> toMap() => <String, Object?>{
    'kind': kind.name,
    'table': table,
    if (column != null) 'column': column,
    if (previousType != null) 'previousType': previousType?.name,
    if (newType != null) 'newType': newType?.name,
    if (previousNullable != null) 'previousNullable': previousNullable,
    if (newNullable != null) 'newNullable': newNullable,
    if (destructive) 'destructive': true,
  };
}

/// Aggregated changes between two schemas.
final class SchemaDiff {
  /// Creates a [SchemaDiff].
  const SchemaDiff(this.changes);

  /// Empty diff.
  const SchemaDiff.empty() : changes = const <SchemaChange>[];

  /// Detected changes in declaration order.
  final List<SchemaChange> changes;

  /// Whether any destructive change exists.
  bool get hasDestructive => changes.any((c) => c.destructive);

  /// Whether the diff is empty.
  bool get isEmpty => changes.isEmpty;

  /// Returns the subset of changes that are destructive.
  List<SchemaChange> get destructiveChanges => <SchemaChange>[
    for (final c in changes)
      if (c.destructive) c,
  ];

  /// Convenience: list of table snapshot pairs for printing.
  List<TableSchema> tablesIn(SchemaChangeKind kind) => <TableSchema>[];
}
