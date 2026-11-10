import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'generate_issue.dart';

/// One column of a table in the Serverpod migration.
final class DbColumn {
  /// Creates a column.
  const DbColumn({required this.name, required this.dartType});

  /// The physical column name.
  final String name;

  /// The Dart type Serverpod recorded (`UuidValue?`, `protocol:Mode`).
  final String dartType;
}

/// A foreign key of a table.
final class DbForeignKey {
  /// Creates a foreign key.
  const DbForeignKey({required this.columns, required this.referenceTable});

  /// The local columns.
  final List<String> columns;

  /// The table they point at.
  final String referenceTable;
}

/// An index of a table.
final class DbIndex {
  /// Creates an index.
  const DbIndex({
    required this.name,
    required this.columns,
    required this.isUnique,
  });

  /// The index name.
  final String name;

  /// The indexed columns, in order.
  final List<String> columns;

  /// Whether it enforces uniqueness.
  final bool isUnique;
}

/// One table of the migration, the physical truth about a model.
final class DbTable {
  /// Creates a table.
  const DbTable({
    required this.name,
    required this.columns,
    required this.foreignKeys,
    required this.indexes,
  });

  /// The table name.
  final String name;

  /// Its columns by name.
  final Map<String, DbColumn> columns;

  /// Its foreign keys.
  final List<DbForeignKey> foreignKeys;

  /// Its indexes.
  final List<DbIndex> indexes;
}

/// The database definition of the newest Serverpod migration.
///
/// It lists what is really in the database: every column, including the
/// foreign keys Serverpod invents for a one-sided relation (`_parentMain...Id`)
/// and the unique indexes the models declare.
final class DatabaseDefinition {
  /// Creates a definition from its [tables].
  const DatabaseDefinition(this.tables, {required this.source});

  /// The tables by name.
  final Map<String, DbTable> tables;

  /// The `definition_project.json` this was read from, relative to the
  /// server package.
  final String source;

  /// Reads the newest `*/definition_project.json` under [migrations].
  factory DatabaseDefinition.read(Directory serverRoot, String migrations) {
    final directory = Directory(p.join(serverRoot.path, migrations));
    final files = <File>[
      if (directory.existsSync())
        for (final entity in directory.listSync())
          if (entity is Directory &&
              File(p.join(entity.path, 'definition_project.json')).existsSync())
            File(p.join(entity.path, 'definition_project.json')),
    ]..sort((a, b) => a.path.compareTo(b.path));
    if (files.isEmpty) {
      throw BeakGenerateException.single(
        'beak.yaml',
        'serverpod.migrations ($migrations) holds no '
            '*/definition_project.json. Create a migration first with '
            '`serverpod create-migration`, so the generated schema can be '
            'checked against the real tables.',
      );
    }
    final String source = p.posix.joinAll(
      p.split(p.relative(files.last.path, from: serverRoot.path)),
    );
    final Object? json;
    try {
      json = jsonDecode(files.last.readAsStringSync());
    } on FormatException catch (error) {
      throw BeakGenerateException.single(
        source,
        'is not valid JSON: ${error.message}',
      );
    }
    final tables = <String, DbTable>{};
    if (json is Map<String, Object?>) {
      for (final raw in _maps(json['tables'])) {
        if (raw['name'] case final String name) {
          tables[name] = _table(name, raw);
        }
      }
    }
    if (tables.isEmpty) {
      throw BeakGenerateException.single(source, 'lists no tables.');
    }
    return DatabaseDefinition(tables, source: source);
  }

  static DbTable _table(String name, Map<String, Object?> raw) => DbTable(
    name: name,
    columns: {
      for (final column in _maps(raw['columns']))
        if (column['name'] case final String name)
          name: DbColumn(
            name: name,
            dartType: switch (column['dartType']) {
              final String type => type,
              _ => '',
            },
          ),
    },
    foreignKeys: [
      for (final key in _maps(raw['foreignKeys']))
        if (key['referenceTable'] case final String table)
          DbForeignKey(
            columns: _strings(key['columns']),
            referenceTable: table,
          ),
    ],
    indexes: [
      for (final index in _maps(raw['indexes']))
        DbIndex(
          name: switch (index['indexName']) {
            final String name => name,
            _ => '',
          },
          columns: [
            for (final element in _maps(index['elements']))
              if (element['definition'] case final String definition)
                definition,
          ],
          isUnique: index['isUnique'] == true && index['isPrimary'] != true,
        ),
    ],
  );

  static List<Map<String, Object?>> _maps(Object? raw) => [
    if (raw is List<Object?>)
      for (final item in raw)
        if (item is Map<String, Object?>) item,
  ];

  static List<String> _strings(Object? raw) => [
    if (raw is List<Object?>)
      for (final item in raw)
        if (item is String) item,
  ];
}
