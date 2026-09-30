/// Transactional `DatabaseAdapter` running on a pinned MySQL connection.
library;

import 'package:mysql_client_plus/mysql_client_plus.dart';
import 'package:worm/worm.dart';

import 'compiler/mysql_compiler.dart';
import 'mysql_adapter.dart';
import 'mysql_error_mapper.dart';

/// A `DatabaseAdapter` bound to one open [MySQLConnection] inside an
/// active transaction.
///
/// `MysqlAdapter.transaction` issues `START TRANSACTION` on a checked-out
/// connection and passes an instance of this class to the user callback;
/// every method dispatches through the same connection so the whole
/// callback is one transactional unit.
///
/// Nested [transaction] invocations map to MySQL savepoints: a fresh
/// savepoint is issued on entry, released on success, and rolled back to
/// when the nested callback throws. A per-instance counter produces
/// unique savepoint names so nested callbacks may themselves nest.
final class MysqlTransactionAdapter extends DatabaseAdapter
    with ExplainCapable, CurrentReadCapable {
  /// Creates a transactional adapter using [connection] for every call.
  MysqlTransactionAdapter({
    required MySQLConnection connection,
    MysqlCompiler compiler = const MysqlCompiler(),
  }) : _connection = connection,
       _compiler = compiler,
       super(capabilities: mysqlAdapterCapabilities);

  final MySQLConnection _connection;
  final MysqlCompiler _compiler;

  /// Monotonic per-instance counter for unique savepoint names.
  int _savepointCounter = 0;

  @override
  AdapterType get adapterType => AdapterType.sql;

  @override
  Future<void> connect() async {
    // The transaction is already open — nothing to do.
  }

  @override
  Future<void> disconnect() async {
    // Connection lifecycle is owned by the surrounding pool checkout.
  }

  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor d) {
    final compiled = _compiler.compileSelect(d);
    return MysqlErrorMapper.wrap(
      () => runSelectRows(_connection, compiled.sql, compiled.parameters),
      query: compiled.sql,
    );
  }

  @override
  Future<Map<String, Object?>?> selectOne(QueryDescriptor d) async {
    final rows = await select(d.copyWith(limit: 1));
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<Map<String, Object?>?> selectOneCurrent(QueryDescriptor d) async {
    final compiled = _compiler.compileCurrentSelect(d);
    final rows = await MysqlErrorMapper.wrap(
      () => runSelectRows(_connection, compiled.sql, compiled.parameters),
      query: compiled.sql,
    );
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<Map<String, Object?>> insert(InsertDescriptor d) {
    final compiled = _compiler.compileInsert(d);
    return MysqlErrorMapper.wrap(() async {
      final result = await runPrepared(
        _connection,
        compiled.sql,
        compiled.parameters,
      );
      return materializeInsertedRow(d, result);
    }, query: compiled.sql);
  }

  @override
  Future<List<Map<String, Object?>>> insertMany(InsertManyDescriptor d) {
    if (d.rows.isEmpty) {
      return Future<List<Map<String, Object?>>>.value(
        const <Map<String, Object?>>[],
      );
    }
    final compiled = _compiler.compileInsertMany(d);
    return MysqlErrorMapper.wrap(() async {
      await runPrepared(_connection, compiled.sql, compiled.parameters);
      return <Map<String, Object?>>[
        for (final row in d.rows) projectRow(row, d.returning),
      ];
    }, query: compiled.sql);
  }

  @override
  Future<int> update(UpdateDescriptor d) {
    final compiled = _compiler.compileUpdate(d);
    return MysqlErrorMapper.wrap(
      () => runAffected(_connection, compiled.sql, compiled.parameters),
      query: compiled.sql,
    );
  }

  @override
  Future<int> delete(DeleteDescriptor d) {
    final compiled = _compiler.compileDelete(d);
    return MysqlErrorMapper.wrap(
      () => runAffected(_connection, compiled.sql, compiled.parameters),
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
  Future<Map<Object?, num>> aggregateGrouped(
    AggregateDescriptor descriptor,
  ) async {
    if (descriptor.groupBy == null) return super.aggregateGrouped(descriptor);
    final compiled = _compiler.compileGroupedAggregate(descriptor);
    final rows = await MysqlErrorMapper.wrap(
      () => runSelectRows(_connection, compiled.sql, compiled.parameters),
      query: compiled.sql,
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
  ) => MysqlErrorMapper.wrap(
    () => runSelectRows(_connection, query, parameters),
    query: query,
  );

  @override
  Future<int> rawExecute(String statement, List<Object?> parameters) =>
      MysqlErrorMapper.wrap(
        () => runAffected(_connection, statement, parameters),
        query: statement,
      );

  @override
  Future<T> transaction<T>(Future<T> Function(DatabaseAdapter tx) action) =>
      MysqlErrorMapper.wrap(() async {
        _savepointCounter++;
        final name = 'worm_sp_$_savepointCounter';
        await _connection.execute('SAVEPOINT $name');
        try {
          final result = await action(this);
          await _connection.execute('RELEASE SAVEPOINT $name');
          return result;
        } on Object {
          await _connection.execute('ROLLBACK TO SAVEPOINT $name');
          rethrow;
        }
      });

  @override
  Future<void> executeSchema(SchemaDescriptor d) async {
    // One descriptor is several ordered statements.
    for (final compiled in _compiler.compileDdl(d)) {
      await MysqlErrorMapper.wrap(
        () => _connection.execute(compiled.sql),
        query: compiled.sql,
      );
    }
  }

  @override
  Future<Map<String, List<String>>> introspectSchema() =>
      MysqlErrorMapper.wrap(() async {
        const sql =
            'SELECT table_name, column_name '
            'FROM information_schema.columns '
            'WHERE table_schema = DATABASE() '
            'ORDER BY table_name, ordinal_position';
        final result = await _connection.execute(sql);
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
    return MysqlErrorMapper.wrap(() async {
      final result = await runPrepared(
        _connection,
        explainSql,
        compiled.parameters,
      );
      return parseMysqlExplainJson(extractExplainRaw(result));
    }, query: explainSql);
  }

  Future<Map<String, Object?>> _aggregateRow(AggregateDescriptor d) {
    final compiled = _compiler.compileAggregate(d);
    return MysqlErrorMapper.wrap(
      () => aggregateRow(_connection, compiled.sql, compiled.parameters),
      query: compiled.sql,
    );
  }
}
