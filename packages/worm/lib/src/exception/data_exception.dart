/// Exception for values the database refuses to store.
library;

import 'adapter_exception.dart';

/// Thrown when the database refuses a value for its size, range or format: a
/// string longer than its column allows, a number outside its type's range, a
/// text that is not a valid value of the column's type (PostgreSQL SQLSTATE
/// class `22`, MySQL "data too long" and "out of range").
///
/// The statement itself is well formed; the value in it is what the database
/// cannot hold, so a server can report it to whoever sent the value.
class DataException extends AdapterException {
  /// Creates a [DataException].
  const DataException({
    required this.table,
    required String message,
    this.column,
  }) : super(message);

  /// The table the statement wrote to, or the constraint or `unknown` when the
  /// driver names none.
  final String table;

  /// The column whose value was refused, when the driver names it.
  final String? column;

  @override
  Map<String, Object?> get context => <String, Object?>{
    'table': table,
    'column': column,
  };

  @override
  String toString() {
    final parts = <String>['table: $table'];
    final col = column;
    if (col != null) parts.add('column: $col');
    return 'DataException: $message (${parts.join(', ')})';
  }
}
