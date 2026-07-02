/// Full `DatabaseAdapter` implementation backed by MySQL.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:mysql_client_plus/mysql_client_plus.dart';
import 'package:worm/worm.dart';

import 'compiler/mysql_compiler.dart';
import 'mysql_error_mapper.dart';
import 'mysql_transaction_adapter.dart';
import 'pool/mysql_connection_pool.dart';
import 'pool/mysql_prepared_statement_cache.dart';

/// Capability profile declared by every MySQL-backed adapter.
///
/// Shared between [MysqlAdapter] and the transactional variant so the
/// two cannot drift apart. MySQL supports transactions, savepoints,
/// joins, aggregations, prepared statements, raw queries, schema
/// introspection, EXPLAIN, and (buffered) streaming. It does **not**
/// support `RETURNING` or partial indexes.
const AdapterCapabilities mysqlAdapterCapabilities = AdapterCapabilities(
  supportsTransactions: true,
  supportsSavepoints: true,
  supportsStreaming: true,
  supportsRawQuery: true,
  supportsReturning: false,
  supportsJoins: true,
  supportsPreparedStatements: true,
  supportsPartialIndexes: false,
  supportsAggregations: true,
  supportsSchemaIntrospection: true,
  supportsExplain: true,
);

const String _introspectSql =
    'SELECT table_name, column_name '
    'FROM information_schema.columns '
    'WHERE table_schema = DATABASE() '
    'ORDER BY table_name, ordinal_position';

/// MySQL-backed [DatabaseAdapter].
///
/// Compiles every worm descriptor with [MysqlCompiler] and executes the
/// resulting SQL on a pooled [MySQLConnection] obtained from
/// [MysqlConnectionPool]. Each method checks out, uses, and returns its
/// own connection, so the adapter is safe to share across concurrent
/// callers.
///
/// All bound values travel through **server-side prepared statements**
/// (positional `?`), never string interpolation. Transactions run the
/// nested callback against a [MysqlTransactionAdapter] pinned to one
/// connection for the whole `START TRANSACTION` … `COMMIT` span.
final class MysqlAdapter extends DatabaseAdapter with ExplainCapable {
  /// Creates an adapter backed by [pool], compiling descriptors with
  /// [compiler]. The optional [preparedStatementCache] records compiled
  /// SQL for prepared-statement-churn diagnostics.
  MysqlAdapter({
    required MysqlConnectionPool pool,
    MysqlCompiler compiler = const MysqlCompiler(),
    MysqlPreparedStatementCache<String>? preparedStatementCache,
  }) : _pool = pool,
       _compiler = compiler,
       _preparedStatementCache =
           preparedStatementCache ?? MysqlPreparedStatementCache<String>(),
       super(capabilities: mysqlAdapterCapabilities);

  final MysqlConnectionPool _pool;
  final MysqlCompiler _compiler;
  final MysqlPreparedStatementCache<String> _preparedStatementCache;

  /// Underlying pool. Exposed for diagnostics and for tests that need
  /// to release resources at teardown.
  MysqlConnectionPool get pool => _pool;

  /// Compiler used for descriptor-to-SQL translation.
  MysqlCompiler get compiler => _compiler;

  /// Observability hook into prepared-statement churn. Each unique
  /// compiled SQL string is recorded once; repeats register hits.
  MysqlPreparedStatementCache<String> get preparedStatementCache =>
      _preparedStatementCache;

  @override
  AdapterType get adapterType => AdapterType.sql;

  @override
  Future<void> connect() async {
    // The underlying pool opens connections lazily on first use; there
    // is no eager handshake to perform here.
  }

  @override
  Future<void> disconnect() => _pool.close();

  Future<R> _run<R>(
    String query,
    Future<R> Function(MySQLConnection conn) body,
  ) {
    _trackPrepared(query);
    return MysqlErrorMapper.wrap(() => _pool.run(body), query: query);
  }

