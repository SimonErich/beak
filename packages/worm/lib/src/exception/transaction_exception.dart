/// Exception for transaction failures.
library;

import 'adapter_exception.dart';

/// Thrown when a database transaction fails.
class TransactionException extends AdapterException {
  /// Creates a [TransactionException].
  const TransactionException({required String message, this.savepointName})
    : super(message);

  /// Optional savepoint name, if the failure
  /// occurred within a nested savepoint.
  final String? savepointName;

  @override
  Map<String, Object?> get context => <String, Object?>{
    'savepoint': savepointName,
  };

  @override
  String toString() {
    final savepoint = savepointName;
    if (savepoint == null) return 'TransactionException: $message';
    return 'TransactionException: $message (savepoint: $savepoint)';
  }
}
