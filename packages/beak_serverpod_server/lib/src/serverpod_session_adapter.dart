import 'dart:convert';

import 'package:serverpod/serverpod.dart'
    show DatabaseResult, DatabaseUtil, QueryParameters, Session, Transaction;
import 'package:worm/worm.dart';
import 'package:worm_postgres/worm_postgres.dart'
    show
        PostgresCompiler,
        parseAggregateAvg,
        parseAggregateCount,
        parseAggregateSum,
        parseExplainJsonOutput;

import 'beak_serverpod.dart';
import 'serverpod_database_bridge.dart';

/// Capabilities of a [ServerpodSessionAdapter].
///
/// Serverpod owns the schema through its migrations, so schema
/// introspection and alterations are off. Prepared statements are off
/// because statements reach the driver as unnamed, one-shot extended-protocol
/// queries through `unsafeQuery`.
const AdapterCapabilities serverpodSessionAdapterCapabilities =
    AdapterCapabilities(
      supportsTransactions: true,
      supportsSavepoints: true,
      supportsStreaming: true,
      supportsRawQuery: true,
      supportsReturning: true,
      supportsJoins: true,
      supportsAggregations: true,
      supportsExplain: true,
    );

/// A worm [DatabaseAdapter] over the Serverpod request's own database.
///
/// Statements are compiled by worm_postgres's [PostgresCompiler] (quoted
/// identifiers, `$n` placeholders) and run through
/// `session.db.unsafeQuery`/`unsafeExecute` with
/// `QueryParameters.positional`, so they share Serverpod's pool, logging and
/// (inside [transaction]) its transaction.
///
/// **Session.** The default adapter reads the session from the zone set by
/// [BeakServerpod.runInSession], once per call and synchronously at the call,
/// so one adapter instance serves every request.
/// [ServerpodSessionAdapter.forSession] pins a session instead.
///
/// **Transactions.** The outermost [transaction] opens a Serverpod
/// transaction; a nested one is a savepoint on it, never flattened, so an
/// inner failure rolls back only the inner work. The adapter handed to the
/// callback is pinned to the session and transaction, and exposes both to
/// typed ORM code via [BeakServerpod.sessionOf] and
/// [BeakServerpod.transactionOf].
///
/// **Errors.** Serverpod's database exceptions become worm exceptions per
/// statement and around the whole transaction (see
/// [guardServerpodDatabase]), so a unique violation reads as a
/// `UniqueConstraintException` whether it happens mid-transaction or at
/// COMMIT. Postgres refuses to COMMIT after any failed statement, even one
/// the caller caught, so a statement whose failure is meant to be survived
/// must run in its own nested [transaction].
///
/// **Values.** Parameters are normalised to Serverpod's storage form by
/// [serverpodParameterValue] (UTC instants, milliseconds for `Duration`).
final class ServerpodSessionAdapter extends DatabaseAdapter
    with ExplainCapable {
  /// An adapter that takes its session from the zone.
  ///
  /// [statementTimeoutInSeconds] is passed to every statement; Postgres
  /// cancels one that runs longer.
  ServerpodSessionAdapter({
    PostgresCompiler compiler = const PostgresCompiler(),
    int? statementTimeoutInSeconds,
  }) : this._(compiler, statementTimeoutInSeconds, null, null);

  /// An adapter pinned to [session], ignoring the zone.
  ServerpodSessionAdapter.forSession(
    Session session, {
    PostgresCompiler compiler = const PostgresCompiler(),
    int? statementTimeoutInSeconds,
  }) : this._(compiler, statementTimeoutInSeconds, session, null);

  ServerpodSessionAdapter._(
    this._compiler,
    this._statementTimeoutInSeconds,
    this._pinnedSession,
    this.serverpodTransaction,
  ) : super(capabilities: serverpodSessionAdapterCapabilities);

  final PostgresCompiler _compiler;
  final int? _statementTimeoutInSeconds;
  final Session? _pinnedSession;

  /// The Serverpod transaction this adapter runs in, or `null` outside one.
  final Transaction? serverpodTransaction;

  /// The session statements run on: the pinned one, else the zone's.
  ///
  /// Throws a [StateError] when neither exists.
  Session get session => _pinnedSession ?? BeakServerpod.currentSession;

  /// The compiler turning worm descriptors into Postgres SQL.
  PostgresCompiler get compiler => _compiler;

  @override
  Future<void> connect() async {
    // Serverpod owns the pool; there is nothing to open.
  }

  @override
  Future<void> disconnect() async {
    // Serverpod owns the pool; closing it is the server's shutdown.
  }

  @override
  Future<List<Map<String, Object?>>> select(QueryDescriptor descriptor) {
    final compiled = _compiler.compileSelect(descriptor);
    return _rows(compiled.sql, compiled.parameters);
  }

  @override
  Future<Map<String, Object?>?> selectOne(QueryDescriptor descriptor) async {
    final rows = await select(descriptor.copyWith(limit: 1));
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<Map<String, Object?>> insert(InsertDescriptor descriptor) async {
    final compiled = _compiler.compileInsert(descriptor);
    final rows = await _rows(compiled.sql, compiled.parameters);
    if (rows.isEmpty) {
      throw QueryException(
        query: compiled.sql,
        message: 'INSERT RETURNING produced no row',
      );
    }
    return rows.first;
  }

  @override
  Future<List<Map<String, Object?>>> insertMany(
    InsertManyDescriptor descriptor,
  ) {
    final compiled = _compiler.compileInsertMany(descriptor);
    return _rows(compiled.sql, compiled.parameters);
  }

  @override
  Future<int> update(UpdateDescriptor descriptor) {
    final compiled = _compiler.compileUpdate(descriptor);
    return _affected(compiled.sql, compiled.parameters);
  }

  @override
  Future<int> delete(DeleteDescriptor descriptor) {
    final compiled = _compiler.compileDelete(descriptor);
    return _affected(compiled.sql, compiled.parameters);
  }

  @override
  Future<int> count(AggregateDescriptor descriptor) async =>
      parseAggregateCount(await _aggregateRow(descriptor), descriptor);

  @override
  Future<Map<Object?, num>> aggregateGrouped(
    AggregateDescriptor descriptor,
  ) async {
    if (descriptor.groupBy == null) return super.aggregateGrouped(descriptor);
    final compiled = _compiler.compileGroupedAggregate(descriptor);
    final rows = await _rows(compiled.sql, compiled.parameters);
    return {
      for (final row in rows)
        if (row['value'] case final num value) row['group']: value,
    };
  }

  @override
  Future<num?> sum(AggregateDescriptor descriptor) async =>
      parseAggregateSum(await _aggregateRow(descriptor), descriptor);

  @override
  Future<double?> avg(AggregateDescriptor descriptor) async =>
      parseAggregateAvg(await _aggregateRow(descriptor), descriptor);

  @override
  Future<Object?> min(AggregateDescriptor descriptor) async =>
      (await _aggregateRow(descriptor))['min'];

  @override
  Future<Object?> max(AggregateDescriptor descriptor) async =>
      (await _aggregateRow(descriptor))['max'];

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String query,
    List<Object?> parameters,
  ) => _rows(query, parameters);

  @override
  Future<int> rawExecute(String statement, List<Object?> parameters) =>
      _affected(statement, parameters);

  @override
  Future<T> transaction<T>(Future<T> Function(DatabaseAdapter tx) action) {
    final Session current = session;
    final Transaction? outer = serverpodTransaction;
    return guardServerpodDatabase(
      () => DatabaseUtil.runInTransactionOrSavepoint<T>(
        current.db,
        outer,
        (transaction) =>
            action(outer == null ? _boundTo(current, transaction) : this),
      ),
      query: outer == null ? 'BEGIN … COMMIT' : 'SAVEPOINT … RELEASE',
    );
  }

  @override
  Future<void> executeSchema(SchemaDescriptor descriptor) =>
      Future.error(_serverpodOwnsSchema('executeSchema'));

  @override
  Future<Map<String, List<String>>> introspectSchema() =>
      Future.error(_serverpodOwnsSchema('introspectSchema'));

  @override
  Stream<Map<String, Object?>> stream(QueryDescriptor descriptor) {
    // The session is resolved now, at the call, and the query runs when the
    // stream is listened to: the listener may sit in another zone.
    final Session current = session;
    final compiled = _compiler.compileSelect(descriptor);
    return _streamOn(current, compiled.sql, compiled.parameters);
  }

  Stream<Map<String, Object?>> _streamOn(
    Session current,
    String sql,
    List<Object?> parameters,
  ) async* {
    yield* Stream.fromIterable(await _rowsOn(current, sql, parameters));
  }

  @override
  String compileToString(Object descriptor) =>
      _compiler.compileToString(descriptor);

  @override
  Future<ExplainResult> explain(QueryDescriptor descriptor) async {
    final compiled = _compiler.compileSelect(descriptor);
    final rows = await _rows(
      'EXPLAIN (FORMAT JSON) ${compiled.sql}',
      compiled.parameters,
    );
    final Object? plan = rows.isEmpty ? null : rows.first.values.firstOrNull;
    // The driver decodes the json column into Dart lists and maps; their
    // toString() is not JSON, and the plan parser reads JSON keys.
    return parseExplainJsonOutput(switch (plan) {
      null => '',
      final String text => text,
      final Object decoded => jsonEncode(decoded),
    });
  }

  ServerpodSessionAdapter _boundTo(Session session, Transaction transaction) =>
      ServerpodSessionAdapter._(
        _compiler,
        _statementTimeoutInSeconds,
        session,
        transaction,
      );

  Future<List<Map<String, Object?>>> _rows(
    String sql,
    List<Object?> parameters,
  ) => _rowsOn(session, sql, parameters);

  Future<List<Map<String, Object?>>> _rowsOn(
    Session current,
    String sql,
    List<Object?> parameters,
  ) => guardServerpodDatabase(() async {
    final DatabaseResult result = await current.db.unsafeQuery(
      sql,
      parameters: _parameters(parameters),
      transaction: serverpodTransaction,
      timeoutInSeconds: _statementTimeoutInSeconds,
    );
    return [
      for (final row in result) <String, Object?>{...row.toColumnMap()},
    ];
  }, query: sql);

  Future<int> _affected(String sql, List<Object?> parameters) {
    final Session current = session;
    return guardServerpodDatabase(
      () => current.db.unsafeExecute(
        sql,
        parameters: _parameters(parameters),
        transaction: serverpodTransaction,
        timeoutInSeconds: _statementTimeoutInSeconds,
      ),
      query: sql,
    );
  }

  Future<Map<String, Object?>> _aggregateRow(
    AggregateDescriptor descriptor,
  ) async {
    final compiled = _compiler.compileAggregate(descriptor);
    final rows = await _rows(compiled.sql, compiled.parameters);
    return rows.isEmpty ? const <String, Object?>{} : rows.first;
  }

  static QueryParameters? _parameters(List<Object?> values) => values.isEmpty
      ? null
      : QueryParameters.positional([
          for (final value in values) serverpodParameterValue(value),
        ]);

  static UnsupportedOperationException _serverpodOwnsSchema(String operation) =>
      UnsupportedOperationException(
        operation: operation,
        adapter: 'ServerpodSessionAdapter',
        message:
            'Serverpod owns the schema: change it in a *.spy.yaml file and '
            'create a migration with `serverpod create-migration`.',
      );
}
