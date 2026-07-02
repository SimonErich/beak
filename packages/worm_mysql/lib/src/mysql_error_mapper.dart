/// MySQL server error-code → typed `WormException` mapping.
library;

import 'package:mysql_client_plus/exception.dart';
import 'package:worm/worm.dart';

/// Translates `mysql_client_plus` driver exceptions into the worm
/// package's typed [WormException] hierarchy.
///
/// Stateless — every method is `static`.
///
/// ## Code coverage
///
/// MySQL exposes an integer error number (not a SQLSTATE) on
/// [MySQLServerException]. The following numbers are recognised
/// explicitly; any other code falls through to [QueryException]:
///
/// - `1062` / `1169` duplicate entry        → [UniqueConstraintException]
/// - `1451` / `1452` / `1216` / `1217`
///   foreign-key violations                 → [ForeignKeyException]
/// - `1205` lock wait timeout /
///   `1213` deadlock                        → [TransactionException]
/// - `1042` / `1043` / `1045` / `2002` /
///   `2003` / `2006` / `2013` connection    → [ConnectionException]
///
/// Client-side / protocol exceptions (which carry no error number)
/// propagate as [QueryException].
final class MysqlErrorMapper {
  const MysqlErrorMapper._();

  static final RegExp _keyPattern = RegExp("for key '([^']+)'");

  /// Extracts the MySQL error number from [exception], or `null` when
  /// the exception is client-side (no server error packet).
  static int? codeOf(MySQLException exception) => switch (exception) {
    final MySQLServerException e => e.errorCode,
    _ => null,
  };

  /// Maps a [MySQLException] into a concrete [WormException].
  ///
  /// Context parameters — [query], [host], [port] — populate the typed
  /// exception fields the driver cannot supply itself.
  static WormException map(
    MySQLException exception, {
    String query = '',
    String host = '',
    int port = 0,
  }) {
    if (exception is! MySQLServerException) {
      // Client/protocol error: no server code to classify.
      return QueryException(
        query: query,
        message: exception.message,
        nativeError: exception.toString(),
      );
    }
    return fromCode(
      exception.errorCode,
      message: exception.message,
      constraint: _constraintOf(exception.message),
      query: query,
      host: host,
      port: port,
      nativeError: exception.toString(),
    );
  }

  /// Pure code-based mapping.
  ///
  /// Exposed so unit tests can exercise every branch without
  /// constructing a driver exception.
  static WormException fromCode(
    int? code, {
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
      1062 || 1169 => UniqueConstraintException(
        table: label,
        column: column,
        message: message,
      ),
      1451 || 1452 || 1216 || 1217 => ForeignKeyException(
        table: label,
        column: column,
        message: message,
      ),
      1205 || 1213 => TransactionException(message: message),
      1042 ||
      1043 ||
      1045 ||
      2002 ||
      2003 ||
      2006 ||
      2013 => ConnectionException(host: host, port: port, message: message),
      _ => QueryException(
        query: query,
        message: message,
        nativeError: nativeError,
      ),
    };
  }

  /// Awaits [action] and rethrows any [MySQLException] as the
  /// corresponding typed [WormException].
  ///
  /// Non-`MySQLException` errors propagate unchanged so callers can
  /// distinguish programmer errors from database failures.
  static Future<T> wrap<T>(
    Future<T> Function() action, {
    String query = '',
    String host = '',
    int port = 0,
  }) async {
    try {
      return await action();
    } on MySQLException catch (e) {
      throw map(e, query: query, host: host, port: port);
    }
  }

  /// Extracts the constraint / key name from a MySQL duplicate-entry
  /// message such as `Duplicate entry '1' for key 'tbl.PRIMARY'`.
  static String _constraintOf(String message) {
    final match = _keyPattern.firstMatch(message);
    return match?.group(1) ?? '';
  }

  static String _nonEmpty(String first, String second, String fallback) {
    if (first.isNotEmpty) return first;
    if (second.isNotEmpty) return second;
    return fallback;
  }
}
