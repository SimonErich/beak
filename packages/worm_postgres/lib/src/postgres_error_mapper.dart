/// PostgreSQL SQLSTATE → typed `WormException` mapping.
library;

import 'package:postgres/postgres.dart';
import 'package:worm/worm.dart';

/// Translates PostgreSQL driver exceptions into the worm package's
/// typed [WormException] hierarchy.
///
/// Stateless — every method is `static` — so callers can invoke
/// mapping without allocating an instance.
///
/// ## Code coverage
///
/// The following SQLSTATE codes are recognised explicitly. Any
/// other code (including `null`, which means the exception came
/// from the client side) falls through to [QueryException]:
///
/// - `23505` unique_violation            → [UniqueConstraintException]
/// - `23503` foreign_key_violation /
///   `23001` restrict_violation          → [ForeignKeyException]
/// - `23514` check_violation /
///   `23502` not_null_violation          → [CheckConstraintException]
/// - every code of class `22` (data
///   exception: value too long, out of
///   range, malformed text)              → [DataException]
/// - `40P01` deadlock_detected           → [TransactionException]
/// - `40001` serialization_failure       → [TransactionException]
/// - `08000` / `08001` / `08003` /
///   `08004` / `08006` / `08P01`         → [ConnectionException]
final class PostgresErrorMapper {
  const PostgresErrorMapper._();

  /// Extracts the PostgreSQL SQLSTATE from [exception].
  ///
  /// Returns `null` when the exception did not originate from the
  /// database server (for example network errors wrapped in a bare
  /// [PgException]).
  static String? codeOf(PgException exception) => switch (exception) {
    ServerException(:final code) => code,
    _ => null,
  };

  /// Maps a full [PgException] into a concrete [WormException].
  ///
  /// Context parameters — [query], [host], [port] — populate the
  /// typed exception fields that the driver cannot supply on its
  /// own. Callers (the adapter) pass whichever of these are known
  /// at the failing call site.
  static WormException map(
    PgException exception, {
    String query = '',
    String host = '',
    int port = 0,
  }) => fromCode(
    codeOf(exception),
    message: exception.message,
    table: _fieldOrEmpty(exception, (s) => s.tableName),
    constraint: _fieldOrEmpty(exception, (s) => s.constraintName),
    column: _fieldOrEmpty(exception, (s) => s.columnName),
    query: query,
    host: host,
    port: port,
    nativeError: exception.toString(),
  );

  /// Pure code-based mapping.
  ///
  /// Exposed so unit tests can exercise every mapping branch
  /// without constructing a [ServerException] — whose constructors
  /// are package-private in `package:postgres`.
  static WormException fromCode(
    String? code, {
    String message = '',
    String table = '',
    String constraint = '',
    String column = '',
    String query = '',
    String host = '',
    int port = 0,
    String? nativeError,
  }) {
    final label = _nonEmpty(table, constraint, 'unknown');
    return switch (code) {
      '23505' => UniqueConstraintException(
        table: label,
        column: column,
        message: message,
      ),
      '23503' || '23001' => ForeignKeyException(
        table: label,
        column: column,
        message: message,
      ),
      '23514' || '23502' => CheckConstraintException(
        table: label,
        column: column.isEmpty ? null : column,
        constraintName: constraint.isEmpty ? null : constraint,
        message: message,
      ),
      final String dataCode when dataCode.startsWith('22') => DataException(
        table: label,
        column: column.isEmpty ? null : column,
        message: message,
      ),
      '40001' || '40P01' => TransactionException(message: message),
      '08000' ||
      '08001' ||
      '08003' ||
      '08004' ||
      '08006' ||
      '08P01' => ConnectionException(host: host, port: port, message: message),
      _ => QueryException(
        query: query,
        message: message,
        nativeError: nativeError,
      ),
    };
  }

  /// Awaits [action] and rethrows any [PgException] as the
  /// corresponding typed [WormException].
  ///
  /// Non-`PgException` errors propagate unchanged so the caller can
  /// handle programmer errors (bad state, argument mismatch)
  /// distinctly from database failures.
  static Future<T> wrap<T>(
    Future<T> Function() action, {
    String query = '',
    String host = '',
    int port = 0,
  }) async {
    try {
      return await action();
    } on PgException catch (e) {
      throw map(e, query: query, host: host, port: port);
    }
  }

  static String _nonEmpty(String first, String second, String fallback) {
    if (first.isNotEmpty) return first;
    if (second.isNotEmpty) return second;
    return fallback;
  }

  static String _fieldOrEmpty(
    PgException exception,
    String? Function(ServerException) extractor,
  ) => switch (exception) {
    final ServerException s => extractor(s) ?? '',
    _ => '',
  };
}
