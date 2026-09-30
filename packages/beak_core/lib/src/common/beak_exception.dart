import 'package:meta/meta.dart';

/// Base type of every failure Beak raises across its layers.
///
/// The hierarchy is sealed so exception-to-response mapping (in
/// `beak_backend`'s Shelf handlers) can be an exhaustive switch. Every
/// exception carries a stable machine-readable [code] for wire formats and a
/// human-readable [message].
///
/// Because the type is sealed, a translator switch is checked for
/// completeness at compile time — adding a new variant forces every mapper to
/// handle it:
///
/// ```dart
/// int httpStatus(BeakException exception) => switch (exception) {
///   BeakValidationException() => 422,
///   BeakNotFoundException() => 404,
///   BeakAuthenticationException() => 401,
///   BeakAuthorizationException() => 403,
///   BeakConflictException() => 409,
///   BeakConfigurationException() => 500,
///   BeakStorageException() => 500,
///   BeakInternalException() => 500,
///   BeakPayloadTooLargeException() => 413,
///   BeakTransportException() => 502,
/// };
/// ```
// --8<-- [start:BeakException]
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
// --8<-- [end:BeakException]

// --8<-- [start:BeakValidationException]
/// Raised when user-supplied data violates one or more column rules.
///
/// [fieldErrors] maps a column key to its messages, so a form can highlight
/// the offending inputs individually:
///
/// ```dart
/// throw const BeakValidationException(
///   'The product could not be saved.',
///   fieldErrors: {
///     'price': ['Must be greater than 0'],
///     'sku': ['Already taken'],
///   },
/// );
/// ```
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
// --8<-- [end:BeakValidationException]

// --8<-- [start:BeakOtherExceptions]
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

/// Raised when the server failed in a way it does not describe: an unexpected
/// error behind an opaque `500`, or a gateway's `5xx` with no Beak body.
///
/// This is the server's fault, never the caller's configuration. The message
/// is safe to show: the server keeps the real cause to itself.
final class BeakInternalException extends BeakException {
  /// Creates an internal failure described by [message].
  const BeakInternalException(String message)
    : super(code: 'internal', message: message);
}

/// Raised when a request body is larger than the server accepts (HTTP 413),
/// for example an upload above the size cap of a proxy or of the host.
final class BeakPayloadTooLargeException extends BeakException {
  /// Creates a size-limit failure described by [message].
  const BeakPayloadTooLargeException(String message)
    : super(code: 'payload_too_large', message: message);
}

/// Raised when a response never reached Beak's own error format and no more
/// specific type fits: an unexpected status, or a tunnel that failed on the
/// way (for example a Serverpod gate answering before Beak's API ran).
final class BeakTransportException extends BeakException {
  /// Creates a transport failure described by [message].
  const BeakTransportException(String message)
    : super(code: 'transport', message: message);
}
// --8<-- [end:BeakOtherExceptions]

/// Raised when a record does not carry the value a column requires — the
/// column is absent, null, or holds a shape the column cannot read.
///
/// Thrown by `BeakTypedColumn.require`, which is the strict counterpart of
/// `readFrom`. Reach for `readFrom` when absence is legitimate; `require`
/// exists so a column carrying [BeakRequired] fails loudly and namefully
/// instead of yielding `null` far from the cause.
final class BeakRecordShapeException extends BeakConfigurationException {
  /// Creates a shape failure for [columnKey], which expected [expectedType].
  BeakRecordShapeException({
    required this.columnKey,
    required this.expectedType,
  }) : super(
         'Column "$columnKey" has no readable $expectedType value on this '
         'record. It is absent, null, or of an unexpected shape — check that '
         'the query selected it and that the row supplies it.',
       );

  /// Key of the column whose value could not be read.
  final String columnKey;

  /// The Dart type the column reads its values as.
  final Type expectedType;
}
