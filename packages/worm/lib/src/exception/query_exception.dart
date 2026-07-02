/// Exception for query execution failures.
library;

import 'adapter_exception.dart';

/// Thrown when a database query fails to execute.
class QueryException extends AdapterException {
  /// Creates a [QueryException].
  const QueryException({
    required this.query,
    required String message,
    this.nativeError,
    this.table,
  }) : super(message);

  /// The query string that failed.
  final String query;

  /// Optional error from the underlying driver.
  final String? nativeError;

  /// The table targeted by the query, when known.
  final String? table;

  @override
  Map<String, Object?> get context => <String, Object?>{
    'table': table,
    'query': query,
    'nativeError': nativeError,
  };

  @override
  String toString() {
    final parts = <String>[];
    final tableName = table;
    if (tableName != null) parts.add('table: $tableName');
    parts.add('query: $query');
    final err = nativeError;
    if (err != null) parts.add('nativeError: $err');
    return 'QueryException: $message (${parts.join(', ')})';
  }
}
