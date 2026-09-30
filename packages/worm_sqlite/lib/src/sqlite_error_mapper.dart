/// SQLite error → typed `WormException` mapping.
library;

import 'package:sqlite3/sqlite3.dart';
import 'package:worm/worm.dart';

/// Translates errors thrown by the `sqlite3` driver into the worm
/// package's typed [WormException] hierarchy.
///
/// Stateless — every method is `static`.
///
/// ## Recognised extended result codes
///
/// - `2067` / `1555` UNIQUE / PRIMARY KEY → [UniqueConstraintException]
/// - `787` FOREIGN KEY → [ForeignKeyException]
/// - any other constraint failure (primary code `19`) whose message is
///   `FOREIGN KEY constraint failed` → [ForeignKeyException]; SQLite reports
///   an `ON DELETE RESTRICT` refusal as `1811`, not `787`
/// - `275` CHECK / `1299` NOT NULL → [CheckConstraintException]
/// - any other [SqliteException] → [QueryException]
/// - any other thrown object → [QueryException] with `toString()`
///
/// `WormException`s thrown by inner code pass through [wrap] untouched.
final class SqliteErrorMapper {
  const SqliteErrorMapper._();

  /// SQLite extended result code for a UNIQUE constraint violation.
  static const int constraintUnique = 2067;

  /// SQLite extended result code for a PRIMARY KEY violation.
  static const int constraintPrimaryKey = 1555;

  /// SQLite extended result code for a FOREIGN KEY violation.
  static const int constraintForeignKey = 787;

  /// SQLite extended result code for a CHECK constraint violation.
  static const int constraintCheck = 275;

  /// SQLite extended result code for a NOT NULL constraint violation.
  static const int constraintNotNull = 1299;

  /// SQLite primary result code shared by every constraint failure.
  static const int constraintPrimary = 19;

  static const String _foreignKeyMessage = 'FOREIGN KEY constraint failed';

  static final RegExp _notNullPattern = RegExp(
    r'NOT NULL constraint failed: (\w+)\.(\w+)',
  );

  /// Maps an arbitrary thrown [error] into a [WormException].
  static WormException map(
    Object error, {
    String table = 'unknown',
    String query = '',
  }) {
    if (error is WormException) return error;
    if (error is SqliteException) {
      final code = error.extendedResultCode;
      if (code == constraintUnique || code == constraintPrimaryKey) {
        return UniqueConstraintException(
          table: table,
          column: '',
          message: error.message,
        );
      }
      if (code == constraintForeignKey ||
          (error.resultCode == constraintPrimary &&
              error.message == _foreignKeyMessage)) {
        return ForeignKeyException(
          table: table,
          column: '',
          message: error.message,
        );
      }
      if (code == constraintNotNull) {
        final match = _notNullPattern.firstMatch(error.message);
        return CheckConstraintException(
          table: match?[1] ?? table,
          column: match?[2],
          message: error.message,
        );
      }
      if (code == constraintCheck) {
        return CheckConstraintException(table: table, message: error.message);
      }
      return QueryException(query: query, message: error.message);
    }
    return QueryException(query: query, message: error.toString());
  }

  /// Runs [action] and rethrows any thrown error as the matching typed
  /// [WormException]. Pre-existing `WormException`s pass through.
  static Future<T> wrap<T>(
    Future<T> Function() action, {
    String table = 'unknown',
    String query = '',
  }) async {
    try {
      return await action();
    } on WormException {
      rethrow;
    } catch (error) {
      throw map(error, table: table, query: query);
    }
  }
}
