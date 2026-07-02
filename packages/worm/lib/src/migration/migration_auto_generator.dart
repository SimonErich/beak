/// Generator for `worm make:migration --auto`.
///
/// Reads a target schema snapshot from `schema/schema.json`,
/// diffs it against the live database via [DiffEngine], and
/// renders a migration source file whose `upSchema(Schema)`
/// body uses the `Schema` facade to bring the live DB in line
/// with the target.
library;

import 'dart:convert';
import 'dart:io';

import '../adapter/database_adapter.dart';
import '../exception/migration_exception.dart';
import '../schema/column_type.dart';
import '../schema/table_schema.dart';
import 'diff_engine.dart';
import 'schema_diff.dart';

/// Generates migration source from a (target, live) schema diff.
final class MigrationAutoGenerator {
  /// Creates a [MigrationAutoGenerator].
  const MigrationAutoGenerator({
    required this.adapter,
    required this.projectRoot,
  });

  /// Adapter the generator introspects for the live schema.
  final DatabaseAdapter adapter;

  /// Project root containing `schema/schema.json`.
  final Directory projectRoot;

  /// Render the migration source for the diff between
  /// `schema/schema.json` and the live database.
  Future<String> generate({
    required String className,
    required String fileName,
  }) async {
    final target = await readTargetSchema();
    final live = await readLiveSchema();
    final diff = DiffEngine.diff(from: live, to: target);
    return _renderMigration(
      className: className,
      fileName: fileName,
      diff: diff,
      target: target,
    );
  }

  /// Parse `schema/schema.json` into [TableSchema]s.
  Future<List<TableSchema>> readTargetSchema() async {
    final file = File('${projectRoot.path}/schema/schema.json');
    if (!file.existsSync()) {
      throw MigrationException(
        migration: 'auto',
        message:
            'schema/schema.json not found at '
            '${file.path} — create one before running '
            'make:migration --auto.',
      );
    }
    final decoded = jsonDecode(await file.readAsString());
    return _parseSchema(decoded);
  }

  /// Introspect the live database. Column types are unknown at
  /// the adapter level, so each live column is reported as
  /// [ColumnType.text]; structural diffs (add/drop table or
  /// column) are unaffected.
  Future<List<TableSchema>> readLiveSchema() async {
    final raw = await adapter.introspectSchema();
    return <TableSchema>[
      for (final entry in raw.entries)
        TableSchema(
          name: entry.key,
          columns: <ColumnSnapshot>[
            for (final col in entry.value)
              ColumnSnapshot(name: col, type: ColumnType.text),
          ],
        ),
    ];
  }

  List<TableSchema> _parseSchema(Object? raw) {
    if (raw is! Map<String, Object?>) {
      throw const FormatException('schema.json root must be a JSON object');
    }
    final tables = raw['tables'];
    if (tables is! List) {
      throw const FormatException('schema.json must contain a "tables" array');
    }
    return <TableSchema>[for (final entry in tables) _parseTable(entry)];
  }

  TableSchema _parseTable(Object? raw) {
    if (raw is! Map<String, Object?>) {
      throw const FormatException('table entry must be a JSON object');
    }
    final name = raw['name'];
    final columns = raw['columns'];
    if (name is! String) {
      throw const FormatException('table entry missing string "name"');
    }
    if (columns is! List) {
      throw FormatException('table "$name" missing "columns" array');
    }
    return TableSchema(
      name: name,
      columns: <ColumnSnapshot>[for (final c in columns) _parseColumn(c)],
    );
  }

  ColumnSnapshot _parseColumn(Object? raw) {
    if (raw is! Map<String, Object?>) {
      throw const FormatException('column entry must be a JSON object');
    }
    final name = raw['name'];
    final type = raw['type'];
    final nullable = raw['nullable'];
    final isPk = raw['isPrimaryKey'];
    if (name is! String) {
      throw const FormatException('column missing string "name"');
    }
    if (type is! String) {
      throw FormatException('column "$name" missing string "type"');
    }
    return ColumnSnapshot(
      name: name,
      type: _parseType(type),
      nullable: nullable is bool ? nullable : false,
      isPrimaryKey: isPk is bool ? isPk : false,
    );
  }

  ColumnType _parseType(String raw) {
    for (final value in ColumnType.values) {
      if (value.name == raw) return value;
    }
    throw FormatException('unknown ColumnType "$raw"');
  }

  String _renderMigration({
    required String className,
    required String fileName,
    required SchemaDiff diff,
    required List<TableSchema> target,
  }) {
    final targetByName = <String, TableSchema>{
      for (final t in target) t.name: t,
    };
    final addedTables = <String>{
      for (final c in diff.changes)
        if (c.kind == SchemaChangeKind.addTable) c.table,
    };
    final body = StringBuffer();
    for (final change in diff.changes) {
      _renderChange(body, change, targetByName, addedTables);
    }
    final droppedTables = <String>[
      for (final c in diff.changes)
        if (c.kind == SchemaChangeKind.dropTable) c.table,
    ];
    final down = _renderDown(droppedTables, addedTables.toList());
    return _migrationSource(
      className: className,
      fileName: fileName,
      upBody: body.toString().trimRight(),
      downBody: down,
    );
  }

