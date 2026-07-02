/// Captured record of a single executed query.
library;

/// One captured query execution.
///
/// Carries the parameterized statement, the bound parameter values,
/// the wall-clock duration the call took, and the number of rows the
/// query touched. Loggers consume these records.
final class QueryLog {
  /// Creates a [QueryLog] entry.
  const QueryLog({
    required this.statement,
    required this.parameters,
    required this.duration,
    required this.rowCount,
    required this.adapter,
    this.table,
  });

  /// Parameterized query text (placeholders left in place).
  final String statement;

  /// Bound parameter values, in positional order.
  final List<Object?> parameters;

  /// Total execution time as observed by the logger.
  final Duration duration;

  /// Number of rows returned (reads) or affected (writes).
  final int rowCount;

  /// Adapter type name that executed the query.
  final String adapter;

  /// Optional table name when known from the descriptor.
  final String? table;

  @override
  String toString() {
    final params = parameters.isEmpty ? '' : ' params=$parameters';
    final tbl = table == null ? '' : ' table=$table';
    return '[$adapter$tbl] $statement$params '
        '(${duration.inMicroseconds}us, $rowCount rows)';
  }
}
