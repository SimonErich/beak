/// Umbrella exception for model-layer failures.
library;

import 'worm_exception.dart';

/// Base type for every exception thrown from the
/// model layer.
///
/// Catching [ModelException] groups validation,
/// mass-assignment, model-lookup, hydration,
/// relation, cast, lazy-loading, and hook
/// cancellation failures into a single
/// catch-clause. Each concrete subtype still
/// carries its own typed context fields.
abstract class ModelException extends WormException {
  /// Creates a [ModelException] with the given
  /// [message].
  const ModelException(super.message);
}
