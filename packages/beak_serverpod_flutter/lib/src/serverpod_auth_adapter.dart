import 'dart:async';

import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart';
import 'package:signals/signals.dart';

import 'serverpod_auth_errors.dart';
import 'serverpod_email_verification_flow.dart';

/// Resolves host account/permissions into an identity after each auth transition.
typedef ServerpodIdentityResolver =
    Future<BeakAuthIdentity?> Function(bool signedIn);

/// Beak authentication over an existing Serverpod client and session manager.
///
/// This adapter owns no credentials: Serverpod retains secure storage and token
/// refresh. The host contributes only its identity/permission projection and
/// mapping for domain-specific serialized exceptions.
class ServerpodAuthAdapter extends BeakAuthAdapter {
  /// Attaches to [sessionManager]; call [initialize] after host DI is ready.
  ServerpodAuthAdapter({
    required this.client,
    required this.sessionManager,
    this.resolveIdentity,
    ServerpodAuthExceptionMapper? exceptionMapper,
    this.isUnauthenticated,
  }) : _errors = ServerpodAuthErrors(exceptionMapper) {
    sessionManager.authInfoListenable.addListener(_onAuthChanged);
  }

  /// The same generated client used by the host's authenticated resources.
  final ServerpodClientShared client;

  /// Existing Serverpod credential/session authority.
  final FlutterAuthSessionManager sessionManager;

  /// Host account/permission mapping; subclasses of BeakAuthIdentity are retained.
  final ServerpodIdentityResolver? resolveIdentity;

  /// Recognizes host-generated unauthenticated errors in addition to HTTP 401.
  final bool Function(Object error)? isUnauthenticated;
  final ServerpodAuthErrors _errors;
  final Signal<BeakAuthState> _state = signal(const BeakAuthLoading());
  Future<BeakResult<void>>? _pending;
  Future<void> _sessionMutation = Future.value();
  int _sessionMutations = 0;
  UuidValue? _lastUserId;
  bool _initialized = false;
  bool _disposed = false;
  int _resolution = 0;
  int _authIntent = 0;

  @override
  ReadonlySignal<BeakAuthState> get state => _state;

  /// Resolves the stored session once, after host dependencies are installed.
  Future<BeakResult<void>> initialize() => _resolve(force: !_initialized);

  EndpointEmailIdpBase get _email =>
      client.getEndpointOfType<EndpointEmailIdpBase>();

  @override
  Future<BeakResult<void>> login({
    required String email,
    required String password,
  }) async {
    final intent = ++_authIntent;
    final result = await _errors.run(
      () => _email.login(email: email.trim(), password: password),
    );
    if (_disposed || intent != _authIntent) return _cancelled;
    return switch (result) {
      BeakErr(:final error) => BeakErr(error),
      BeakOk(:final value) => _acceptSession(value, intent),
    };
  }

  Future<BeakResult<void>> _acceptSession(AuthSuccess auth, int intent) async {
    if (_disposed || intent != _authIntent) return _cancelled;
    final update = await _mutateSession(() async {
      if (intent == _authIntent) {
        await sessionManager.updateSignedInUser(auth);
      }
    });
    if (_disposed || intent != _authIntent) return _cancelled;
    if (update is BeakErr<void>) return update;
    final resolved = await _resolve();
    if (_disposed || intent != _authIntent) return _cancelled;
    if (resolved is BeakErr<void>) return resolved;
    if (_state.value case BeakAuthAuthenticated(
      :final identity,
    ) when identity.canAccessPanel) {
      return const BeakOk(null);
    }
    await logout();
    return const BeakErr(
      BeakAuthorizationException('The account cannot access this panel.'),
    );
  }

