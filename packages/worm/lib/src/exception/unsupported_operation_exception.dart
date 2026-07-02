/// Exception for unsupported adapter / driver
/// operations.
library;

import 'worm_exception.dart';

/// Thrown when an operation is requested that the
/// current adapter (or runtime) does not support.
///
/// Distinct from `ConfigurationException`: that
/// signals a misconfigured option; this signals
/// that the option is genuinely unavailable in the
/// current backend.
class UnsupportedOperationException extends WormException {
  /// Creates an [UnsupportedOperationException].
  const UnsupportedOperationException({
    required this.operation,
    required String message,
    this.adapter,
  }) : super(message);

  /// The operation name that was rejected.
  final String operation;

  /// The adapter that rejected the operation, when
  /// known.
  final String? adapter;

  @override
  Map<String, Object?> get context => <String, Object?>{
    'operation': operation,
    'adapter': adapter,
  };

  @override
  String toString() {
    final adapterName = adapter;
    if (adapterName == null) {
      return 'UnsupportedOperationException: $message '
          '(operation: $operation)';
    }
    return 'UnsupportedOperationException: $message '
        '(operation: $operation, adapter: $adapterName)';
  }
}
