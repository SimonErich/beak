import 'dart:math';

import 'beak_auth_guard.dart';

/// Server-side storage for opaque session tokens — swappable so a
/// database-backed implementation can replace the in-memory default.
///
/// [BeakAuthSessions] mints tokens into a store on login and
/// [TokenSessionAuthGuard] reads them back on every request; implement this
/// interface to persist sessions across restarts (e.g. in Redis or a table)
/// instead of the process-memory [InMemoryTokenSessionStore].
abstract interface class TokenSessionStore {
  /// Mints a new opaque token for [principal] and stores the session.
  Future<String> createSession(BeakPrincipal principal);

  /// The principal behind [token], or `null` when the token is unknown or
  /// the session expired.
  Future<BeakPrincipal?> sessionFor(String token);

  /// Invalidates [token]; unknown tokens are a no-op.
  Future<void> revoke(String token);
}

/// The default [TokenSessionStore]: sessions in process memory with a
/// fixed time-to-live.
///
/// Sessions vanish on restart — fine for local development and tests, but a
/// production deployment behind more than one instance wants a shared,
/// persistent [TokenSessionStore]. `sessionFor` treats an expired session as
/// unknown and evicts it lazily.
///
/// ```dart
/// final store = InMemoryTokenSessionStore(sessionTtl: Duration(hours: 8));
/// final token = await store.createSession(
///   const BeakPrincipal(id: 'admin', roles: {'admin'}),
/// );
/// final principal = await store.sessionFor(token); // the admin principal
/// await store.revoke(token); // subsequent lookups return null
/// ```
final class InMemoryTokenSessionStore implements TokenSessionStore {
  /// Creates a store whose sessions live for [sessionTtl].
  ///
  /// [now] and [generateToken] inject the clock and token mint for tests;
  /// production leaves them at their defaults (the system clock and 256 bits
  /// of secure randomness per token).
  InMemoryTokenSessionStore({
    this.sessionTtl = const Duration(hours: 12),
    DateTime Function()? now,
    String Function()? generateToken,
  }) : _now = now ?? DateTime.now,
       _generateToken = generateToken ?? _randomToken;

  /// How long a session stays valid after creation.
  final Duration sessionTtl;

  final DateTime Function() _now;
  final String Function() _generateToken;
  final Map<String, _Session> _sessionsByToken = {};

  static final Random _random = Random.secure();

  @override
  Future<String> createSession(BeakPrincipal principal) async {
    final String token = _generateToken();
    _sessionsByToken[token] = _Session(
      principal: principal,
      expiresAt: _now().add(sessionTtl),
    );
    return token;
  }

  @override
  Future<BeakPrincipal?> sessionFor(String token) async {
    final session = _sessionsByToken[token];
    if (session == null) {
      return null;
    }
    if (!_now().isBefore(session.expiresAt)) {
      _sessionsByToken.remove(token);
      return null;
    }
    return session.principal;
  }

  @override
  Future<void> revoke(String token) async {
    _sessionsByToken.remove(token);
  }

  /// 256 bits of secure randomness, hex-encoded.
  static String _randomToken() => [
    for (var i = 0; i < 32; i += 1)
      _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

final class _Session {
  const _Session({required this.principal, required this.expiresAt});

  final BeakPrincipal principal;
  final DateTime expiresAt;
}
