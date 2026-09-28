import 'package:beak_core/beak_core.dart';
import 'package:signals/signals.dart';

import '../state/beak_view_model.dart';
import 'beak_auth_adapter.dart';

/// The visible step of an email verification form.
enum BeakAuthStep {
  /// The email address to verify.
  email,

  /// The verification code sent to that email address.
  verify,

  /// The new password after successful verification.
  password,
}

/// Owns pending/error state for backend-neutral authentication forms.
final class BeakAuthViewModel extends BeakViewModel {
  /// Uses [adapter] for login, optionally owning an email verification [flow].
  BeakAuthViewModel({required this.adapter, this.flow});

  /// Existing session authority; this view model does not dispose it.
  final BeakAuthAdapter adapter;

  /// Transient verification flow owned by this form.
  final BeakEmailVerificationFlow? flow;
  late final _busy = ownedSignal(false);
  late final _error = ownedSignal<BeakException?>(null);
  late final _step = ownedSignal(BeakAuthStep.email);

  /// Whether an operation is in flight.
  ReadonlySignal<bool> get busy => _busy;

  /// Latest typed failure, cleared when retrying.
  ReadonlySignal<BeakException?> get error => _error;

  /// Current email verification step.
  ReadonlySignal<BeakAuthStep> get step => _step;

  /// Ends the device session through the same typed pending/error boundary.
  Future<bool> logout() => _run(adapter.logout);

  /// Signs in with a normalized email and the exact supplied password.
  Future<bool> login({required String email, required String password}) async {
    if (!_validEmail(email) || !_required(password)) return false;
    return _run(() => adapter.login(email: email.trim(), password: password));
  }

  /// Starts verification or resends a code for this email.
  Future<void> start(String email) async {
    if (!_validEmail(email)) return;
    if (await _run(() => _requireFlow.start(email: email.trim()))) {
      _step.value = BeakAuthStep.verify;
    }
  }

  /// Advances only after the backend accepts the verification code.
  Future<void> verify(String code) async {
    if (!_required(code.trim())) return;
    if (await _run(() => _requireFlow.verify(code: code.trim()))) {
      _step.value = BeakAuthStep.password;
    }
  }

  /// Completes registration or recovery with a new password.
  Future<bool> complete(String password, {String? confirmation}) async {
    if (!_required(password)) return false;
    if (confirmation != null && password != confirmation) {
      return _failed(
        const BeakValidationException(
          'Passwords differ.',
          fieldErrors: {
            'confirmation': ['mismatch'],
          },
        ),
      );
    }
    return _run(() => _requireFlow.complete(password: password));
  }

  bool _validEmail(String email) =>
      _required(email.trim()) &&
      (const BeakEmail().validate(email.trim()) == null ||
          _failed(
            const BeakValidationException(
              'Invalid email.',
              fieldErrors: {
                'email': ['invalid'],
              },
            ),
          ));

  bool _required(String value) =>
      value.isNotEmpty ||
      _failed(const BeakValidationException('A required value is missing.'));

  BeakEmailVerificationFlow get _requireFlow =>
      flow ?? (throw StateError('This authentication form has no email flow.'));

  Future<bool> _run(Future<BeakResult<void>> Function() operation) async {
    if (isDisposed || _busy.value) return false;
    _busy.value = true;
    _error.value = null;
    final result = await operation();
    if (isDisposed) return false;
    _busy.value = false;
    return switch (result) {
      BeakOk() => true,
      BeakErr(:final error) => _failed(error),
    };
  }

  bool _failed(BeakException error) {
    _error.value = error;
    return false;
  }

  @override
  void dispose() {
    flow?.dispose();
    super.dispose();
  }
}
