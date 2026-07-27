/// Immutable descriptor for DDL schema operations.
library;

import '../schema/column_type.dart';
import '../schema/index_definition.dart';
import '../schema/on_delete.dart';

/// The type of schema operation.
enum SchemaOperation {
  /// Create a new table.
  create,

  /// Drop an existing table.
  drop,

  /// Alter an existing table, applying [SchemaDescriptor.alterations] in order.
  alter,

  /// Truncate all rows from a table.
  truncate,
}

/// Describes a DDL schema operation without any
/// database-specific syntax.
final class SchemaDescriptor {
  /// Creates a [SchemaDescriptor].
  const SchemaDescriptor({
    required this.table,
    required this.operation,
    this.columns = const <SchemaColumn>[],
    this.indexes = const <SchemaIndex>[],
    this.foreignKeys = const <SchemaForeignKey>[],
    this.alterations = const <SchemaAlteration>[],
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

  /// Creates a table-alteration descriptor applying [alterations] in order.
  const SchemaDescriptor.alterTable({
    required String table,
    required List<SchemaAlteration> alterations,
  }) : this(
         table: table,
         operation: SchemaOperation.alter,
         alterations: alterations,
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

  /// Column definitions for a create.
  final List<SchemaColumn> columns;

  /// Index definitions for a create.
  ///
  /// A unique index becomes an inline table constraint; the rest become
  /// `CREATE INDEX` statements alongside the `CREATE TABLE`.
  final List<SchemaIndex> indexes;

  /// Foreign-key constraints for a create.
  ///
  /// Adapters that cannot express referential integrity (the in-memory one,
  /// Mongo) ignore these; SQL adapters render them as table constraints.
  final List<SchemaForeignKey> foreignKeys;

  /// The ordered steps of an alter, empty for every other operation.
  ///
  /// Order is semantic and preserved exactly: an index must be dropped before
  /// the column it covers, and a column must exist before an index can cover
  /// it. A compiler that reordered these would be wrong for some input.
  final List<SchemaAlteration> alterations;

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
    if (alterations.isNotEmpty)
      'alterations': <Map<String, Object?>>[
        for (final alteration in alterations) alteration.toMap(),
      ],
  };
}

/// One ordered step of an `ALTER TABLE`.
///
/// Sealed on purpose: adding a step that some dialect cannot render must be a
/// compile error in every compiler, not a field they quietly ignore. A
/// non-unique index was dropped on the floor for exactly that reason before
/// this type existed.
///
/// A step a dialect genuinely cannot express throws
/// `UnsupportedOperationException` naming the limitation — never silence.
sealed class SchemaAlteration {
  /// Enables `const` construction by subclasses.
  const SchemaAlteration();

  /// Serializes to a map for golden snapshots.
  Map<String, Object?> toMap();
}

/// Adds a column to an existing table.
final class SchemaAddColumn extends SchemaAlteration {
  /// Adds [column].
  const SchemaAddColumn(this.column, {this.ifNotExists = false});

  /// The column to add.
  final SchemaColumn column;

  /// Whether to tolerate the column already existing.
  ///
  /// Postgres supports this; SQLite and MySQL do not and reject the request
  /// rather than pretend.
  final bool ifNotExists;

  @override
  Map<String, Object?> toMap() => <String, Object?>{
    'alteration': 'addColumn',
    'column': column.toMap(),
    if (ifNotExists) 'ifNotExists': true,
  };
}

/// Removes a column from an existing table.
final class SchemaDropColumn extends SchemaAlteration {
  /// Drops the column named [column].
  const SchemaDropColumn(this.column, {this.ifExists = false});

  /// The column name to drop.
  final String column;

  /// Whether to tolerate the column being absent.
  final bool ifExists;

  @override
  Map<String, Object?> toMap() => <String, Object?>{
    'alteration': 'dropColumn',
    'column': column,
    if (ifExists) 'ifExists': true,
  };
}

/// The facets of a column an alteration may touch.
enum SchemaColumnFacet {
  /// The stored type.
  type,

  /// Whether `NULL` is accepted.
  nullability,

  /// The column default.
  defaultValue,
}

/// Changes an existing column's type, nullability or default.
final class SchemaChangeColumn extends SchemaAlteration {
  /// Changes [column] to its declared end state.
  const SchemaChangeColumn(this.column, {this.facets = allFacets, this.using});

  /// Every facet, the default.
  static const Set<SchemaColumnFacet> allFacets = <SchemaColumnFacet>{
    SchemaColumnFacet.type,
    SchemaColumnFacet.nullability,
    SchemaColumnFacet.defaultValue,
  };

  /// The column's complete desired end state, never a delta.
  ///
  /// MySQL's `MODIFY COLUMN` restates the whole definition and has no way to
  /// express a partial change, so a delta could not be compiled there at all.
  final SchemaColumn column;

  /// Which facets to emit.
  ///
  /// A Postgres refinement — it can alter type, nullability and default
  /// independently. MySQL restates everything regardless.
  final Set<SchemaColumnFacet> facets;

  /// The Postgres `USING` cast expression, when the default cast will not do.
  final String? using;

  @override
  Map<String, Object?> toMap() => <String, Object?>{
    'alteration': 'changeColumn',
    'column': column.toMap(),
    if (facets.length != allFacets.length)
      'facets': <String>[
        for (final facet in SchemaColumnFacet.values)
          if (facets.contains(facet)) facet.name,
      ],
    if (using != null) 'using': using,
  };
}

/// Creates an index on an existing table.
final class SchemaAddIndex extends SchemaAlteration {
  /// Creates [index].
  const SchemaAddIndex(this.index, {this.ifNotExists = false});

  /// The index to create.
  final SchemaIndex index;

  /// Whether to tolerate the index already existing.
  final bool ifNotExists;

  @override
  Map<String, Object?> toMap() => <String, Object?>{
    'alteration': 'addIndex',
    'index': index.toMap(),
    if (ifNotExists) 'ifNotExists': true,
  };
}

/// Drops an index from an existing table.
final class SchemaDropIndex extends SchemaAlteration {
  /// Drops the index named [name].
  const SchemaDropIndex(this.name, {this.ifExists = false});

  /// The index name.
  final String name;

  /// Whether to tolerate the index being absent.
  final bool ifExists;

  @override
  Map<String, Object?> toMap() => <String, Object?>{
    'alteration': 'dropIndex',
    'name': name,
    if (ifExists) 'ifExists': true,
  };
}

/// Adds a foreign-key constraint to an existing table.
final class SchemaAddForeignKey extends SchemaAlteration {
  /// Adds [foreignKey].
  const SchemaAddForeignKey(this.foreignKey);

  /// The constraint to add.
  final SchemaForeignKey foreignKey;

  @override
  Map<String, Object?> toMap() => <String, Object?>{
    'alteration': 'addForeignKey',
    'foreignKey': foreignKey.toMap(),
  };
}

/// Drops a foreign-key constraint from an existing table.
final class SchemaDropForeignKey extends SchemaAlteration {
  /// Drops the constraint named [name].
  const SchemaDropForeignKey(this.name);

  /// The constraint name.
  final String name;

  @override
  Map<String, Object?> toMap() => <String, Object?>{
    'alteration': 'dropForeignKey',
    'name': name,
  };
}

/// An abstract column definition in a schema.
///
/// Carries everything a dialect needs to render the column, including the
/// sizing a `VARCHAR(120)` or a `DECIMAL(10,2)` depends on. A field the
/// descriptor drops is a field the database never sees.
final class SchemaColumn {
  /// Creates a [SchemaColumn].
  const SchemaColumn({
    required this.name,
    required this.type,
    this.nullable = false,
    this.defaultValue,
    this.isPrimaryKey = false,
    this.length,
    this.precision,
    this.scale,
    this.elementType,
    this.autoIncrement = false,
    this.unique = false,
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

  /// Declared length, for a string or binary column.
  final int? length;

  /// Declared precision, for a decimal column.
  final int? precision;

  /// Declared scale, for a decimal column.
  final int? scale;

  /// The element type, when [type] is [ColumnType.array].
  final ColumnType? elementType;

  /// Whether the database assigns the value on insert.
  final bool autoIncrement;

  /// Whether this single column carries a unique constraint.
  final bool unique;

  /// Serializes to a map for golden snapshots.
  Map<String, Object?> toMap() => <String, Object?>{
    'name': name,
    'type': type.name,
    if (nullable) 'nullable': nullable,
    if (defaultValue != null) 'defaultValue': defaultValue,
    if (isPrimaryKey) 'isPrimaryKey': isPrimaryKey,
    if (length != null) 'length': length,
    if (precision != null) 'precision': precision,
    if (scale != null) 'scale': scale,
    if (elementType != null) 'elementType': elementType?.name,
    if (autoIncrement) 'autoIncrement': autoIncrement,
    if (unique) 'unique': unique,
  };
}

/// An abstract index definition in a schema.
final class SchemaIndex {
  /// Creates a [SchemaIndex].
  const SchemaIndex({
    required this.name,
    required this.columns,
    this.unique = false,
    this.kind = IndexKind.btree,
    this.where,
  });

  /// The index name.
  final String name;

  /// Columns included in the index.
  final List<String> columns;

  /// Whether the index enforces uniqueness.
  final bool unique;

  /// The storage strategy.
  ///
  /// Only Postgres renders anything but [IndexKind.btree]; the others reject
  /// a request they cannot honour rather than silently building a b-tree.
  final IndexKind kind;

  /// The predicate of a partial index, when it has one.
  final String? where;

  /// Serializes to a map for golden snapshots.
  Map<String, Object?> toMap() => <String, Object?>{
    'name': name,
    'columns': columns,
    if (unique) 'unique': unique,
    if (kind != IndexKind.btree) 'kind': kind.name,
    if (where != null) 'where': where,
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
