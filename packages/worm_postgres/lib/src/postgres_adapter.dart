/// Full `DatabaseAdapter` implementation backed by PostgreSQL.
library;

import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:worm/worm.dart';

import 'compiler/postgres_compiler.dart';
import 'pool/postgres_connection_pool.dart';
import 'pool/prepared_statement_cache.dart';
import 'postgres_error_mapper.dart';
import 'postgres_transaction_adapter.dart';

/// Capability profile declared by every PostgreSQL-backed adapter.
///
/// Shared between [PostgresAdapter] and the transactional variant so
/// the two cannot drift apart silently. Transactions, savepoints,
/// returning, explain, streaming, aggregations, prepared statements,
/// raw queries, joins, partial indexes, and schema introspection are
/// all supported.
const AdapterCapabilities postgresAdapterCapabilities = AdapterCapabilities(
  supportsTransactions: true,
  supportsSavepoints: true,
  supportsStreaming: true,
  supportsRawQuery: true,
  supportsReturning: true,
  supportsJoins: true,
  supportsPreparedStatements: true,
  supportsPartialIndexes: true,
  supportsAggregations: true,
  supportsSchemaIntrospection: true,
  supportsExplain: true,
);

/// PostgreSQL-backed [DatabaseAdapter].
///
/// Compiles every worm descriptor with [PostgresCompiler] and
/// executes the resulting SQL on a pooled [Session] obtained from
/// [PostgresConnectionPool]. The adapter is safe to hand to multiple
/// callers concurrently — each method call acquires, uses, and
/// releases its own pooled connection.
///
/// Transactions run the nested callback against a
/// [PostgresTransactionAdapter] bound to the same [TxSession], so
/// within the callback every adapter method executes transactionally.
final class PostgresAdapter extends DatabaseAdapter with ExplainCapable {
  /// Creates an adapter backed by [pool], compiling descriptors with
  /// [compiler]. Optional [preparedStatementCache] tracks reuse for
  /// observability; the underlying `postgres` driver already caches
  /// prepared statements per-connection.
  PostgresAdapter({
    required PostgresConnectionPool pool,
    PostgresCompiler compiler = const PostgresCompiler(),
    PreparedStatementCache<String>? preparedStatementCache,
  }) : _pool = pool,
       _compiler = compiler,
       _preparedStatementCache =
           preparedStatementCache ?? PreparedStatementCache<String>(),
       super(capabilities: postgresAdapterCapabilities);

  final PostgresConnectionPool _pool;
  final PostgresCompiler _compiler;
  final PreparedStatementCache<String> _preparedStatementCache;

  /// Underlying pool. Exposed for diagnostics and for tests that
  /// need to release resources at teardown.
  PostgresConnectionPool get pool => _pool;

  /// Compiler used for descriptor-to-SQL translation.
  PostgresCompiler get compiler => _compiler;

  /// Observability hook into prepared-statement reuse. Each unique
  /// compiled SQL string is recorded once; subsequent compilations
  /// of the same SQL register cache hits.
  PreparedStatementCache<String> get preparedStatementCache =>
      _preparedStatementCache;

  @override
  Future<void> connect() async {
    // The underlying postgres `Pool` opens connections lazily on
    // first use; there is no eager handshake to perform here.
  }

  @override
  Future<void> disconnect() => _pool.close();

  Future<R> _guardedRun<R>(
    Future<R> Function(Session session) action, {
    String query = '',
  }) {
    _trackPrepared(query);
    return PostgresErrorMapper.wrap(() => _pool.run(action), query: query);
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
    return _guardedRun(
      (session) => runSelect(session, compiled.sql, compiled.parameters),
      query: compiled.sql,
    );
  }

