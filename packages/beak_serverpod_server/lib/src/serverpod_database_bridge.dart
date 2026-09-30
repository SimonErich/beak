import 'package:serverpod/serverpod.dart'
    show
        DatabaseException,
        DatabaseQueryException,
        RollbackToSavepointFailedException,
        UuidValue;
import 'package:worm/worm.dart'
    show QueryException, TransactionException, WormException;
import 'package:worm_postgres/worm_postgres.dart' show PostgresErrorMapper;

/// SQLSTATE `query_canceled`: Postgres cancelled the statement, which is
/// how a statement timeout arrives.
const String postgresQueryCanceledCode = '57014';

/// [error] as the worm exception Beak's services catch.
///
/// Serverpod 4 has already turned the driver's error into a
/// [DatabaseQueryException] carrying the SQLSTATE, so the mapping keys on
/// that code through worm_postgres's own table: `23505` becomes a
/// `UniqueConstraintException`, `23503` a `ForeignKeyException`, `40001` and
/// `40P01` a [TransactionException], and anything else a [QueryException].
WormException mapServerpodDatabaseException(
  DatabaseException error, {
  String query = '',
}) => switch (error) {
  DatabaseQueryException(
    :final code,
    :final tableName,
    :final constraintName,
    :final columnName,
  ) =>
    PostgresErrorMapper.fromCode(
      code,
      message: code == postgresQueryCanceledCode
          ? 'Statement cancelled (timeout): ${error.message}'
          : error.message,
      table: tableName ?? '',
      constraint: constraintName ?? '',
      column: columnName ?? '',
      query: query,
      nativeError: error.toString(),
    ),
  _ => QueryException(
    query: query,
    message: error.message,
    nativeError: error.toString(),
  ),
};

/// Awaits [action], rethrowing Serverpod database errors as worm exceptions.
///
/// Wraps single statements and whole transactions alike: a transaction's
/// COMMIT can fail on its own (a deferred constraint, or a statement error
/// the callback caught and swallowed), and Serverpod raises that from
/// `db.transaction` itself, after every statement has succeeded. Anything
/// that is not a database error, including the callback's own exceptions,
/// passes through untouched.
Future<T> guardServerpodDatabase<T>(
  Future<T> Function() action, {
  String query = '',
}) async {
  try {
    return await action();
  } on DatabaseException catch (error, stackTrace) {
    Error.throwWithStackTrace(
      mapServerpodDatabaseException(error, query: query),
      stackTrace,
    );
  } on RollbackToSavepointFailedException catch (error, stackTrace) {
    Error.throwWithStackTrace(
      TransactionException(
        message:
            'Rolling back to a savepoint failed, so the transaction is in an '
            'unknown state: ${error.innerException}',
      ),
      stackTrace,
    );
  }
}

/// [value] in the storage form Serverpod's own ORM writes, as a statement
/// parameter.
///
/// Serverpod stores `DateTime` in `timestamp without time zone` as UTC, and
/// Postgres drops the offset of an untyped timestamp parameter, so a local
/// time would land shifted by the zone offset: every instant is sent as
/// UTC. `Duration` is stored as milliseconds, `UuidValue` as uuid text, and
/// `Uri` and `BigInt` as text. Enums are not converted: whether a column
/// stores the name or the index is the model's decision, not the driver's.
Object? serverpodParameterValue(Object? value) => switch (value) {
  final DateTime instant => instant.toUtc(),
  final Duration duration => duration.inMilliseconds,
  final UuidValue uuid => uuid.uuid,
  final Uri uri => uri.toString(),
  final BigInt big => big.toString(),
  _ => value,
};
