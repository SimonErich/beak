/// Exception for queries that risk full table scans.
library;

import 'worm_exception.dart';

/// Thrown when a query would perform an unsafe
/// operation such as a full table scan.
///
/// The spec refers to this concept as
/// `DangerousQueryException`; that name is exposed
/// as a typedef alias in
/// `dangerous_query_exception.dart`, so the two
/// names are mutually catchable.
class FullTableScanException extends WormException {
  /// Creates a [FullTableScanException].
  const FullTableScanException({
    required this.table,
    required String message,
    this.queryHint,
  }) : super(message);

  /// The table targeted by the dangerous query.
  final String table;

  /// Optional hint describing how to fix the query.
  final String? queryHint;

  @override
  Map<String, Object?> get context => <String, Object?>{
    'table': table,
    'hint': queryHint,
  };

  @override
  String toString() {
    final hint = queryHint;
    if (hint == null) {
      return 'FullTableScanException: $message (table: $table)';
    }
    return 'FullTableScanException: $message '
        '(table: $table, hint: $hint)';
  }
}
