/// Exception for cancelled operations.
library;

import 'worm_exception.dart';

/// Thrown to propagate hook cancellation in-band.
///
/// When a `before*` lifecycle hook signals
/// cancellation, the runtime throws an
/// [OperationCancelledException] to abort the
/// surrounding operation while preserving the
/// [hook] that requested the cancellation.
///
/// Extends [WormException] directly because hook
/// cancellation is a cross-cutting concern that can
/// originate from model lifecycle hooks, adapter
/// transaction hooks, or migration hooks alike.
class OperationCancelledException extends WormException {
  /// Creates an [OperationCancelledException].
  const OperationCancelledException({
    required this.operation,
    required String message,
    this.hook,
  }) : super(message);

  /// Operation kind (e.g. `save`, `delete`,
  /// `restore`).
  final String operation;

  /// The lifecycle hook that requested the
  /// cancellation, when known.
  final String? hook;

  @override
  Map<String, Object?> get context => <String, Object?>{
    'operation': operation,
    'hook': hook,
  };

  @override
  String toString() {
    final hookName = hook;
    if (hookName == null) {
      return 'OperationCancelledException: $message '
          '(operation: $operation)';
    }
    return 'OperationCancelledException: $message '
        '(operation: $operation, hook: $hookName)';
  }
}
