/// Immutable descriptor for DDL schema operations.
library;

import '../schema/column_type.dart';

/// The type of schema operation.
enum SchemaOperation {
  /// Create a new table.
  create,

  /// Drop an existing table.
  drop,

  /// Alter an existing table.
  alter,

  /// Truncate all rows from a table.
  truncate,

  /// Create an index on a column. Carried by
  /// `SchemaIndexDescriptor` from `schema/`.
  createIndex,
}

/// Describes a DDL schema operation without any
/// database-specific syntax.
///
/// Declared `base` so adapter-specific descriptors (e.g.
/// `SchemaIndexDescriptor`) can extend it.
base class SchemaDescriptor {
  /// Creates a [SchemaDescriptor].
  const SchemaDescriptor({
    required this.table,
    required this.operation,
    this.columns = const <SchemaColumn>[],
    this.indexes = const <SchemaIndex>[],
    this.ifNotExists = false,
    this.ifExists = false,
  });

  /// Creates a table-creation descriptor.
  const SchemaDescriptor.createTable({
    required String table,
    List<SchemaColumn> columns = const <SchemaColumn>[],
    List<SchemaIndex> indexes = const <SchemaIndex>[],
    bool ifNotExists = false,
  }) : this(
         table: table,
         operation: SchemaOperation.create,
         columns: columns,
         indexes: indexes,
         ifNotExists: ifNotExists,
       );

  /// Creates a table-drop descriptor.
  const SchemaDescriptor.dropTable({
    required String table,
    bool ifExists = false,
  }) : this(table: table, operation: SchemaOperation.drop, ifExists: ifExists);

  /// Creates a truncate descriptor.
  const SchemaDescriptor.truncateTable({required String table})
    : this(table: table, operation: SchemaOperation.truncate);

  /// The target table name.
  final String table;

  /// The DDL operation to perform.
  final SchemaOperation operation;

  /// Column definitions for create/alter.
  final List<SchemaColumn> columns;

  /// Index definitions for create/alter.
  final List<SchemaIndex> indexes;

  /// Whether `IF NOT EXISTS` semantics apply.
  final bool ifNotExists;

  /// Whether `IF EXISTS` semantics apply.
  final bool ifExists;

  /// Serializes to a map for golden snapshots.
  Map<String, Object?> toMap() => <String, Object?>{
    'type': 'schema',
    'table': table,
    'operation': operation.name,
    if (columns.isNotEmpty)
      'columns': <Map<String, Object?>>[for (final col in columns) col.toMap()],
    if (indexes.isNotEmpty)
      'indexes': <Map<String, Object?>>[for (final idx in indexes) idx.toMap()],
  };
}

/// An abstract column definition in a schema.
final class SchemaColumn {
  /// Creates a [SchemaColumn].
  const SchemaColumn({
    required this.name,
    required this.type,
    this.nullable = false,
    this.defaultValue,
    this.isPrimaryKey = false,
  });

  /// The column name.
  final String name;

  /// The abstract column type.
  final ColumnType type;

  /// Whether the column allows NULL.
  final bool nullable;

  /// Default value expression.
  final Object? defaultValue;

  /// Whether this column is the primary key.
  final bool isPrimaryKey;

  /// Serializes to a map for golden snapshots.
  Map<String, Object?> toMap() => <String, Object?>{
    'name': name,
    'type': type.name,
    if (nullable) 'nullable': nullable,
    if (defaultValue != null) 'defaultValue': defaultValue,
    if (isPrimaryKey) 'isPrimaryKey': isPrimaryKey,
  };
}

/// An abstract index definition in a schema.
final class SchemaIndex {
  /// Creates a [SchemaIndex].
  const SchemaIndex({
    required this.name,
    required this.columns,
    this.unique = false,
  });

  /// The index name.
  final String name;

  /// Columns included in the index.
  final List<String> columns;

  /// Whether the index enforces uniqueness.
  final bool unique;

  /// Serializes to a map for golden snapshots.
  Map<String, Object?> toMap() => <String, Object?>{
    'name': name,
    'columns': columns,
    if (unique) 'unique': unique,
  };
}
