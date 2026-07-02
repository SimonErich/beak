/// Foreign key definition used by the schema builder.
library;

import 'on_delete.dart';

/// A foreign key constraint produced by the schema builder.
///
/// Holds the local [columns] and the matching [referencedColumns]
/// on [referencedTable]. Single-column FKs (the common case) are
/// declared via the default constructor; composite (multi-column)
/// FKs use [ForeignKeyDefinition.composite].
final class ForeignKeyDefinition {
  /// Creates a single-column [ForeignKeyDefinition].
  ///
  /// Sugar over [ForeignKeyDefinition.composite] for the common
  /// one-column case. Not `const` because the list initializers
  /// wrap parameter values; use [ForeignKeyDefinition.composite]
  /// with literal lists when a const instance is required.
  ForeignKeyDefinition({
    required String column,
    required this.referencedTable,
    required String referencedColumn,
    this.onDelete = OnDelete.restrict,
    this.name,
  }) : columns = <String>[column],
       referencedColumns = <String>[referencedColumn];

  /// Creates a composite (multi-column) [ForeignKeyDefinition].
  ///
  /// [columns] and [referencedColumns] must have equal length —
  /// the i-th local column references the i-th remote column.
  const ForeignKeyDefinition.composite({
    required this.columns,
    required this.referencedTable,
    required this.referencedColumns,
    this.onDelete = OnDelete.restrict,
    this.name,
  });

  /// Local columns carrying the foreign key (one entry for a
  /// single-column FK, N entries for a composite FK).
  final List<String> columns;

  /// Referenced parent table.
  final String referencedTable;

  /// Referenced columns on the parent table, aligned with
  /// [columns] by index.
  final List<String> referencedColumns;

  /// Referential action on parent deletion.
  final OnDelete onDelete;

  /// Optional explicit constraint name.
  final String? name;

  /// Serializes the foreign key to a plain map.
  Map<String, Object?> toMap() => <String, Object?>{
    'columns': columns,
    'referencedTable': referencedTable,
    'referencedColumns': referencedColumns,
    'onDelete': onDelete.name,
    if (name != null) 'name': name,
  };
}
