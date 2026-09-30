import 'package:beak_core/beak_core.dart';
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart';

/// Translates generated application exceptions without importing their models.
typedef ServerpodAuthExceptionMapper =
    BeakException Function(Object error, StackTrace stackTrace);

/// Error boundary shared by Serverpod authentication and verification flows.
class ServerpodAuthErrors {
  /// Adds a host mapper for domain-specific serialized exceptions.
  const ServerpodAuthErrors(this.mapper);

  /// Optional host exception mapping, used after standard auth exceptions.
  final ServerpodAuthExceptionMapper? mapper;

  /// Captures auth operations as typed results; widgets never catch transports.
  Future<BeakResult<T>> run<T>(Future<T> Function() operation) async {
    try {
      return BeakOk(await operation());
    } catch (error, stackTrace) {
      return BeakErr(map(error, stackTrace));
    }
  }

  /// Maps known Serverpod errors while keeping raw infrastructure detail private.
  BeakException map(Object error, StackTrace stackTrace) => switch (error) {
    final BeakException error => error,
    EmailAccountLoginException(
      reason: EmailAccountLoginExceptionReason.tooManyAttempts,
    ) =>
      const BeakConflictException('Too many sign-in attempts.'),
    EmailAccountLoginException() => const BeakAuthenticationException(
      'Invalid credentials.',
    ),
    EmailAccountRequestException(
      reason: EmailAccountRequestExceptionReason.tooManyAttempts,
    ) ||
    EmailAccountPasswordResetException(
      reason: EmailAccountPasswordResetExceptionReason.tooManyAttempts,
    ) => const BeakConflictException('Too many verification attempts.'),
    EmailAccountRequestException() ||
    EmailAccountPasswordResetException() => const BeakValidationException(
      'The verification request or password was rejected.',
    ),
    ServerpodClientHttpException(statusCode: 401) =>
      const BeakAuthenticationException(
        'The device session is no longer valid.',
      ),
    ServerpodClientHttpException(statusCode: 403) =>
      const BeakAuthorizationException('Access denied.'),
    ServerpodClientHttpException() ||
    ServerpodClientNetworkException() ||
    ServerpodClientUnknownException() => const BeakTransportException(
      'Authentication transport failed.',
    ),
    _ =>
      mapper?.call(error, stackTrace) ??
          const BeakConfigurationException('Authentication transport failed.'),
  };
}
