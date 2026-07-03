import 'package:meta/meta.dart';

/// Base type of every failure Beak raises across its layers.
///
/// The hierarchy is sealed so exception-to-response mapping (in
/// `beak_backend`'s Shelf handlers) can be an exhaustive switch. Every
/// exception carries a stable machine-readable [code] for wire formats and a
/// human-readable [message].
@immutable
sealed class BeakException implements Exception {
  /// Creates an exception carrying a stable [code] and a [message].
  const BeakException({required this.code, required this.message});

  /// Stable machine-readable identifier of the failure category.
  final String code;

  /// Human-readable description of what went wrong.
  final String message;

  @override
  String toString() => '$runtimeType($code): $message';
}

/// Raised when user-supplied data violates one or more column rules.
final class BeakValidationException extends BeakException {
  /// Creates a validation failure with an overall [message] and optional
  /// per-field [fieldErrors].
  const BeakValidationException(String message, {this.fieldErrors = const {}})
    : super(code: 'validation', message: message);

  /// Validation messages aggregated per column key.
  final Map<String, List<String>> fieldErrors;

  @override
  String toString() => fieldErrors.isEmpty
      ? super.toString()
      : '${super.toString()} $fieldErrors';
}

/// Raised when a requested record or resource does not exist.
final class BeakNotFoundException extends BeakException {
  /// Creates a not-found failure described by [message].
  const BeakNotFoundException(String message)
    : super(code: 'not_found', message: message);
}

/// Raised when a request carries no valid identity (missing, invalid, or
/// expired credentials) — the 401 counterpart to authorization's 403.
final class BeakAuthenticationException extends BeakException {
  /// Creates an authentication failure described by [message].
  const BeakAuthenticationException(String message)
    : super(code: 'authentication', message: message);
}

/// Raised when the current user is not allowed to perform an operation.
final class BeakAuthorizationException extends BeakException {
  /// Creates an authorization failure described by [message].
  const BeakAuthorizationException(String message)
    : super(code: 'authorization', message: message);
}

/// Raised when Beak itself is set up incorrectly (missing driver, duplicate
/// column key, unregistered model, ...) — a developer error, not user input.
final class BeakConfigurationException extends BeakException {
  /// Creates a configuration failure described by [message].
  const BeakConfigurationException(String message)
    : super(code: 'configuration', message: message);
}

/// Raised when a storage driver fails to store, read, or delete a file.
final class BeakStorageException extends BeakException {
  /// Creates a storage failure described by [message].
  const BeakStorageException(String message)
    : super(code: 'storage', message: message);
}

/// Raised when an operation conflicts with existing state (duplicate unique
/// value, concurrent modification).
final class BeakConflictException extends BeakException {
  /// Creates a conflict failure described by [message].
  const BeakConflictException(String message)
    : super(code: 'conflict', message: message);
}
