/// Transactional `DatabaseAdapter` running inside an open
/// `TxSession`.
library;

import 'package:postgres/postgres.dart';
import 'package:worm/worm.dart';

import 'compiler/postgres_compiler.dart';
import 'postgres_adapter.dart';
import 'postgres_error_mapper.dart';

/// A `DatabaseAdapter` bound to an existing transactional
/// [TxSession].
///
/// `PostgresAdapter.transaction` passes an instance of this class to
/// the user callback; every method dispatches through the same
/// [TxSession] so the whole callback is one transactional unit.
///
/// Nested [transaction] invocations are mapped to PostgreSQL
/// savepoints: a fresh savepoint is issued on entry, released on
/// success, and rolled back when the nested callback throws. A
/// per-instance counter produces unique savepoint names so nested
/// callbacks can themselves invoke [transaction] again.
final class PostgresTransactionAdapter extends DatabaseAdapter
    with ExplainCapable {
  /// Creates a transactional adapter using [session] for every call.
  PostgresTransactionAdapter({
    required TxSession session,
    PostgresCompiler compiler = const PostgresCompiler(),
  }) : _session = session,
       _compiler = compiler,
       super(capabilities: postgresAdapterCapabilities);

  final TxSession _session;
  final PostgresCompiler _compiler;

  /// Monotonic counter for generating unique savepoint names.
  ///
  /// Per-instance (not a static or library-level counter) so two
  /// concurrent transactions running on different sessions do not
  /// contend for the same name space.
  int _savepointCounter = 0;

  @override
  Future<void> connect() async {
    // The transaction is already open — nothing to do.
  }

  @override
  Future<void> disconnect() async {
    // Session lifecycle is owned by the surrounding `Pool.runTx`.
  }

  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor d) {
    final compiled = _compiler.compileSelect(d);
    return PostgresErrorMapper.wrap(
      () => runSelect(_session, compiled.sql, compiled.parameters),
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
    final rows = await PostgresErrorMapper.wrap(
      () => runSelect(_session, compiled.sql, compiled.parameters),
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
    return PostgresErrorMapper.wrap(
      () => runSelect(_session, compiled.sql, compiled.parameters),
      query: compiled.sql,
    );
  }

  @override
  Future<int> update(UpdateDescriptor d) {
    final compiled = _compiler.compileUpdate(d);
    return PostgresErrorMapper.wrap(
      () => runAffected(_session, compiled.sql, compiled.parameters),
      query: compiled.sql,
    );
  }

  @override
  Future<int> delete(DeleteDescriptor d) {
    final compiled = _compiler.compileDelete(d);
    return PostgresErrorMapper.wrap(
      () => runAffected(_session, compiled.sql, compiled.parameters),
      query: compiled.sql,
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
  Future<List<Map<String, Object?>>> rawQuery(
    String query,
    List<Object?> parameters,
  ) => PostgresErrorMapper.wrap(
    () => runSelect(_session, query, parameters),
    query: query,
  );

  @override
  Future<int> rawExecute(String statement, List<Object?> parameters) =>
      PostgresErrorMapper.wrap(
        () => runAffected(_session, statement, parameters),
        query: statement,
      );

  @override
  Future<T> transaction<T>(Future<T> Function(DatabaseAdapter tx) action) =>
      PostgresErrorMapper.wrap(() async {
        _savepointCounter++;
        final name = 'worm_sp_$_savepointCounter';
        await _session.execute('SAVEPOINT $name');
        try {
          final result = await action(this);
          await _session.execute('RELEASE SAVEPOINT $name');
          return result;
        } catch (_) {
          await _session.execute('ROLLBACK TO SAVEPOINT $name');
          rethrow;
        }
      });

  @override
  Future<void> executeSchema(SchemaDescriptor d) async {
    final compiled = _compiler.compileDdl(d);
    await PostgresErrorMapper.wrap(
      () => runAffected(_session, compiled.sql, compiled.parameters),
      query: compiled.sql,
    );
  }

  @override
  Future<Map<String, List<String>>> introspectSchema() =>
      PostgresErrorMapper.wrap(() async {
        const sql =
            'SELECT table_name, column_name '
            'FROM information_schema.columns '
            "WHERE table_schema = 'public' "
            'ORDER BY table_name, ordinal_position';
        final result = await _session.execute(sql);
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
      final result = await _session.execute(
        explainSql,
        parameters: compiled.parameters,
      );
      return parseExplainJsonOutput(extractExplainRaw(result));
    }, query: explainSql);
  }

  Future<Map<String, Object?>> _aggregateRow(AggregateDescriptor d) {
    final compiled = _compiler.compileAggregate(d);
    return PostgresErrorMapper.wrap(
      () => aggregateRow(_session, compiled.sql, compiled.parameters),
      query: compiled.sql,
    );
  }
}
