/// Full `DatabaseAdapter` implementation backed by SQLite.
library;

import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:worm/worm.dart';

import 'compiler/sqlite_compiler.dart';
import 'sqlite_runner.dart';
import 'sqlite_transaction_adapter.dart';

/// A SQLite-backed [DatabaseAdapter].
///
/// Wraps a synchronous `sqlite3` [CommonDatabase] behind the async
/// adapter contract. Use [SqliteAdapter.memory] for tests and
/// [SqliteAdapter.open] for a file-backed database. `id` ↔ rowid is
/// left to the schema; the adapter performs no key remapping.
///
/// SQLite is single-connection, so `transaction` cannot service
/// overlapping queries — eager loading already serialises inside a
/// transaction. Outside one, the in-process engine has no network
/// latency to hide, so concurrent loading is a no-op win here.
final class SqliteAdapter extends DatabaseAdapter with ExplainCapable {
  /// Creates an adapter over an already-open [database].
  ///
  /// [libraryVersion] overrides the version the linked library reports, which
  /// gates the statements SQLite only learned recently. Pass it to prove the
  /// refusal without linking a decade-old SQLite; leave it alone otherwise.
  SqliteAdapter(
    CommonDatabase database, {
    SqliteCompiler compiler = const SqliteCompiler(),
    String? libraryVersion,
  }) : _runner = SqliteRunner(
         database: database,
         compiler: compiler,
         libraryVersion: libraryVersion,
       ),
       super(capabilities: SqliteRunner.capabilities);

  /// Opens a fresh in-memory database (ideal for tests).
  factory SqliteAdapter.memory({String? libraryVersion}) =>
      SqliteAdapter(sqlite3.openInMemory(), libraryVersion: libraryVersion);

  /// Opens (or creates) a file-backed database at [path].
  factory SqliteAdapter.open(String path) => SqliteAdapter(sqlite3.open(path));

  final SqliteRunner _runner;

  @override
  AdapterType get adapterType => AdapterType.sql;

  /// The prepared-statement cache backing this connection. Exposed for
  /// diagnostics (hit/miss counters) and tests.
  SqlitePreparedCache get preparedStatementCache => _runner.preparedCache;

  @override
  Future<void> connect() async {
    // WAL + foreign-key enforcement + the safe-fast synchronous mode.
    _runner.configureConnection();
  }

  @override
  Future<void> disconnect() async => _runner.dispose();

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
      _runner.runInTransaction(() => action(SqliteTransactionAdapter(_runner)));

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
