/// MongoDB error → typed `WormException` mapping.
library;

import 'package:mongo_dart/mongo_dart.dart';
import 'package:worm/worm.dart';

/// Translates errors thrown by the `mongo_dart` driver into the
/// worm package's typed [WormException] hierarchy.
///
/// Stateless — every method is `static` — so callers can map an
/// exception without allocating an instance.
///
/// ## Recognised codes
///
/// - `11000` duplicate-key → [UniqueConstraintException]
///   (collection name flows into the `table` field)
/// - Any other [MongoDartError] → [QueryException] preserving the
///   original `message`
/// - Any other thrown object → [QueryException] with `toString()`
///   as the message
///
/// `WormException`s thrown by inner code are never re-wrapped: they
/// pass through [wrap] untouched.
final class MongoErrorMapper {
  const MongoErrorMapper._();

  /// Maps an arbitrary thrown [error] into a [WormException].
  static WormException map(
    Object error, {
    String table = 'unknown',
    String query = '',
  }) {
    if (error is WormException) return error;
    if (error is MongoDartError) {
      return fromCode(
        error.mongoCode,
        message: error.message,
        table: table,
        query: query,
      );
    }
    return QueryException(query: query, message: error.toString());
  }

  /// Maps a driver-side write-command failure to a typed
  /// [WormException].
  ///
  /// Accepts the raw `code` + `errmsg` pair MongoDB emits for any
  /// `WriteCommandError` (the structural shape of `mongo_dart`'s
  /// `WriteError`, which isn't a public export). This lets the
  /// adapter forward a failure picked off a `WriteResult` without
  /// owning a typed reference to the driver-internal class.
  static WormException fromWriteCommandError({
    required int? code,
    required String? errmsg,
    String table = 'unknown',
    String query = '',
  }) => fromCode(
    code,
    message: errmsg ?? 'mongo write error',
    table: table,
    query: query,
  );

  /// Pure code-based mapping.
  ///
  /// Exposed so unit tests can exercise every mapping branch
  /// without constructing a driver-side error object.
  static WormException fromCode(
    int? code, {
    String message = '',
    String table = 'unknown',
    String query = '',
  }) {
    if (code == 11000) {
      return UniqueConstraintException(
        table: table,
        column: '',
        message: message,
      );
    }
    return QueryException(query: query, message: message);
  }

  /// Awaits [action] and rethrows any thrown error as the matching
  /// typed [WormException].
  ///
  /// Pre-existing `WormException`s pass through untouched.
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
