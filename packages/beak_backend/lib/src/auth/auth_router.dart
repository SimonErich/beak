import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../server/middleware/auth_middleware.dart';
import '../server/middleware/json_middleware.dart';
import 'beak_auth_guard.dart';
import 'token_session_store.dart';

/// Hashes [password] with HMAC-SHA256 under [secret] — what
/// [BeakUserAccount]s store instead of plaintext.
///
/// The same [secret] must be supplied to [BeakAuthSessions] so login can
/// recompute and compare the hash. Keep it out of source (load it from the
/// environment):
///
/// ```dart
/// final account = BeakUserAccount(
///   username: 'admin',
///   passwordHash: hashBeakPassword('s3cret', secret: authSecret),
///   principal: const BeakPrincipal(id: 'admin', roles: {'admin'}),
/// );
/// ```
String hashBeakPassword(String password, {required String secret}) =>
    Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(password)).toString();

/// One login-capable account: a username, the hash of its password, and the
/// principal a successful login mints sessions for.
final class BeakUserAccount {
  /// Creates an account; [passwordHash] comes from [hashBeakPassword].
  const BeakUserAccount({
    required this.username,
    required this.passwordHash,
    required this.principal,
  });

  /// The username presented at login.
  final String username;

  /// HMAC-SHA256 hash of the password — never the plaintext.
  final String passwordHash;

  /// The identity sessions carry after a successful login.
  final BeakPrincipal principal;
}

/// Configuration of the generated `/api/auth` surface: the session store,
/// the login-capable accounts, and the password-hashing secret.
///
/// Pass this to [BeakServer] (its `authSessions` parameter) or to
/// [beakAuthRouter] to mount `POST /login`, `POST /logout`, and `GET /me`.
/// The same [secret] must have hashed every account's password:
///
/// ```dart
/// final auth = BeakAuthSessions(
///   store: InMemoryTokenSessionStore(),
///   secret: authSecret,
///   users: [
///     BeakUserAccount(
///       username: 'admin',
///       passwordHash: hashBeakPassword('s3cret', secret: authSecret),
///       principal: const BeakPrincipal(id: 'admin', roles: {'admin'}),
///     ),
///   ],
/// );
/// ```
final class BeakAuthSessions {
  /// Creates the auth-surface configuration.
  const BeakAuthSessions({
    required this.store,
    required this.users,
    required this.secret,
  });

  /// Where sessions live.
  final TokenSessionStore store;

  /// The accounts that may log in.
  final List<BeakUserAccount> users;

  /// The secret behind [hashBeakPassword].
  final String secret;
}

/// The thin handlers behind `/api/auth`: login mints an opaque session
/// token, logout revokes it, and `me` echoes the authenticated principal.
final class BeakAuthHandlers {
  /// Creates handlers over [sessions].
  BeakAuthHandlers(this.sessions)
    : _accountsByUsername = {
        for (final account in sessions.users) account.username: account,
      };

  /// The configured auth surface.
  final BeakAuthSessions sessions;

  final Map<String, BeakUserAccount> _accountsByUsername;

  /// `POST /login` — verifies credentials and returns a session token plus
  /// the principal.
  Future<Response> login(Request request) async {
    final body = await readJsonObject(request);
    final String username = _requireString(body, 'username');
    final String password = _requireString(body, 'password');
    final account = _accountsByUsername[username];
    if (account == null ||
        account.passwordHash !=
            hashBeakPassword(password, secret: sessions.secret)) {
      throw const BeakAuthenticationException('Invalid username or password.');
    }
    final String token = await sessions.store.createSession(account.principal);
    return Response.ok(
      jsonEncode({'token': token, 'principal': account.principal.toJson()}),
    );
  }

  /// `POST /logout` — revokes the presented Bearer token.
  Future<Response> logout(Request request) async {
    await sessions.store.revoke(_bearerTokenOf(request));
    return Response(204);
  }

  /// `GET /me` — the authenticated principal (401 when anonymous).
  Future<Response> me(Request request) async {
    final principal =
        beakPrincipal(request) ??
        (throw const BeakAuthenticationException('Sign in to continue.'));
    return Response.ok(jsonEncode(principal.toJson()));
  }

  String _bearerTokenOf(Request request) {
    final String? header = request.headers['authorization'];
    if (header == null || !header.startsWith('Bearer ')) {
      throw const BeakAuthenticationException(
        'A Bearer token is required to log out.',
      );
    }
    return header.substring('Bearer '.length);
  }

  String _requireString(Map<String, Object?> body, String key) =>
      switch (body[key]) {
        final String value => value,
        final Object? other => throw BeakValidationException(
          'Request body must carry a "$key" string, got $other.',
        ),
      };
}

/// Builds the auth [Router] over [sessions]: `POST /login`, `POST /logout`,
/// and `GET /me`, mounted under `/api/auth` by the generated API.
///
/// Usually you configure [BeakServer] with `authSessions` instead of calling
/// this directly; reach for it when composing the router by hand.
Router beakAuthRouter(BeakAuthSessions sessions) {
  final handlers = BeakAuthHandlers(sessions);
  return Router()
    ..post('/login', handlers.login)
    ..post('/logout', handlers.logout)
    ..get('/me', handlers.me);
}
