/// User-facing schema facade used inside migrations.
library;

import 'package:meta/meta.dart';

import '../adapter/database_adapter.dart';
import '../exception/schema_definition_exception.dart';
import '../query/schema_descriptor.dart';
import 'blueprint.dart';
import 'column_definition.dart';
import 'foreign_key_definition.dart';
import 'index_definition.dart';

/// Fluent schema facade exposed to `Migration.upSchema` and
/// `Migration.downSchema`.
///
/// Wraps a [DatabaseAdapter] and translates fluent
/// `create` / `alter` / `drop` calls into
/// [DatabaseAdapter.executeSchema] descriptor invocations.
///
/// Construction is library-private: users receive a [Schema]
/// instance from `MigrationRunner` via the migration's
/// `upSchema(Schema)` / `downSchema(Schema)` overrides. To
/// instantiate one in trusted internal code (the runner), use
/// [Schema.forRunner], which simply redirects to the private
/// canonical constructor `Schema._(adapter)`.
final class Schema {
  /// Canonical, library-private constructor.
  const Schema._(this._adapter);

  /// Internal redirector used by `MigrationRunner` only.
  ///
  /// Marked [internal] so user code that depends on `worm`
  /// triggers a `library_private_types_in_public_api`-style
  /// analyzer warning if it calls this directly. Library code
  /// (the migration runner) reaches it without `as` casts.
  @internal
  const Schema.forRunner(DatabaseAdapter adapter) : this._(adapter);

  final DatabaseAdapter _adapter;

  /// The wrapped adapter.
  ///
  /// Power-user escape hatch — the base `Migration.upSchema`
  /// implementation reads it to forward to legacy `up(adapter)`
  /// overrides.
  DatabaseAdapter get adapter => _adapter;

  /// Create a new table named [tableName] using [build] to
  /// declare its columns.
  ///
  /// Forwards to [DatabaseAdapter.executeSchema] with a
  /// [SchemaDescriptor.createTable] descriptor populated from
  /// the resulting [Blueprint].
  Future<void> create(
    String tableName,
    void Function(BlueprintTable table) build,
  ) {
    final blueprint = Blueprint.create(tableName, build);
    return _adapter.executeSchema(_toCreateDescriptor(blueprint));
  }

  /// Alter an existing table named [tableName].
  Future<void> alter(
    String tableName,
    void Function(BlueprintTable table) build,
  ) {
    final blueprint = Blueprint.alter(tableName, build);
    return _adapter.executeSchema(_toAlterDescriptor(blueprint));
  }

  /// Drop the table named [tableName].
  Future<void> drop(String tableName, {bool ifExists = false}) =>
      _adapter.executeSchema(
        SchemaDescriptor.dropTable(table: tableName, ifExists: ifExists),
      );

  SchemaDescriptor _toCreateDescriptor(Blueprint blueprint) {
    final table = blueprint.table;
    if (table.changedColumns.isNotEmpty) {
      throw SchemaDefinitionException(
        table: blueprint.tableName,
        operation: 'create',
        message:
            'change() marks a modification of an existing column and is only '
            'valid inside Schema.alter.',
      );
    }
    if (table.droppedColumns.isNotEmpty ||
        table.droppedIndexes.isNotEmpty ||
        table.droppedForeignKeys.isNotEmpty) {
      throw SchemaDefinitionException(
        table: blueprint.tableName,
        operation: 'create',
        message:
            'A table being created has nothing to drop; move the drop into a '
            'Schema.alter.',
      );
    }
    return SchemaDescriptor.createTable(
      table: blueprint.tableName,
      columns: _toSchemaColumns(table.columns),
      // A column-level unique constraint and a table-level unique index are
      // the same request; normalising here means the compilers see one shape.
      indexes: [
        ..._toSchemaIndexes(table.indexes),
        for (final column in table.columns)
          if (column.unique && !column.isPrimaryKey)
            SchemaIndex(
              name: '${blueprint.tableName}_${column.name}_key',
              columns: <String>[column.name],
              unique: true,
            ),
      ],
      foreignKeys: _toSchemaForeignKeys(table.foreignKeys),
    );
  }

