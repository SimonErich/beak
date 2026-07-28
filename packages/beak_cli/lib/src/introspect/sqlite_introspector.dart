import 'beak_schema_introspection.dart';
import 'postgres_introspector.dart';

/// Reads a live SQLite schema through [BeakSqlReader].
///
/// SQLite has no `information_schema`, so this walks `sqlite_master` and the
/// `PRAGMA` functions instead. Same output as [PostgresIntrospector], so
/// everything downstream, `beak doctor`'s drift check and the migration
/// generator, works against the zero-setup default database rather than only
/// against a server someone remembered to configure.
final class SqliteIntrospector {
  /// Creates an introspector reading through [query].
  const SqliteIntrospector(this.query);

  /// Runs a statement and returns its rows.
  final BeakSqlReader query;

  /// SQL listing every table a project owns.
  ///
  /// `sqlite_%` is SQLite's own bookkeeping, and a view is not a table Beak
  /// migrates.
  static const String tablesSql = '''
SELECT name FROM sqlite_master
WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
ORDER BY name
''';

  /// Reads every table, its columns, its indexes and its foreign keys.
  Future<List<IntrospectedTable>> read() async {
    final tables = <IntrospectedTable>[];
    for (final row in await query(tablesSql)) {
      final String name = '${row['name']}';
      tables.add(
        IntrospectedTable(
          name: name,
          columns: await _columnsOf(name),
          foreignKeys: await _foreignKeysOf(name),
          primaryKey: await _primaryKeyOf(name),
        ),
      );
    }
    return tables;
  }

  Future<List<IntrospectedColumn>> _columnsOf(String table) async {
    final (indexed, unique) = await _indexedColumnsOf(table);
    return [
      for (final row in await query('PRAGMA table_info("$table")'))
        _columnOf(row, indexed: indexed, unique: unique),
    ];
  }

  IntrospectedColumn _columnOf(
    Map<String, Object?> row, {
    required Set<String> indexed,
    required Set<String> unique,
  }) {
    final String name = '${row['name']}';
    final String declared = '${row['type']}';
    final (String type, int? length, int? precision, int? scale) = _typeOf(
      declared,
    );
    return IntrospectedColumn(
      name: name,
      dataType: type,
      // `notnull` is 0 or 1, and a primary key is implicitly not null.
      isNullable: '${row['notnull']}' != '1' && '${row['pk']}' == '0',
      maxLength: length,
      numericPrecision: precision,
      numericScale: scale,
      hasDefault: row['dflt_value'] != null,
      isIndexed: indexed.contains(name),
      isUnique: unique.contains(name),
    );
  }

  /// The declared type split into its base name and its width.
  ///
  /// SQLite stores the declaration verbatim, so `VARCHAR(120)` and
  /// `NUMERIC(12, 4)` arrive as written and the width is read back out of the
  /// string rather than from a catalog column.
  static (String, int?, int?, int?) _typeOf(String declared) {
    final match = RegExp(
      r'^\s*(\w[\w\s]*?)\s*\(([^)]*)\)\s*$',
    ).firstMatch(declared);
    if (match == null) {
      return (declared.trim().toLowerCase(), null, null, null);
    }
    final String base = match.group(1)!.trim().toLowerCase();
    final List<int?> widths = [
      for (final part in match.group(2)!.split(',')) int.tryParse(part.trim()),
    ];
    // One argument is a length on a text type and a precision on a numeric
    // one; two are always precision and scale.
    if (widths.length >= 2) {
      return (base, null, widths[0], widths[1]);
    }
    final bool isNumeric = base.contains('numeric') || base.contains('decimal');
    return (
      base,
      isNumeric ? null : widths.first,
      isNumeric ? widths.first : null,
      null,
    );
  }

  /// The columns of [table] an index covers, and those an index makes unique.
  Future<(Set<String>, Set<String>)> _indexedColumnsOf(String table) async {
    final indexed = <String>{};
    final unique = <String>{};
    for (final index in await query('PRAGMA index_list("$table")')) {
      final columns = [
        for (final row in await query('PRAGMA index_info("${index['name']}")'))
          '${row['name']}',
      ];
      // A composite index says nothing about any one of its columns being
      // separately indexed, which is what a schema class can express.
      if (columns.length != 1) {
        continue;
      }
      indexed.add(columns.single);
      if ('${index['unique']}' == '1') {
        unique.add(columns.single);
      }
    }
    return (indexed, unique);
  }

  Future<List<IntrospectedForeignKey>> _foreignKeysOf(String table) async => [
    for (final row in await query('PRAGMA foreign_key_list("$table")'))
      IntrospectedForeignKey(
        column: '${row['from']}',
        referencedTable: '${row['table']}',
      ),
  ];

  /// The primary key of [table], or `id` when it declares none.
  ///
  /// Every table Beak generates has one; a table another system owns might
  /// not, and naming the conventional column keeps the rest of the pipeline
  /// from having to handle a null.
  Future<String> _primaryKeyOf(String table) async {
    for (final row in await query('PRAGMA table_info("$table")')) {
      if ('${row['pk']}' != '0') {
        return '${row['name']}';
      }
    }
    return 'id';
  }
}