  void _trackPrepared(String sql) {
    if (sql.isEmpty) return;
    if (_preparedStatementCache.get(sql) == null) {
      _preparedStatementCache.put(sql, sql);
    }
  }

  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor d) {
    final compiled = _compiler.compileSelect(d);
    return _run(
      compiled.sql,
      (conn) => runSelectRows(conn, compiled.sql, compiled.parameters),
    );
  }

  @override
  Future<Map<String, Object?>?> selectOne(QueryDescriptor d) async {
    final rows = await select(d.copyWith(limit: 1));
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<Map<String, Object?>> insert(InsertDescriptor d) {
    final compiled = _compiler.compileInsert(d);
    return _run(compiled.sql, (conn) async {
      final result = await runPrepared(conn, compiled.sql, compiled.parameters);
      return materializeInsertedRow(d, result);
    });
  }

  @override
  Future<List<Map<String, Object?>>> insertMany(InsertManyDescriptor d) {
    if (d.rows.isEmpty) {
      return Future<List<Map<String, Object?>>>.value(
        const <Map<String, Object?>>[],
      );
    }
    final compiled = _compiler.compileInsertMany(d);
    return _run(compiled.sql, (conn) async {
      await runPrepared(conn, compiled.sql, compiled.parameters);
      return <Map<String, Object?>>[
        for (final row in d.rows) projectRow(row, d.returning),
      ];
    });
  }

  @override
  Future<int> update(UpdateDescriptor d) {
    final compiled = _compiler.compileUpdate(d);
    return _run(
      compiled.sql,
      (conn) => runAffected(conn, compiled.sql, compiled.parameters),
    );
  }

  @override
  Future<int> delete(DeleteDescriptor d) {
    final compiled = _compiler.compileDelete(d);
    return _run(
      compiled.sql,
      (conn) => runAffected(conn, compiled.sql, compiled.parameters),
    );
  }

  @override
  Future<int> count(AggregateDescriptor d) async =>
      parseAggregateCount(await _aggregateRow(d), d);

  @override
  Future<num?> sum(AggregateDescriptor d) async =>
      parseAggregateSum(await _aggregateRow(d), d);

  @override
  Future<double?> avg(AggregateDescriptor d) async =>
      parseAggregateAvg(await _aggregateRow(d), d);

  @override
  Future<Object?> min(AggregateDescriptor d) async =>
      (await _aggregateRow(d))['min'];

  @override
  Future<Object?> max(AggregateDescriptor d) async =>
      (await _aggregateRow(d))['max'];

  @override
  Future<Map<Object?, num>> aggregateGrouped(
    AggregateDescriptor descriptor,
  ) async {
    if (descriptor.groupBy == null) return super.aggregateGrouped(descriptor);
    final compiled = _compiler.compileGroupedAggregate(descriptor);
    final rows = await _run(
      compiled.sql,
      (conn) => runSelectRows(conn, compiled.sql, compiled.parameters),
    );
    final result = <Object?, num>{};
    for (final row in rows) {
      final value = coerceNum(row['value']);
      if (value != null) result[row['group']] = value;
    }
    return result;
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String query,
    List<Object?> parameters,
  ) => _run(query, (conn) => runSelectRows(conn, query, parameters));

  @override
  Future<int> rawExecute(String statement, List<Object?> parameters) =>
      _run(statement, (conn) => runAffected(conn, statement, parameters));

  @override
  Future<T> transaction<T>(Future<T> Function(DatabaseAdapter tx) action) =>
      MysqlErrorMapper.wrap(
        () => _pool.run((conn) async {
          await conn.execute('START TRANSACTION');
          try {
            final result = await action(
              MysqlTransactionAdapter(connection: conn, compiler: _compiler),
            );
            await conn.execute('COMMIT');
            return result;
          } on Object {
            await _rollbackQuietly(conn);
            rethrow;
          }
        }),
      );

  @override
  Future<void> executeSchema(SchemaDescriptor d) async {
    final compiled = _compiler.compileDdl(d);
    await _run(compiled.sql, (conn) async {
      // DDL carries no user parameters and quotes its identifiers, so
      // it runs over the text protocol rather than a prepared stmt.
      await conn.execute(compiled.sql);
    });
  }

  @override
  Future<Map<String, List<String>>> introspectSchema() =>
      _run(_introspectSql, (conn) async {
        final result = await conn.execute(_introspectSql);
        return groupSchemaRows(result);
      });

  @override
  Stream<Map<String, Object?>> stream(QueryDescriptor d) async* {
    final rows = await select(d);
    for (final row in rows) {
      yield row;
    }
  }

  @override
  String compileToString(Object descriptor) =>
      _compiler.compileToString(descriptor);

  @override
  Future<ExplainResult> explain(QueryDescriptor d) {
    final compiled = _compiler.compileSelect(d);
    final explainSql = 'EXPLAIN FORMAT=JSON ${compiled.sql}';
    return _run(explainSql, (conn) async {
      final result = await runPrepared(conn, explainSql, compiled.parameters);
      return parseMysqlExplainJson(extractExplainRaw(result));
    });
  }

  Future<Map<String, Object?>> _aggregateRow(AggregateDescriptor d) {
    final compiled = _compiler.compileAggregate(d);
    return _run(
      compiled.sql,
      (conn) => aggregateRow(conn, compiled.sql, compiled.parameters),
    );
  }

  Future<void> _rollbackQuietly(MySQLConnection conn) async {
    try {
      await conn.execute('ROLLBACK');
    } on Object {
      // Surface the original failure; a rollback error must not mask it.
    }
  }
}

