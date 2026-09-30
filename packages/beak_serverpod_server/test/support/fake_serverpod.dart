/// Database-free stand-ins for the Serverpod objects the adapter and the
/// engine touch: a [Session] with an [AuthenticationInfo] and a log, and a
/// [Database] that records every statement and replays queued results.
///
/// What runs against a real Serverpod database lives in the example project.
library;

import 'package:serverpod/serverpod.dart';

/// One statement a [FakeDatabase] received.
final class RecordedStatement {
  /// Creates a record of a statement.
  const RecordedStatement({
    required this.sql,
    required this.parameters,
    required this.transaction,
    required this.timeoutInSeconds,
  });

  /// The SQL text.
  final String sql;

  /// The positional parameters, or `null` when none were passed.
  final List<Object?>? parameters;

  /// The Serverpod transaction the statement ran in.
  final Transaction? transaction;

  /// The statement timeout passed with it.
  final int? timeoutInSeconds;
}

final class _FakeRow extends DatabaseResultRow {
  _FakeRow(this._map) : super(_map.values.toList());

  final Map<String, Object?> _map;

  @override
  // interop: DatabaseResultRow.toColumnMap is declared with `dynamic` values.
  Map<String, dynamic> toColumnMap() => _map;
}

final class _FakeResult extends DatabaseResult {
  _FakeResult(List<Map<String, Object?>> rows)
    : super([for (final row in rows) _FakeRow(row)]);

  @override
  int get affectedRowCount => length;

  @override
  DatabaseResultSchema get schema =>
      throw UnsupportedError('The fake result has no schema.');
}

/// A savepoint that remembers how it ended.
final class FakeSavepoint implements Savepoint {
  /// Creates savepoint number [number].
  FakeSavepoint(this.number, {this.failRollback = false});

  /// Order of creation, from 1.
  final int number;

  /// Whether rolling back should fail.
  final bool failRollback;

  /// Whether [release] ran.
  bool released = false;

  /// Whether [rollback] ran.
  bool rolledBack = false;

  @override
  String get id => 'sp$number';

  @override
  Future<void> release() async => released = true;

  @override
  Future<void> rollback() async {
    if (failRollback) throw StateError('connection lost');
    rolledBack = true;
  }
}

/// A transaction that hands out [FakeSavepoint]s.
final class FakeTransaction implements Transaction {
  /// Whether savepoints it creates fail to roll back.
  bool failSavepointRollback = false;

  /// Every savepoint created on it, in order.
  final List<FakeSavepoint> savepoints = [];

  @override
  Future<Savepoint> createSavepoint() async {
    final savepoint = FakeSavepoint(
      savepoints.length + 1,
      failRollback: failSavepointRollback,
    );
    savepoints.add(savepoint);
    return savepoint;
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A [Database] that records statements and replays canned results.
final class FakeDatabase implements Database {
  /// Waits this long before answering a statement, so two requests overlap.
  Duration latency = Duration.zero;

  /// Rows returned by the next `unsafeQuery` calls, one list per call.
  final List<List<Map<String, Object?>>> queryReplies = [];

  /// The count `unsafeExecute` returns.
  int executeReply = 1;

  /// Thrown by the next statement, then cleared.
  Object? failNextStatement;

  /// Thrown by a transaction after its callback returned (a COMMIT error).
  Object? failCommit;

  /// Every statement received, in order.
  final List<RecordedStatement> statements = [];

  /// Every transaction opened, in order.
  final List<FakeTransaction> transactions = [];

  @override
  Future<DatabaseResult> unsafeQuery(
    String query, {
    int? timeoutInSeconds,
    Transaction? transaction,
    QueryParameters? parameters,
  }) async {
    _record(query, timeoutInSeconds, transaction, parameters);
    await Future<void>.delayed(latency);
    return _FakeResult(
      queryReplies.isEmpty ? const [] : queryReplies.removeAt(0),
    );
  }

  @override
  Future<int> unsafeExecute(
    String query, {
    int? timeoutInSeconds,
    Transaction? transaction,
    QueryParameters? parameters,
  }) async {
    _record(query, timeoutInSeconds, transaction, parameters);
    return executeReply;
  }

  @override
  Future<R> transaction<R>(
    TransactionFunction<R> transactionFunction, {
    TransactionSettings? settings,
  }) async {
    final transaction = FakeTransaction();
    transactions.add(transaction);
    final result = await transactionFunction(transaction);
    if (failCommit case final Object error) {
      throw error;
    }
    return result;
  }

  void _record(
    String query,
    int? timeoutInSeconds,
    Transaction? transaction,
    QueryParameters? parameters,
  ) {
    statements.add(
      RecordedStatement(
        sql: query,
        parameters: switch (parameters?.parameters) {
          final List<Object?> positional => positional,
          _ => null,
        },
        transaction: transaction,
        timeoutInSeconds: timeoutInSeconds,
      ),
    );
    if (failNextStatement case final Object error) {
      failNextStatement = null;
      throw error;
    }
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A [Session] over a [FakeDatabase], with a log to read back.
final class FakeSession implements Session {
  /// Creates a session; [authenticated] `null` is an anonymous caller.
  FakeSession({FakeDatabase? database, this.authenticated})
    : fakeDatabase = database ?? FakeDatabase();

  /// The database behind [db].
  final FakeDatabase fakeDatabase;

  @override
  AuthenticationInfo? authenticated;

  /// Every message logged, with its level.
  final List<({String message, LogLevel? level, Object? exception})> logs = [];

  @override
  Database get db => fakeDatabase;

  @override
  void log(
    String message, {
    LogLevel? level,
    Object? exception,
    StackTrace? stackTrace,
    Map<String, Object?>? metadata,
  }) => logs.add((message: message, level: level, exception: exception));

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A signed-in caller holding [scopeNames].
AuthenticationInfo signedIn(
  Set<String> scopeNames, {
  String userIdentifier = 'user-1',
}) => AuthenticationInfo(userIdentifier, {
  for (final name in scopeNames) Scope(name),
}, authId: 'auth-1');