  @override
  Future<Map<String, Object?>?> selectOne(QueryDescriptor d) async {
    final rows = await select(d.copyWith(limit: 1));
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<Map<String, Object?>> insert(InsertDescriptor d) async {
    final compiled = _compiler.compileInsert(d);
    final rows = await _guardedRun(
      (session) => runSelect(session, compiled.sql, compiled.parameters),
      query: compiled.sql,
    );
    if (rows.isEmpty) {
      throw QueryException(
        query: compiled.sql,
        message: 'INSERT RETURNING produced no row',
      );
    }
    return rows.first;
  }

  @override
  Future<List<Map<String, Object?>>> insertMany(InsertManyDescriptor d) {
    final compiled = _compiler.compileInsertMany(d);
    return _guardedRun(
      (session) => runSelect(session, compiled.sql, compiled.parameters),
      query: compiled.sql,
    );
  }

  @override
  Future<int> update(UpdateDescriptor d) {
    final compiled = _compiler.compileUpdate(d);
    return _guardedRun(
      (session) => runAffected(session, compiled.sql, compiled.parameters),
      query: compiled.sql,
    );
  }

  @override
  Future<int> delete(DeleteDescriptor d) {
    final compiled = _compiler.compileDelete(d);
    return _guardedRun(
      (session) => runAffected(session, compiled.sql, compiled.parameters),
      query: compiled.sql,
    );
  }

  @override
  Future<int> count(AggregateDescriptor d) async =>
      parseAggregateCount(await _aggregateRow(d), d);

  @override
  Future<Map<Object?, num>> aggregateGrouped(
    AggregateDescriptor descriptor,
  ) async {
    if (descriptor.groupBy == null) return super.aggregateGrouped(descriptor);
    final compiled = _compiler.compileGroupedAggregate(descriptor);
    final rows = await _guardedRun(
      (session) => runSelect(session, compiled.sql, compiled.parameters),
      query: compiled.sql,
    );
    final result = <Object?, num>{};
    for (final row in rows) {
      final value = row['value'];
      if (value is num) result[row['group']] = value;
    }
    return result;
  }

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
  Future<List<Map<String, Object?>>> rawQuery(
    String query,
    List<Object?> parameters,
  ) => _guardedRun(
    (session) => runSelect(session, query, parameters),
    query: query,
  );

  @override
  Future<int> rawExecute(String statement, List<Object?> parameters) =>
      _guardedRun(
        (session) => runAffected(session, statement, parameters),
        query: statement,
      );

  @override
  Future<T> transaction<T>(Future<T> Function(DatabaseAdapter tx) action) =>
      PostgresErrorMapper.wrap(
        () => _pool.transaction(
          (tx) => action(
            PostgresTransactionAdapter(session: tx, compiler: _compiler),
          ),
        ),
      );

  @override
  Future<void> executeSchema(SchemaDescriptor d) async {
    // One descriptor is several statements — a create with indexes, an alter
    // with steps — and they are ordered, so they run in sequence.
    for (final compiled in _compiler.compileDdl(d)) {
      await _guardedRun(
        (session) => runAffected(session, compiled.sql, compiled.parameters),
        query: compiled.sql,
      );
    }
  }

  @override
  Future<Map<String, List<String>>> introspectSchema() =>
      _guardedRun((session) async {
        const sql =
            'SELECT table_name, column_name '
            'FROM information_schema.columns '
            "WHERE table_schema = 'public' "
            'ORDER BY table_name, ordinal_position';
        final result = await session.execute(sql);
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
    final explainSql = 'EXPLAIN (FORMAT JSON) ${compiled.sql}';
    return PostgresErrorMapper.wrap(() async {
      final result = await _pool.run(
        (session) =>
            session.execute(explainSql, parameters: compiled.parameters),
      );
      return parseExplainJsonOutput(extractExplainRaw(result));
    }, query: explainSql);
  }

  Future<Map<String, Object?>> _aggregateRow(AggregateDescriptor d) {
    final compiled = _compiler.compileAggregate(d);
    return _guardedRun(
      (session) => aggregateRow(session, compiled.sql, compiled.parameters),
      query: compiled.sql,
    );
  }
}

/// Builds an [ExplainResult] from the JSON document produced by
/// `EXPLAIN (FORMAT JSON)`.
///
/// PostgreSQL emits an array containing a single object whose
/// `Plan` key holds a tree of nodes. Each node carries `"Node
/// Type"` and — for scan nodes — `"Relation Name"`. This helper
/// scans the raw text for those keys without parsing the JSON
/// into a typed model, which keeps the helper allocation-free and
/// independent of any postgres-specific result types.
///
/// Exposed at library level so the transaction adapter and the
/// unit test can both invoke it with sample plan output.
ExplainResult parseExplainJsonOutput(String raw) => ExplainResult(
  usesIndex: _detectIndexUseInJson(raw),
  raw: raw,
  scannedTables: _detectSeqScansInJson(raw),
);

/// Extracts the raw JSON plan string from the [Result] of an
/// `EXPLAIN (FORMAT JSON)` query.
///
/// The plan lives in the first cell of the first row. Postgres
/// may deliver it as either a [String] or as a [List]/[Map] that
/// the postgres driver has already decoded; both cases are
/// normalised to a [String] via pattern matching so callers see
/// a single shape.
String extractExplainRaw(Result rows) {
  for (final row in rows) {
    if (row.isEmpty) continue;
    final cell = row.first;
    return switch (cell) {
      final String s => s,
      null => '',
      _ => cell.toString(),
    };
  }
  return '';
}

bool _detectIndexUseInJson(String raw) =>
    raw.contains('"Index Scan"') ||
    raw.contains('"Index Only Scan"') ||
    raw.contains('"Bitmap Index Scan"');

List<String> _detectSeqScansInJson(String raw) {
  // The regex tolerates whitespace between the keys because
  // postgres pretty-prints when the output is read via psql but
  // returns compact text over the wire; both shapes are handled.
  final regex = RegExp(
    r'"Node Type"\s*:\s*"Seq Scan"[^}]*?'
    r'"Relation Name"\s*:\s*"([^"]+)"',
  );
  return <String>[
    for (final m in regex.allMatches(raw))
      if (m.group(1) case final String table) table,
  ];
}

/// Executes [sql] with [parameters] on [session] and converts each
/// [ResultRow] into a typed [Map]. Exposed at library level so the
/// [PostgresTransactionAdapter] can reuse the conversion logic
/// against a transactional [Session].
Future<List<Map<String, Object?>>> runSelect(
  Session session,
  String sql,
  List<Object?> parameters,
) async {
  final result = await session.execute(sql, parameters: parameters);
  return <Map<String, Object?>>[for (final row in result) rowToMap(row)];
}

/// Executes [sql] with [parameters] on [session] and returns the
/// number of affected rows (for INSERT/UPDATE/DELETE/DDL).
Future<int> runAffected(
  Session session,
  String sql,
  List<Object?> parameters,
) async {
  final result = await session.execute(sql, parameters: parameters);
  return result.affectedRows;
}

/// Runs an aggregate SELECT and returns its single result row, or an
/// empty map when the query produced no rows. Shared by both the
/// pooled and transactional adapters via their respective session
/// acquisition paths.
Future<Map<String, Object?>> aggregateRow(
  Session session,
  String sql,
  List<Object?> parameters,
) async {
  final rows = await runSelect(session, sql, parameters);
  return rows.isEmpty ? const <String, Object?>{} : rows.first;
}

/// Reads the `count` column from an aggregate [row], coercing it into
/// an [int]. Postgres may return the value as [int], [num] (when the
/// driver widens) or as a [String] (for `bigint` counts above
/// 2^53-1). Throws a [QueryException] for any other shape.
int parseAggregateCount(Map<String, Object?> row, AggregateDescriptor d) =>
    switch (row['count']) {
      final int v => v,
      final num v => v.toInt(),
      final String v => int.parse(v),
      _ => throw QueryException(
        query: 'SELECT COUNT(*) FROM "${d.table}"',
        message: 'count() returned a non-numeric value',
      ),
    };

/// Reads the `sum` column from an aggregate [row], coercing it into a
/// nullable [num]. `null` survives as `null` (an empty aggregate over
/// no rows). Throws a [QueryException] for any non-numeric shape.
num? parseAggregateSum(Map<String, Object?> row, AggregateDescriptor d) =>
    switch (row['sum']) {
      null => null,
      final num v => v,
      final String v => num.parse(v),
      _ => throw QueryException(
        query: 'SELECT SUM("${d.column}") FROM "${d.table}"',
        message: 'sum() returned a non-numeric value',
      ),
    };

/// Reads the `avg` column from an aggregate [row], coercing it into a
/// nullable [double]. `null` survives as `null`. Throws a
/// [QueryException] for any non-numeric shape.
double? parseAggregateAvg(Map<String, Object?> row, AggregateDescriptor d) =>
    switch (row['avg']) {
      null => null,
      final double v => v,
      final num v => v.toDouble(),
      final String v => double.parse(v),
      _ => throw QueryException(
        query: 'SELECT AVG("${d.column}") FROM "${d.table}"',
        message: 'avg() returned a non-numeric value',
      ),
    };

/// Converts a postgres [ResultRow] into a typed `Map<String, Object?>`
/// without using `as` casts or `dynamic`.
Map<String, Object?> rowToMap(ResultRow row) {
  final out = <String, Object?>{};
  for (final (i, column) in row.schema.columns.indexed) {
    final name = column.columnName;
    if (name == null) continue;
    out[name] = decodeColumnValue(row[i]);
  }
  return out;
}

/// Turns the value the driver could not type into something a row can hold.
///
/// The postgres driver hands back an [UndecodedBytes] for a column whose type
/// it does not know: a native `enum`, a `citext`, a domain over either. Those
/// are all text on the wire, so a payload that is valid UTF-8 becomes a
/// `String` (the label of an enum). Any other value passes through, and so
/// does a payload that is not text, left as its raw bytes.
Object? decodeColumnValue(Object? value) {
  if (value is! UndecodedBytes) return value;
  try {
    return utf8.decode(value.bytes);
  } on FormatException {
    return value.bytes;
  }
}

/// Groups an `information_schema.columns` result into a
/// `table → [column, ...]` map.
Map<String, List<String>> groupSchemaRows(Result rows) {
  final grouped = <String, List<String>>{};
  for (final row in rows) {
    if (row.length < 2) continue;
    final table = row[0];
    final column = row[1];
    if (table is! String || column is! String) continue;
    grouped.putIfAbsent(table, () => <String>[]).add(column);
  }
  return grouped;
}
