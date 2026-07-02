/// Exception for syntactically invalid queries.
library;

import 'query_exception.dart';

/// Thrown when the database driver reports a
/// syntax error in a query.
///
/// Extends [QueryException] so handlers catching
/// any query failure also catch syntax problems.
class SyntaxException extends QueryException {
  /// Creates a [SyntaxException].
  const SyntaxException({
    required super.query,
    required super.message,
    super.nativeError,
    super.table,
    this.position,
  });

  /// Byte offset within [query] where the parser
  /// reported the error, when known.
  final int? position;

  @override
  Map<String, Object?> get context => <String, Object?>{
    'table': table,
    'query': query,
    'position': position,
    'nativeError': nativeError,
  };

  @override
  String toString() {
    final parts = <String>[];
    final tableName = table;
    if (tableName != null) parts.add('table: $tableName');
    parts.add('query: $query');
    final pos = position;
    if (pos != null) parts.add('position: $pos');
    final err = nativeError;
    if (err != null) parts.add('nativeError: $err');
    return 'SyntaxException: $message (${parts.join(', ')})';
  }
}
