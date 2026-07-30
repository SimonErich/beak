import 'package:beak_core/beak_core.dart';
import 'package:signals/signals.dart';

/// Holds the panel's signed-in session for the lifetime of the app.
///
/// Registered as a singleton by `registerBeakDependencies`, which also points
/// the [BeakClient]'s token provider at it — so signing in through
/// [BeakSessionStore.signIn] authenticates every later request without any
/// wiring in between.
///
/// ```dart
/// final store = beakLocator<BeakSessionStore>();
/// await store.signIn(username: email, password: password);
/// ```
final class BeakSessionStore {
  /// Creates an empty store over [client].
  BeakSessionStore(this.client);

  /// The client sessions are minted through.
  final BeakClient client;

  final Signal<BeakSession?> _session = signal(null);

  /// The current session, or null while signed out.
  ReadonlySignal<BeakSession?> get session => _session;

  /// The bearer token of the current session, for `BeakClient`.
  String? get token => _session.value?.token;

  /// Whether someone is signed in.
  bool get isSignedIn => _session.value != null;

  /// Signs in and remembers the session.
  ///
  /// Returns false when the backend rejects the credentials, which is what an
  /// auth screen's `onLogin` wants; any other failure still throws, because a
  /// broken server is not a wrong password.
  Future<bool> signIn({
    required String username,
    required String password,
  }) async {
    try {
      _session.value = await client.login(
        username: username,
        password: password,
      );
      return true;
    } on BeakAuthenticationException {
      _session.value = null;
      return false;
    }
  }

  /// Ends the session, server-side included.
  Future<void> signOut() async {
    final BeakSession? current = _session.value;
    _session.value = null;
    if (current != null) {
      await client.logout(current.token);
    }
  }
}