/// Prepares [sql] on [conn], executes it with [params], and deallocates
/// the server-side statement afterwards.
///
/// Shared by [MysqlAdapter] and [MysqlTransactionAdapter] so both paths
/// use identical binding and clean-up. Deallocation prevents leaking
/// statement handles on pooled connections.
Future<IResultSet> runPrepared(
  MySQLConnection conn,
  String sql,
  List<Object?> params,
) async {
  final stmt = await conn.prepare(sql);
  try {
    return await stmt.execute(bindValues(params));
  } finally {
    await stmt.deallocate();
  }
}

/// Executes a SELECT [sql] and converts each row into a typed map.
Future<List<Map<String, Object?>>> runSelectRows(
  MySQLConnection conn,
  String sql,
  List<Object?> params,
) async {
  final result = await runPrepared(conn, sql, params);
  return <Map<String, Object?>>[
    for (final row in result.rows) typedRowToMap(row),
  ];
}

/// Executes a DML [sql] and returns the number of affected rows.
Future<int> runAffected(
  MySQLConnection conn,
  String sql,
  List<Object?> params,
) async {
  final result = await runPrepared(conn, sql, params);
  return result.affectedRows.toInt();
}

/// Runs an aggregate SELECT and returns its single row, or an empty map
/// when the query produced no rows.
Future<Map<String, Object?>> aggregateRow(
  MySQLConnection conn,
  String sql,
  List<Object?> params,
) async {
  final rows = await runSelectRows(conn, sql, params);
  return rows.isEmpty ? const <String, Object?>{} : rows.first;
}

/// Converts a driver [ResultSetRow] into a typed `Map<String, Object?>`
/// using the column metadata (ints, doubles, `DateTime`, `bool`).
Map<String, Object?> typedRowToMap(ResultSetRow row) {
  final out = <String, Object?>{};
  for (final entry in row.typedAssoc().entries) {
    out[entry.key] = entry.value;
  }
  return out;
}

/// Materialises the row returned by [MysqlAdapter.insert] from the
/// supplied [InsertDescriptor.values] (MySQL has no `RETURNING`),
/// enriching it with the generated key from `LAST_INSERT_ID()` when the
/// caller did not supply an `id` and the table produced one.
Map<String, Object?> materializeInsertedRow(
  InsertDescriptor d,
  IResultSet result,
) {
  final row = projectRow(d.values, d.returning);
  if (d.returning == null && !row.containsKey('id')) {
    final id = result.lastInsertID;
    if (id > BigInt.zero) row['id'] = id.toInt();
  }
  return row;
}

/// Projects [values] down to [returning] columns, or returns a copy of
/// all values when [returning] is null.
Map<String, Object?> projectRow(
  Map<String, Object?> values,
  List<String>? returning,
) {
  if (returning == null) return <String, Object?>{...values};
  return <String, Object?>{for (final c in returning) c: values[c]};
}

/// Normalises a parameter list for the driver's prepared-statement
/// encoder (which accepts null / int / double / String / DateTime /
/// bool / Uint8List / Map / List).
List<Object?> bindValues(List<Object?> params) => <Object?>[
  for (final value in params) bindValue(value),
];

/// Normalises a single bound value: booleans become `0`/`1`, `DateTime`
/// becomes a MySQL-canonical literal, JSON containers are encoded, and
/// binary data passes through unchanged.
Object? bindValue(Object? value) {
  if (value is bool) return value ? 1 : 0;
  if (value is DateTime) return _formatDateTime(value);
  if (value is Uint8List) return value;
  if (value is Map || value is List) return jsonEncode(value);
  return value;
}

String _formatDateTime(DateTime d) {
  String pad(int n, int width) => n.toString().padLeft(width, '0');
  final base =
      '${pad(d.year, 4)}-${pad(d.month, 2)}-${pad(d.day, 2)} '
      '${pad(d.hour, 2)}:${pad(d.minute, 2)}:${pad(d.second, 2)}';
  final micros = d.millisecond * 1000 + d.microsecond;
  return micros == 0 ? base : '$base.${pad(micros, 6)}';
}