  @override
  Future<BeakResult<void>> logout() async {
    if (_disposed) return _cancelled;
    final intent = ++_authIntent;
    _resolution++;
    _pending = null;
    _initialized = false;
    _state.value = const BeakAuthLoading();
    final revoked = await _mutateSession(() async {
      try {
        await sessionManager.signOutDevice();
      } finally {
        // Serverpod already clears locally on remote failures. Keep the same
        // guarantee with custom session-manager implementations.
        if (sessionManager.authInfoListenable.value != null) {
          await sessionManager.updateSignedInUser(null);
        }
      }
    });
    if (_disposed || intent != _authIntent) return _cancelled;
    final resolved = await _resolve();
    return resolved is BeakErr<void> ? resolved : revoked;
  }

  // Serverpod publishes credentials only after awaiting secure storage. Keep
  // writes ordered so an earlier login cannot complete after a later logout.
  Future<BeakResult<void>> _mutateSession(
    Future<void> Function() operation,
  ) async {
    final previous = _sessionMutation;
    final completed = Completer<void>();
    _sessionMutation = completed.future;
    _sessionMutations++;
    try {
      await previous;
      if (_disposed) return _cancelled;
      return await _errors.run(operation);
    } finally {
      _sessionMutations--;
      completed.complete();
    }
  }

  @override
  Future<BeakResult<void>> refresh() => _resolve(force: true);

  void _onAuthChanged() {
    if (_initialized && !_disposed && _sessionMutations == 0) {
      unawaited(_resolve());
    }
  }

  Future<BeakResult<void>> _resolve({bool force = false}) {
    if (_disposed) return Future.value(_cancelled);
    if (_sessionMutations > 0) {
      return _sessionMutation.then((_) => _resolve(force: force));
    }
    final id = sessionManager.authInfoListenable.value?.authUserId;
    if (!force && _initialized && _lastUserId == id) {
      return _pending ?? Future.value(const BeakOk(null));
    }
    _initialized = true;
    _lastUserId = id;
    final resolution = ++_resolution;
    if (!force ||
        (_state.value is! BeakAuthAuthenticated &&
            _state.value is! BeakAuthGuest)) {
      _state.value = const BeakAuthLoading();
    }
    return _pending = _performResolution(id, resolution);
  }

  Future<BeakResult<void>> _performResolution(
    UuidValue? id,
    int resolution,
  ) async {
    try {
      final resolver = resolveIdentity;
      final identity = resolver == null
          ? (id == null ? null : BeakAuthIdentity(id: id))
          : await resolver(id != null);
      if (_disposed || resolution != _resolution) return _cancelled;
      _state.value = id == null || identity == null
          ? const BeakAuthGuest()
          : BeakAuthAuthenticated(identity);
      return const BeakOk(null);
    } catch (error, stackTrace) {
      if (_disposed || resolution != _resolution) return _cancelled;
      if (id != null &&
          (error is ServerpodClientException && error.statusCode == 401 ||
              isUnauthenticated?.call(error) == true)) {
        // Await the listener's newer guest resolution, never commit this stale
        // signed-in request over it after clearing the rejected token.
        return logout();
      }
      final mapped = _errors.map(error, stackTrace);
      _state.value = BeakAuthFailure(mapped);
      return BeakErr(mapped);
    }
  }

  @override
  BeakEmailVerificationFlow Function()? get registration => () {
    final intent = _authIntent;
    return ServerpodEmailVerificationFlow(
      endpoint: _email,
      errors: _errors,
      onRegistered: (auth) => _acceptSession(auth, intent),
    );
  };

  @override
  BeakEmailVerificationFlow Function()? get recovery =>
      () => ServerpodEmailVerificationFlow(endpoint: _email, errors: _errors);

  /// Detaches the listener and ignores operations completing after teardown.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _resolution++;
    _authIntent++;
    sessionManager.authInfoListenable.removeListener(_onAuthChanged);
    _state.dispose();
  }

  static const BeakResult<void> _cancelled = BeakErr(
    BeakConfigurationException('Authentication operation superseded.'),
  );
}
