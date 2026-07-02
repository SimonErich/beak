/// Exception for unique constraint violations.
library;

import 'adapter_exception.dart';

/// Thrown when a database unique constraint is
/// violated.
class UniqueConstraintException extends AdapterException {
  /// Creates a [UniqueConstraintException].
  const UniqueConstraintException({
    required this.table,
    required this.column,
    required String message,
  }) : super(message);

  /// The table where the violation occurred.
  final String table;

  /// The column with the unique constraint.
  final String column;

  @override
  Map<String, Object?> get context => <String, Object?>{
    'table': table,
    'column': column,
  };

  @override
  String toString() =>
      'UniqueConstraintException: $message '
      '(table: $table, column: $column)';
}