  /// The alter descriptor, with steps in a canonical dependency order.
  ///
  /// Drops come before adds so an index never blocks the column it covers,
  /// and adds come before the indexes and constraints that reference them.
  /// Ordering here rather than recording call order makes the result
  /// deterministic and removes a class of user error — declaring `index()`
  /// before the `string()` it covers is no longer wrong.
  SchemaDescriptor _toAlterDescriptor(Blueprint blueprint) {
    final table = blueprint.table;
    final added = table.addedColumns;
    final duplicated = <String>{
      for (final column in added) column.name,
    }.intersection(table.droppedColumns.toSet());
    if (duplicated.isNotEmpty) {
      throw SchemaDefinitionException(
        table: blueprint.tableName,
        operation: 'alter',
        message:
            'Column${duplicated.length == 1 ? '' : 's'} '
            '"${duplicated.join('", "')}" '
            '${duplicated.length == 1 ? 'is' : 'are'} both dropped and added '
            'in one alter, which no ordering can make coherent. Use two '
            'migrations, or change() the column instead.',
      );
    }

    final alterations = <SchemaAlteration>[
      for (final name in table.droppedIndexes) SchemaDropIndex(name),
      for (final name in table.droppedForeignKeys) SchemaDropForeignKey(name),
      for (final name in table.droppedColumns) SchemaDropColumn(name),
      for (final column in added) SchemaAddColumn(_toSchemaColumn(column)),
      for (final column in table.changedColumns)
        SchemaChangeColumn(_toSchemaColumn(column)),
      for (final key in _toSchemaForeignKeys(table.foreignKeys))
        SchemaAddForeignKey(key),
      for (final index in _toSchemaIndexes(table.indexes))
        SchemaAddIndex(index),
      for (final column in added)
        if (column.unique && !column.isPrimaryKey)
          SchemaAddIndex(
            SchemaIndex(
              name: '${blueprint.tableName}_${column.name}_key',
              columns: <String>[column.name],
              unique: true,
            ),
          ),
    ];
    if (alterations.isEmpty) {
      throw SchemaDefinitionException(
        table: blueprint.tableName,
        operation: 'alter',
        message: 'An alter with no changes would send an empty statement.',
      );
    }
    return SchemaDescriptor.alterTable(
      table: blueprint.tableName,
      alterations: alterations,
    );
  }

  List<SchemaColumn> _toSchemaColumns(List<ColumnDefinition> columns) =>
      <SchemaColumn>[for (final col in columns) _toSchemaColumn(col)];

  /// Every field the builder recorded, carried through.
  ///
  /// Dropping one here means the database never sees it: a `VARCHAR(120)`
  /// silently became a bare `VARCHAR` for as long as this mapper omitted
  /// [ColumnDefinition.length].
  SchemaColumn _toSchemaColumn(ColumnDefinition col) => SchemaColumn(
    name: col.name,
    type: col.type,
    nullable: col.nullable,
    isPrimaryKey: col.isPrimaryKey,
    defaultValue: col.defaultValue,
    length: col.length,
    precision: col.precision,
    scale: col.scale,
    elementType: col.elementType,
    autoIncrement: col.autoIncrement,
    unique: col.unique,
  );

  List<SchemaIndex> _toSchemaIndexes(List<IndexDefinition> indexes) =>
      <SchemaIndex>[
        for (final index in indexes)
          SchemaIndex(
            name: index.name,
            columns: index.columns,
            unique: index.unique,
            kind: index.kind,
            where: index.partialWhere,
          ),
      ];

  List<SchemaForeignKey> _toSchemaForeignKeys(
    List<ForeignKeyDefinition> foreignKeys,
  ) => <SchemaForeignKey>[
    for (final key in foreignKeys)
      SchemaForeignKey(
        columns: key.columns,
        referencedTable: key.referencedTable,
        referencedColumns: key.referencedColumns,
        onDelete: key.onDelete,
        name: key.name,
      ),
  ];
}
