import 'package:beak_core/beak_core.dart';
import 'package:signals/signals.dart';

import 'beak_auth_adapter.dart';

/// Holds the panel's signed-in session for the lifetime of the app.
///
/// Registered as a singleton by `registerBeakDependencies`, which also points
/// the [BeakClient]'s token provider at it — so signing in through
/// [BeakSessionStore.signIn] authenticates every later request without any
/// wiring in between.
///
/// ```dart
/// final store = beakDependencies(context)<BeakSessionStore>();
/// await store.signIn(username: email, password: password);
/// ```
final class BeakSessionStore extends BeakAuthAdapter {
  /// Creates an empty store over [client].
  BeakSessionStore(this.client);

  /// The client sessions are minted through.
  final BeakClient client;

  final Signal<BeakSession?> _session = signal(null);
  final Signal<BeakAuthState> _state = signal(const BeakAuthGuest());
  int _authIntent = 0;

  @override
  ReadonlySignal<BeakAuthState> get state => _state;

  /// The current session, or null while signed out.
  ReadonlySignal<BeakSession?> get session => _session;

  /// The bearer token of the current session, for `BeakClient`.
  String? get token => _session.value?.token;

  /// Whether someone is signed in.
  bool get isSignedIn => _session.value != null;

  /// Signs in and remembers the session.
  ///
  /// Returns whether authentication completed. Use [login] when the caller
  /// needs to distinguish credential rejection from another typed failure.
  Future<bool> signIn({
    required String username,
    required String password,
  }) async {
    return (await login(email: username, password: password)).isOk;
  }

  @override
  Future<BeakResult<void>> login({
    required String email,
    required String password,
  }) async {
    final intent = ++_authIntent;
    try {
      final session = await client.login(username: email, password: password);
      if (intent != _authIntent) {
        return const BeakErr(
          BeakConfigurationException('Authentication operation superseded.'),
        );
      }
      _session.value = session;
      _state.value = BeakAuthAuthenticated(
        BeakAuthIdentity(id: session.principalId),
      );
      return const BeakOk(null);
    } on BeakException catch (error) {
      return BeakErr(error);
    } on Exception {
      return const BeakErr(
        BeakConfigurationException('Authentication transport failed.'),
      );
    }
  }

  @override
  Future<BeakResult<void>> refresh() async => const BeakOk(null);

  @override
  Future<BeakResult<void>> logout() async {
    try {
      await signOut();
      return const BeakOk(null);
    } on BeakException catch (error) {
      return BeakErr(error);
    } on Exception {
      return const BeakErr(
        BeakConfigurationException('Session revocation failed.'),
      );
    }
  }

  /// Ends the session, server-side included.
  Future<void> signOut() async {
    _authIntent++;
    final BeakSession? current = _session.value;
    _session.value = null;
    _state.value = const BeakAuthGuest();
    if (current != null) {
      await client.logout(current.token);
    }
  }
}
