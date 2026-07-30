import '../common/beak_exception.dart';
import '../common/json_support.dart';

/// A signed-in session: the bearer token every later request carries, and who
/// the backend says it belongs to.
///
/// Returned by `BeakClient.login`. The token is opaque — it names a session
/// the server holds, not a claim the client can rewrite.
final class BeakSession {
  /// Creates a session for [principalId] identified by [token].
  const BeakSession({
    required this.token,
    required this.principalId,
    this.roles = const {},
  });

  /// Decodes the `/api/auth/login` response.
  ///
  /// Throws a [BeakConfigurationException] on malformed input.
  factory BeakSession.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> principal = requireJsonMap(
      json,
      'principal',
      'BeakSession',
    );
    return BeakSession(
      token: requireJsonString(json, 'token', 'BeakSession'),
      principalId: requireJsonString(principal, 'id', 'BeakSession.principal'),
      roles: switch (principal['roles']) {
        null => const <String>{},
        final List<Object?> values => {
          for (final value in values)
            if (value case final String role) role,
        },
        final Object other => throw BeakConfigurationException(
          'BeakSession.principal.roles must be a list, got $other.',
        ),
      },
    );
  }

  /// The bearer token authenticating later requests.
  final String token;

  /// Stable identifier of the signed-in account.
  final String principalId;

  /// The roles the backend granted, for a panel that hides what a role
  /// cannot use. The API enforces them regardless.
  final Set<String> roles;

  /// Whether this session carries [role].
  bool hasRole(String role) => roles.contains(role);

  @override
  String toString() => 'BeakSession($principalId, roles: ${roles.toList()})';
}
