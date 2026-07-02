/// Exception for adapter type mismatches.
library;

import 'adapter_exception.dart';

/// Thrown when an operation is attempted on an
/// adapter that does not support it.
class AdapterMismatchException extends AdapterException {
  /// Creates an [AdapterMismatchException].
  const AdapterMismatchException({
    required this.expectedAdapter,
    required this.actualAdapter,
    required String message,
  }) : super(message);

  /// The adapter type the operation requires.
  final String expectedAdapter;

  /// The adapter type that was provided.
  final String actualAdapter;

  @override
  Map<String, Object?> get context => <String, Object?>{
    'expected': expectedAdapter,
    'actual': actualAdapter,
  };

  @override
  String toString() =>
      'AdapterMismatchException: $message '
      '(expected: $expectedAdapter, actual: $actualAdapter)';
}
