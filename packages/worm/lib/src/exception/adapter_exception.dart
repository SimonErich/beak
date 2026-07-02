/// Umbrella exception for adapter-layer failures.
library;

import 'worm_exception.dart';

/// Base type for every exception thrown from the
/// adapter layer.
///
/// Catching [AdapterException] groups connection,
/// authentication, timeout, query, constraint,
/// transaction, migration, and adapter-mismatch
/// failures into a single catch-clause. Each
/// concrete subtype still carries its own typed
/// context fields.
abstract class AdapterException extends WormException {
  /// Creates an [AdapterException] with the given
  /// [message].
  const AdapterException(super.message);
}
