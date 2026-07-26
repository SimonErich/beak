/// Immutable descriptor for DDL schema operations.
library;

import '../schema/column_type.dart';
import '../schema/on_delete.dart';

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
    this.foreignKeys = const <SchemaForeignKey>[],
    this.ifNotExists = false,
    this.ifExists = false,
  });

  /// Creates a table-creation descriptor.
  const SchemaDescriptor.createTable({
    required String table,
    List<SchemaColumn> columns = const <SchemaColumn>[],
    List<SchemaIndex> indexes = const <SchemaIndex>[],
    List<SchemaForeignKey> foreignKeys = const <SchemaForeignKey>[],
    bool ifNotExists = false,
  }) : this(
         table: table,
         operation: SchemaOperation.create,
         columns: columns,
         indexes: indexes,
         foreignKeys: foreignKeys,
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

  /// Foreign-key constraints for create/alter.
  ///
  /// Adapters that cannot express referential integrity (the in-memory one,
  /// Mongo) ignore these; SQL adapters render them as table constraints.
  final List<SchemaForeignKey> foreignKeys;

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
    if (foreignKeys.isNotEmpty)
      'foreignKeys': <Map<String, Object?>>[
        for (final key in foreignKeys) key.toMap(),
      ],
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

/// An abstract foreign-key constraint in a schema.
///
/// The adapter-neutral counterpart of the schema builder's
/// `ForeignKeyDefinition`: it carries what every SQL dialect needs to render
/// a constraint, and nothing dialect-specific.
final class SchemaForeignKey {
  /// Creates a [SchemaForeignKey].
  const SchemaForeignKey({
    required this.columns,
    required this.referencedTable,
    required this.referencedColumns,
    this.onDelete = OnDelete.restrict,
    this.name,
  });

  /// Local columns carrying the key, aligned with [referencedColumns].
  final List<String> columns;

  /// The parent table.
  final String referencedTable;

  /// Parent columns, aligned with [columns] by index.
  final List<String> referencedColumns;

  /// Referential action on parent deletion.
  final OnDelete onDelete;

  /// Explicit constraint name, when one was given.
  final String? name;

  /// Serializes to a map for golden snapshots.
  Map<String, Object?> toMap() => <String, Object?>{
    'columns': columns,
    'referencedTable': referencedTable,
    'referencedColumns': referencedColumns,
    'onDelete': onDelete.name,
    if (name != null) 'name': name,
  };
}
