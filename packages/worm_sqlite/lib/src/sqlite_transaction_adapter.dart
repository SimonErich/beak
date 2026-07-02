/// Transactional `DatabaseAdapter` running inside a SQLite
/// `BEGIN … COMMIT` / `SAVEPOINT` scope.
library;

import 'package:worm/worm.dart';

import 'sqlite_runner.dart';

/// A `DatabaseAdapter` that runs every operation on a SQLite database
/// already inside an open transaction. Reads and writes share the
/// connection's [SqliteRunner]; nested [transaction] calls open
/// SAVEPOINTs.
final class SqliteTransactionAdapter extends DatabaseAdapter
    with ExplainCapable {
  /// Creates an adapter sharing the enclosing transaction's runner.
  SqliteTransactionAdapter(this._runner)
    : super(capabilities: SqliteRunner.capabilities);

  final SqliteRunner _runner;
  int _savepointCounter = 0;

  @override
  AdapterType get adapterType => AdapterType.sql;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor d) =>
      _runner.select(d);

  @override
  Future<Map<String, Object?>?> selectOne(QueryDescriptor d) =>
      _runner.selectOne(d);

  @override
  Future<Map<String, Object?>> insert(InsertDescriptor d) => _runner.insert(d);

  @override
  Future<List<Map<String, Object?>>> insertMany(InsertManyDescriptor d) =>
      _runner.insertMany(d);

  @override
  Future<int> update(UpdateDescriptor d) => _runner.update(d);

  @override
  Future<int> delete(DeleteDescriptor d) => _runner.delete(d);

  @override
  Future<int> count(AggregateDescriptor d) => _runner.count(d);

  @override
  Future<num?> sum(AggregateDescriptor d) => _runner.sum(d);

  @override
  Future<double?> avg(AggregateDescriptor d) => _runner.avg(d);

  @override
  Future<Object?> min(AggregateDescriptor d) => _runner.min(d);

  @override
  Future<Object?> max(AggregateDescriptor d) => _runner.max(d);

  @override
  Future<Map<Object?, num>> aggregateGrouped(AggregateDescriptor descriptor) =>
      _runner.aggregateGrouped(descriptor);

  @override
  Future<List<Map<String, Object?>>> rawQuery(String q, List<Object?> p) =>
      _runner.rawQuery(q, p);

  @override
  Future<int> rawExecute(String s, List<Object?> p) => _runner.rawExecute(s, p);

  @override
  Future<T> transaction<T>(Future<T> Function(DatabaseAdapter tx) action) =>
      _runner.runInSavepoint(
        'worm_sp_${++_savepointCounter}',
        () => action(this),
      );

  @override
  Future<void> executeSchema(SchemaDescriptor d) => _runner.executeSchema(d);

  @override
  Future<Map<String, List<String>>> introspectSchema() =>
      _runner.introspectSchema();

  @override
  Stream<Map<String, Object?>> stream(QueryDescriptor d) => _runner.stream(d);

  @override
  String compileToString(Object descriptor) =>
      _runner.compileToString(descriptor);

  @override
  Future<ExplainResult> explain(QueryDescriptor descriptor) =>
      _runner.explain(descriptor);
}
