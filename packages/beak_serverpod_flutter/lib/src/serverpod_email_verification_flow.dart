import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart';

import 'serverpod_auth_errors.dart';

/// One email verification attempt; request tokens never enter the widget layer.
class ServerpodEmailVerificationFlow implements BeakEmailVerificationFlow {
  /// Registers when [onRegistered] is supplied, otherwise resets a password.
  ServerpodEmailVerificationFlow({
    required this.endpoint,
    required this.errors,
    this.onRegistered,
  });

  /// Existing generated email endpoint.
  final EndpointEmailIdpBase endpoint;

  /// Shared typed error boundary.
  final ServerpodAuthErrors errors;

  /// Commits a registered identity through the same permission resolution.
  final Future<BeakResult<void>> Function(AuthSuccess auth)? onRegistered;
  UuidValue? _requestId;
  String? _verifiedToken;
  bool _disposed = false;
  int _generation = 0;

  @override
  Future<BeakResult<void>> start({required String email}) async {
    if (_disposed) return _invalid;
    final generation = ++_generation;
    _requestId = null;
    _verifiedToken = null;
    final result = await errors.run(
      () => onRegistered == null
          ? endpoint.startPasswordReset(email: email.trim())
          : endpoint.startRegistration(email: email.trim()),
    );
    if (_disposed || generation != _generation) return _invalid;
    return switch (result) {
      BeakErr(:final error) => BeakErr(error),
      BeakOk(:final value) => _rememberRequest(value),
    };
  }

  BeakResult<void> _rememberRequest(UuidValue id) {
    _requestId = id;
    return const BeakOk(null);
  }

  @override
  Future<BeakResult<void>> verify({required String code}) async {
    final id = _requestId;
    if (_disposed || id == null) return _invalid;
    final generation = _generation;
    final result = await errors.run(
      () => onRegistered == null
          ? endpoint.verifyPasswordResetCode(
              passwordResetRequestId: id,
              verificationCode: code.trim(),
            )
          : endpoint.verifyRegistrationCode(
              accountRequestId: id,
              verificationCode: code.trim(),
            ),
    );
    if (_disposed || generation != _generation) return _invalid;
    return switch (result) {
      BeakErr(:final error) => BeakErr(error),
      BeakOk(:final value) => _rememberToken(value),
    };
  }

  BeakResult<void> _rememberToken(String token) {
    _verifiedToken = token;
    return const BeakOk(null);
  }

  @override
  Future<BeakResult<void>> complete({required String password}) async {
    final token = _verifiedToken;
    if (_disposed || token == null) return _invalid;
    final generation = _generation;
    final register = onRegistered;
    if (register == null) {
      final result = await errors.run(
        () => endpoint.finishPasswordReset(
          finishPasswordResetToken: token,
          newPassword: password,
        ),
      );
      if (_disposed || generation != _generation) return _invalid;
      if (result.isOk) dispose();
      return result;
    }
    final result = await errors.run(
      () => endpoint.finishRegistration(
        registrationToken: token,
        password: password,
      ),
    );
    if (_disposed || generation != _generation) return _invalid;
    switch (result) {
      case BeakErr(:final error):
        return BeakErr(error);
      case BeakOk(:final value):
        dispose();
        return register(value);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _requestId = null;
    _verifiedToken = null;
  }

  static const BeakResult<void> _invalid = BeakErr(
    BeakValidationException('Start a new email verification request.'),
  );
}