  void _renderChange(
    StringBuffer body,
    SchemaChange change,
    Map<String, TableSchema> targetByName,
    Set<String> addedTables,
  ) {
    switch (change.kind) {
      case SchemaChangeKind.addTable:
        final t = targetByName[change.table];
        if (t != null) body.writeln(_renderCreateTable(t));
      case SchemaChangeKind.addColumn:
        if (addedTables.contains(change.table)) return;
        body.writeln(_renderAddColumn(change));
      case SchemaChangeKind.dropColumn:
        body.writeln(_renderDropColumn(change));
      case SchemaChangeKind.dropTable:
        body.writeln("    await schema.drop('${change.table}');");
      case SchemaChangeKind.changeColumnType:
      case SchemaChangeKind.changeColumnNullable:
        body.writeln(
          '    // TODO: ${change.kind.name} on '
          '${change.table}.${change.column} requires manual review.',
        );
    }
  }

  String _renderCreateTable(TableSchema table) {
    final buffer = StringBuffer()
      ..writeln("    await schema.create('${table.name}', (table) {");
    for (final col in table.columns) {
      buffer.writeln('      ${_renderColumnCall(col)}');
    }
    buffer.write('    });');
    return buffer.toString();
  }

  String _renderAddColumn(SchemaChange change) {
    final column = change.column;
    final type = change.newType;
    if (column == null || type == null) {
      throw StateError(
        'DiffEngine emitted an addColumn SchemaChange for '
        '"${change.table}" without a column name or type; '
        'this is a logic error in DiffEngine.',
      );
    }
    final snap = ColumnSnapshot(
      name: column,
      type: type,
      nullable: change.newNullable ?? false,
    );
    final buffer = StringBuffer()
      ..writeln("    await schema.alter('${change.table}', (table) {")
      ..writeln('      ${_renderColumnCall(snap)}')
      ..write('    });');
    return buffer.toString();
  }

  String _renderDropColumn(SchemaChange change) {
    final column = change.column;
    if (column == null) {
      throw StateError(
        'DiffEngine emitted a dropColumn SchemaChange for '
        '"${change.table}" without a column name; this is a '
        'logic error in DiffEngine.',
      );
    }
    final buffer = StringBuffer()
      ..writeln("    await schema.alter('${change.table}', (table) {")
      ..writeln("      table.dropColumn('$column');")
      ..write('    });');
    return buffer.toString();
  }

  String _renderColumnCall(ColumnSnapshot col) {
    final method = _columnMethod(col.type);
    final chain = StringBuffer("table.$method('${col.name}')");
    if (col.isPrimaryKey) chain.write('..primary()');
    if (col.nullable && !col.isPrimaryKey) chain.write('..makeNullable()');
    chain.write(';');
    return chain.toString();
  }

  String _renderDown(List<String> droppedTables, List<String> addedTables) {
    final buffer = StringBuffer();
    for (final t in droppedTables) {
      buffer.writeln('    // TODO: $t was dropped — recreate it here.');
    }
    for (final t in addedTables) {
      buffer.writeln("    await schema.drop('$t', ifExists: true);");
    }
    return buffer.toString().trimRight();
  }

  String _migrationSource({
    required String className,
    required String fileName,
    required String upBody,
    required String downBody,
  }) {
    final up = upBody.isEmpty ? '    // No schema changes detected.' : upBody;
    final down = downBody.isEmpty ? '    // No-op.' : downBody;
    return '''
import 'package:worm/worm.dart';

/// Generated by `worm make:migration --auto`.
final class $className extends Migration {
  /// Default constructor.
  const $className();

  @override
  String get name => '$fileName';

  @override
  Future<void> upSchema(Schema schema) async {
$up
  }

  @override
  Future<void> downSchema(Schema schema) async {
$down
  }
}
''';
  }

  String _columnMethod(ColumnType type) => switch (type) {
    ColumnType.string => 'string',
    ColumnType.smallInteger => 'smallInteger',
    ColumnType.integer => 'integer',
    ColumnType.bigInteger => 'bigInteger',
    ColumnType.decimal => 'decimal',
    ColumnType.boolean => 'boolean',
    ColumnType.date => 'date',
    ColumnType.dateTime => 'dateTime',
    ColumnType.uuid => 'uuid',
    ColumnType.json => 'json',
    ColumnType.jsonb => 'jsonb',
    ColumnType.text => 'text',
    ColumnType.binary => 'binary',
    ColumnType.doublePrecision => 'doublePrecision',
    ColumnType.tsvector => 'tsvector',
    ColumnType.time => 'time',
    ColumnType.interval => 'interval',
    ColumnType.inet => 'inet',
    ColumnType.macaddr => 'macaddr',
    ColumnType.point => 'point',
    ColumnType.line => 'line',
    ColumnType.box => 'box',
    ColumnType.money => 'money',
    ColumnType.bit => 'bit',
    ColumnType.xml => 'xml',
    ColumnType.enumType => 'text',
    ColumnType.array => 'text',
  };
}
