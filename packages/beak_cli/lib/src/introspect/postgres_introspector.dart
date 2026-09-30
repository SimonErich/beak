import 'beak_schema_introspection.dart';

/// Runs a parameterless SQL query and returns its rows.
///
/// Injected so introspection can be tested against canned rows rather than a
/// live server, and so the CLI does not have to depend on a database driver
/// it only needs for one command.
typedef BeakSqlReader = Future<List<Map<String, Object?>>> Function(String sql);

/// Reads a Postgres schema into [IntrospectedTable]s.
///
/// worm's own `introspectSchema()` returns table names to column names and
/// nothing else — no types, no nullability, no foreign keys, no enums — which
/// is not enough to write a model from. These queries read what a model
/// actually needs, straight from `information_schema` and `pg_catalog`.
final class PostgresIntrospector {
  /// Creates an introspector reading through [query].
  const PostgresIntrospector(this.query, {this.schema = 'public'});

  /// Executes SQL against the target database.
  final BeakSqlReader query;

  /// The Postgres schema to read.
  final String schema;

  /// [schema] as the body of a SQL string literal.
  ///
  /// The queries cannot take a bind parameter (`beak doctor` and the tests run
  /// them through a reader of plain SQL), so a schema name with a quote in it
  /// must not end the literal it is written into.
  static String _literal(String schema) => schema.replaceAll("'", "''");

  /// SQL listing every column of every base table in the schema.
  static String columnsSql(String schema) =>
      '''
SELECT c.table_name, c.column_name, c.data_type, c.is_nullable,
       c.character_maximum_length, c.numeric_precision, c.numeric_scale,
       c.column_default, c.udt_name
FROM information_schema.columns c
JOIN information_schema.tables t
  ON t.table_schema = c.table_schema AND t.table_name = c.table_name
WHERE c.table_schema = '${_literal(schema)}' AND t.table_type = 'BASE TABLE'
ORDER BY c.table_name, c.ordinal_position
''';

  /// SQL listing every foreign key in the schema.
  ///
  /// Read from `pg_constraint`, not from `information_schema`: a constraint
  /// name is only unique within its table, and the `information_schema` views
  /// join on it alone, so two tables that both hand-name a key `fk_owner` were
  /// each given the other's columns and the other's target.
  static String foreignKeysSql(String schema) =>
      '''
SELECT cl.relname AS table_name, a.attname AS column_name,
       target.relname AS referenced_table
FROM pg_constraint con
JOIN pg_class cl ON cl.oid = con.conrelid
JOIN pg_namespace n ON n.oid = cl.relnamespace
JOIN pg_class target ON target.oid = con.confrelid
CROSS JOIN LATERAL unnest(con.conkey) WITH ORDINALITY AS k(attnum, position)
JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = k.attnum
WHERE con.contype = 'f' AND n.nspname = '${_literal(schema)}'
ORDER BY cl.relname, a.attname
''';

  /// SQL listing every primary-key column in the schema, in key order.
  ///
  /// Read from `pg_constraint` for the reason [foreignKeysSql] is.
  static String primaryKeysSql(String schema) =>
      '''
SELECT cl.relname AS table_name, a.attname AS column_name
FROM pg_constraint con
JOIN pg_class cl ON cl.oid = con.conrelid
JOIN pg_namespace n ON n.oid = cl.relnamespace
CROSS JOIN LATERAL unnest(con.conkey) WITH ORDINALITY AS k(attnum, position)
JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = k.attnum
WHERE con.contype = 'p' AND n.nspname = '${_literal(schema)}'
ORDER BY cl.relname, k.position
''';

  /// SQL listing every enum type and its labels, in declaration order.
  static const String enumsSql = '''
SELECT t.typname AS enum_name, e.enumlabel AS enum_value
FROM pg_type t
JOIN pg_enum e ON e.enumtypid = t.oid
ORDER BY t.typname, e.enumsortorder
''';

  /// SQL listing every indexed column, and whether its index is unique.
  ///
  /// Single-column indexes only: a composite index is a decision about a
  /// query, not about a column, and a schema class has nowhere to put it.
  /// The migration a project owns is where those belong.
  static String indexesSql(String schema) =>
      '''
SELECT t.relname AS table_name, a.attname AS column_name, i.indisunique
FROM pg_index i
JOIN pg_class c ON c.oid = i.indexrelid
JOIN pg_class t ON t.oid = i.indrelid
JOIN pg_namespace n ON n.oid = t.relnamespace
JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = i.indkey[0]
WHERE n.nspname = '${_literal(schema)}'
  AND i.indnatts = 1
  AND NOT i.indisprimary
''';

  /// Reads the schema.
  Future<List<IntrospectedTable>> read() async {
    final enumValues = <String, List<String>>{};
    for (final row in await query(enumsSql)) {
      final String name = '${row['enum_name']}';
      (enumValues[name] ??= []).add('${row['enum_value']}');
    }

    final foreignKeys = <String, List<IntrospectedForeignKey>>{};
    for (final row in await query(foreignKeysSql(schema))) {
      (foreignKeys['${row['table_name']}'] ??= []).add(
        IntrospectedForeignKey(
          column: '${row['column_name']}',
          referencedTable: '${row['referenced_table']}',
        ),
      );
    }

    final primaryKeys = <String, String>{};
    for (final row in await query(primaryKeysSql(schema))) {
      primaryKeys.putIfAbsent(
        '${row['table_name']}',
        () => '${row['column_name']}',
      );
    }

    final indexed = <String>{};
    final uniquelyIndexed = <String>{};
    for (final row in await query(indexesSql(schema))) {
      final String key = '${row['table_name']}.${row['column_name']}';
      indexed.add(key);
      if (row['indisunique'] == true || '${row['indisunique']}' == 't') {
        uniquelyIndexed.add(key);
      }
    }

    final columns = <String, List<IntrospectedColumn>>{};
    for (final row in await query(columnsSql(schema))) {
      final String udt = '${row['udt_name']}';
      final List<String> labels = enumValues[udt] ?? const [];
      (columns['${row['table_name']}'] ??= []).add(
        IntrospectedColumn(
          name: '${row['column_name']}',
          dataType: '${row['data_type']}'.toLowerCase(),
          isNullable: '${row['is_nullable']}'.toUpperCase() == 'YES',
          maxLength: _asInt(row['character_maximum_length']),
          numericPrecision: _asInt(row['numeric_precision']),
          numericScale: _asInt(row['numeric_scale']),
          hasDefault: row['column_default'] != null,
          enumTypeName: labels.isEmpty ? null : udt,
          enumValues: labels,
          isIndexed: indexed.contains(
            '${row['table_name']}.${row['column_name']}',
          ),
          isUnique: uniquelyIndexed.contains(
            '${row['table_name']}.${row['column_name']}',
          ),
        ),
      );
    }

    final tables = [
      for (final entry in columns.entries)
        IntrospectedTable(
          name: entry.key,
          columns: entry.value,
          foreignKeys: foreignKeys[entry.key] ?? const [],
          primaryKey: primaryKeys[entry.key] ?? 'id',
        ),
    ]..sort((a, b) => a.name.compareTo(b.name));
    return tables;
  }
}

/// [value] as an int, whichever way the driver returned it.
///
/// `information_schema` columns come back as `int` from one driver version
/// and as a numeric string from another, and a width read as null silently
/// becomes a default width in the migration.
int? _asInt(Object? value) => switch (value) {
  final int number => number,
  final String text => int.tryParse(text),
  _ => null,
};
