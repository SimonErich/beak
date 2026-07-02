/// Result of running a single validation rule.
library;

/// Outcome of evaluating a `ValidationRule` against a value.
///
/// A result is either valid or carries an error message describing
/// why the value was rejected.
final class ValidationResult {
  /// Creates a successful validation result.
  const ValidationResult.valid() : message = null;

  /// Creates a failing validation result with the given [message].
  const ValidationResult.invalid(String this.message);

  /// The error message when invalid, or `null` when valid.
  final String? message;

  /// Whether this result represents a successful validation.
  bool get isValid => message == null;

  /// Whether this result represents a failed validation.
  bool get isInvalid => message != null;
}
