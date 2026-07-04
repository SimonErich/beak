import 'package:beak_core/beak_core.dart';
import 'package:meta/meta.dart';
import 'package:shelf/shelf.dart';

import 'token_session_store.dart';

/// The authenticated identity of a request.
@immutable
final class BeakPrincipal {
  /// Creates a principal identified by [id] carrying [roles].
  const BeakPrincipal({required this.id, this.roles = const {}});

  /// Stable identifier of the account.
  final String id;

  /// The roles policies decide on.
  final Set<String> roles;

  /// Whether the principal carries [role].
  bool hasRole(String role) => roles.contains(role);

  /// This principal as a plain JSON-encodable object (roles sorted for a
  /// stable wire shape).
  Map<String, Object?> toJson() => {
    'id': id,
    'roles': [...roles]..sort(),
  };

  @override
  bool operator ==(Object other) =>
      other is BeakPrincipal &&
      other.id == id &&
      other.roles.length == roles.length &&
      other.roles.containsAll(roles);

  @override
  int get hashCode => Object.hash(id, Object.hashAllUnordered(roles));

  @override
  String toString() => 'BeakPrincipal($id, roles: ${[...roles]..sort()})';
}

/// Resolves the identity behind a request — the pluggable seam the auth
/// middleware calls.
///
/// Implementations return `null` for anonymous requests (no credentials at
/// all) and throw a [BeakAuthenticationException] for credentials that are
/// present but invalid, so forged tokens never demote silently to
/// anonymous. Implement this to plug in an alternative scheme (JWT, an API
/// gateway header, …); [TokenSessionAuthGuard] is the built-in Bearer-token
/// implementation. Install it via [beakAuthMiddleware] or [BeakServer]'s
/// `authGuard` parameter:
///
/// ```dart
/// final class ApiKeyGuard implements BeakAuthGuard {
///   const ApiKeyGuard(this.keys);
///   final Map<String, BeakPrincipal> keys;
///
///   @override
///   Future<BeakPrincipal?> authenticate(Request request) async {
///     final key = request.headers['x-api-key'];
///     if (key == null) return null; // anonymous
///     return keys[key] ??
///         (throw const BeakAuthenticationException('Unknown API key.'));
///   }
/// }
/// ```
abstract interface class BeakAuthGuard {
  /// The principal behind [request], or `null` when it carries no
  /// credentials.
  Future<BeakPrincipal?> authenticate(Request request);
}

/// The default guard: opaque `Bearer` tokens looked up in a server-side
/// [TokenSessionStore].
///
/// A missing `Authorization` header is anonymous; a header that is not a
/// `Bearer` token, or a token the store does not recognise (unknown or
/// expired), throws a [BeakAuthenticationException] rather than falling back
/// to anonymous. Pair it with the same store [BeakAuthSessions] mints tokens
/// into:
///
/// ```dart
/// final store = InMemoryTokenSessionStore();
/// final handler = const Pipeline()
///     .addMiddleware(beakAuthMiddleware(guard: TokenSessionAuthGuard(store)))
///     .addHandler(router);
/// ```
final class TokenSessionAuthGuard implements BeakAuthGuard {
  /// Creates a guard resolving tokens through [store].
  const TokenSessionAuthGuard(this.store);

  /// The server-side session store.
  final TokenSessionStore store;

  static const String _bearerPrefix = 'Bearer ';

  @override
  Future<BeakPrincipal?> authenticate(Request request) async {
    final String? header = request.headers['authorization'];
    if (header == null) {
      return null;
    }
    if (!header.startsWith(_bearerPrefix)) {
      throw const BeakAuthenticationException(
        'The authorization header must carry a Bearer token.',
      );
    }
    final principal = await store.sessionFor(
      header.substring(_bearerPrefix.length),
    );
    return principal ??
        (throw const BeakAuthenticationException(
          'The session token is invalid or expired.',
        ));
  }
}
