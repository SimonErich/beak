/// Exception for check constraint violations.
library;

import 'adapter_exception.dart';

/// Thrown when a `CHECK` or `NOT NULL` constraint is violated: the row breaks
/// a rule the table declares about its own values.
class CheckConstraintException extends AdapterException {
  /// Creates a [CheckConstraintException].
  const CheckConstraintException({
    required this.table,
    required String message,
    this.column,
    this.constraintName,
  }) : super(message);

  /// The table where the violation occurred.
  final String table;

  /// The column targeted by the constraint, when
  /// known.
  final String? column;

  /// The name of the violated check constraint,
  /// when known.
  final String? constraintName;

  @override
  Map<String, Object?> get context => <String, Object?>{
    'table': table,
    'column': column,
    'constraintName': constraintName,
  };

  @override
  String toString() {
    final parts = <String>['table: $table'];
    final col = column;
    if (col != null) parts.add('column: $col');
    final name = constraintName;
    if (name != null) parts.add('constraintName: $name');
    return 'CheckConstraintException: $message (${parts.join(', ')})';
  }
}