/// Reads the `count` aggregate from [row] as an [int]. MySQL returns
/// `COUNT` as `BIGINT` (→ `int`); a string survives huge counts.
int parseAggregateCount(Map<String, Object?> row, AggregateDescriptor d) =>
    switch (row['count']) {
      final int v => v,
      final num v => v.toInt(),
      final String v => int.parse(v),
      _ => throw QueryException(
        query: 'SELECT COUNT(*) FROM `${d.table}`',
        message: 'count() returned a non-numeric value',
      ),
    };

/// Reads the `sum` aggregate from [row] as a nullable [num]. MySQL
/// returns `SUM` over integers as `DECIMAL` (→ `String`), so a string
/// is parsed. `null` (no rows) survives.
num? parseAggregateSum(Map<String, Object?> row, AggregateDescriptor d) =>
    switch (row['sum']) {
      null => null,
      final num v => v,
      final String v => num.parse(v),
      _ => throw QueryException(
        query: 'SELECT SUM(`${d.column}`) FROM `${d.table}`',
        message: 'sum() returned a non-numeric value',
      ),
    };

/// Reads the `avg` aggregate from [row] as a nullable [double]. MySQL
/// returns `AVG` as `DECIMAL` (→ `String`). `null` (no rows) survives.
double? parseAggregateAvg(Map<String, Object?> row, AggregateDescriptor d) =>
    switch (row['avg']) {
      null => null,
      final double v => v,
      final num v => v.toDouble(),
      final String v => double.parse(v),
      _ => throw QueryException(
        query: 'SELECT AVG(`${d.column}`) FROM `${d.table}`',
        message: 'avg() returned a non-numeric value',
      ),
    };

/// Coerces a grouped-aggregate value into a [num]. MySQL `COUNT` arrives
/// as `int` and `SUM` as a `DECIMAL` string, so both shapes are handled.
num? coerceNum(Object? value) => switch (value) {
  final num v => v,
  final String v => num.tryParse(v),
  _ => null,
};

/// Groups an `information_schema.columns` result into a
/// `table → [column, …]` map, reading by column position to dodge any
/// server-dependent column-name casing.
///
/// `information_schema.TABLE_NAME` uses a binary collation, so the driver
/// hands it back as a byte list rather than a `String`; [_schemaText]
/// decodes either shape.
Map<String, List<String>> groupSchemaRows(IResultSet result) {
  final grouped = <String, List<String>>{};
  for (final row in result.rows) {
    if (row.numOfColumns < 2) continue;
    final table = _schemaText(row.colAt(0));
    final column = _schemaText(row.colAt(1));
    if (table != null && column != null) {
      grouped.putIfAbsent(table, () => <String>[]).add(column);
    }
  }
  return grouped;
}

String? _schemaText(Object? value) {
  if (value is String) return value;
  if (value is List<int>) return utf8.decode(value, allowMalformed: true);
  return null;
}

/// Reads the single JSON cell produced by `EXPLAIN FORMAT=JSON`.
String extractExplainRaw(IResultSet result) {
  for (final row in result.rows) {
    if (row.numOfColumns == 0) continue;
    final cell = row.colAt(0);
    return switch (cell) {
      final String s => s,
      null => '',
      _ => cell.toString(),
    };
  }
  return '';
}

final RegExp _indexAccessPattern = RegExp(
  r'"access_type"\s*:\s*"(eq_ref|ref|const|range|index_merge|index|fulltext)"',
);
final RegExp _keyNamePattern = RegExp(r'"key"\s*:\s*"([^"]+)"');
final RegExp _fullScanPattern = RegExp(
  r'"table_name"\s*:\s*"([^"]+)"[^}]*?"access_type"\s*:\s*"ALL"',
);

/// Builds an [ExplainResult] from a MySQL `EXPLAIN FORMAT=JSON`
/// document.
///
/// MySQL emits a single `query_block` tree whose `table` nodes carry an
/// `access_type` (and a `key` when an index is chosen). An index is
/// considered used when any table reports an index-based access type;
/// tables reporting `access_type: "ALL"` are full scans.
///
/// Exposed at library level so the transaction adapter and the unit test
/// can both invoke it with sample plan output.
ExplainResult parseMysqlExplainJson(String raw) => ExplainResult(
  usesIndex: _indexAccessPattern.hasMatch(raw),
  raw: raw,
  indexName: _keyNamePattern.firstMatch(raw)?.group(1),
  scannedTables: <String>[
    for (final m in _fullScanPattern.allMatches(raw))
      if (m.group(1) case final String table) table,
  ],
);
