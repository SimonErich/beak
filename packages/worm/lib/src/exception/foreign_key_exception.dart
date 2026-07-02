/// Exception for foreign key constraint violations.
library;

import 'adapter_exception.dart';

/// Thrown when a foreign key constraint is violated.
class ForeignKeyException extends AdapterException {
  /// Creates a [ForeignKeyException].
  const ForeignKeyException({
    required this.table,
    required this.column,
    required String message,
  }) : super(message);

  /// The table where the violation occurred.
  final String table;

  /// The column with the foreign key constraint.
  final String column;

  @override
  Map<String, Object?> get context => <String, Object?>{
    'table': table,
    'column': column,
  };

  @override
  String toString() =>
      'ForeignKeyException: $message (table: $table, column: $column)';
}
