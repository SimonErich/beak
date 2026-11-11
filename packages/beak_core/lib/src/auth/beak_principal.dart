import 'package:meta/meta.dart';

/// The authenticated identity of a request.
///
/// A principal is what a [BeakAccess] value is checked against. The server
/// resolves one per request from its auth guard; the panel builds one from the
/// signed-in session, so both sides decide on the same data.
///
/// ```dart
/// const staff = BeakPrincipal(id: 'u1', roles: {'staff'});
/// assert(staff.hasRole('staff'));
/// ```
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
