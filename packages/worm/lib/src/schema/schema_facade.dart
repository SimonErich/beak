/// User-facing schema facade used inside migrations.
library;

import 'package:meta/meta.dart';

import '../adapter/database_adapter.dart';
import '../query/schema_descriptor.dart';
import 'blueprint.dart';
import 'column_definition.dart';

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

  SchemaDescriptor _toCreateDescriptor(Blueprint blueprint) =>
      SchemaDescriptor.createTable(
        table: blueprint.tableName,
        columns: _toSchemaColumns(blueprint.table.columns),
      );

  SchemaDescriptor _toAlterDescriptor(Blueprint blueprint) => SchemaDescriptor(
    table: blueprint.tableName,
    operation: SchemaOperation.alter,
    columns: _toSchemaColumns(blueprint.table.columns),
  );

  List<SchemaColumn> _toSchemaColumns(List<ColumnDefinition> columns) =>
      <SchemaColumn>[
        for (final col in columns)
          SchemaColumn(
            name: col.name,
            type: col.type,
            nullable: col.nullable,
            isPrimaryKey: col.isPrimaryKey,
            defaultValue: col.defaultValue,
          ),
      ];
}
