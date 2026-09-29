import 'package:meta/meta.dart';

import 'beak_auth_guard.dart';

/// Who may do something: the building block of a [BeakModelRules] rule.
///
/// An access value answers one question about a request, "does this principal
/// qualify", and nothing else. Combine values with [BeakAccess.any],
/// [BeakAccess.all] and [BeakAccess.not] instead of writing role checks by
/// hand:
///
/// ```dart
/// final staff = BeakAccess.role('staff');
/// final manager = BeakAccess.role('manager');
/// final staffOrManager = BeakAccess.any([staff, manager]);
/// final signedIn = BeakAccess.authenticated;
/// ```
///
/// Access is denied unless something grants it: an absent access value in a
/// rule, an empty [BeakAccess.any] and an empty [BeakAccess.all] all grant
/// nothing.
@immutable
sealed class BeakAccess {
  const BeakAccess();

  /// Anyone who carries [role], as reported by the auth guard.
  const factory BeakAccess.role(String role) = _RoleAccess;

  /// Anyone at all, including anonymous requests.
  static const BeakAccess anyone = _AnyoneAccess();

  /// Any signed-in principal, whatever its roles.
  static const BeakAccess authenticated = _AuthenticatedAccess();

  /// Anyone [accesses] grants: at least one of them must.
  ///
  /// An empty list grants nothing.
  const factory BeakAccess.any(List<BeakAccess> accesses) = _AnyAccess;

  /// Anyone every one of [accesses] grants.
  ///
  /// An empty list grants nothing, so a list that lost its entries never
  /// opens a resource.
  const factory BeakAccess.all(List<BeakAccess> accesses) = _AllAccess;

  /// Anyone [access] does not grant.
  const factory BeakAccess.not(BeakAccess access) = _NotAccess;

  /// Whether [principal] qualifies; a `null` principal is an anonymous
  /// request.
  bool allows(BeakPrincipal? principal);
}

final class _RoleAccess extends BeakAccess {
  const _RoleAccess(this.role);

  final String role;

  @override
  bool allows(BeakPrincipal? principal) => principal?.hasRole(role) ?? false;
}

final class _AnyoneAccess extends BeakAccess {
  const _AnyoneAccess();

  @override
  bool allows(BeakPrincipal? principal) => true;
}

final class _AuthenticatedAccess extends BeakAccess {
  const _AuthenticatedAccess();

  @override
  bool allows(BeakPrincipal? principal) => principal != null;
}

final class _AnyAccess extends BeakAccess {
  const _AnyAccess(this.accesses);

  final List<BeakAccess> accesses;

  @override
  bool allows(BeakPrincipal? principal) =>
      accesses.any((access) => access.allows(principal));
}

final class _AllAccess extends BeakAccess {
  const _AllAccess(this.accesses);

  final List<BeakAccess> accesses;

  @override
  bool allows(BeakPrincipal? principal) =>
      accesses.isNotEmpty &&
      accesses.every((access) => access.allows(principal));
}

final class _NotAccess extends BeakAccess {
  const _NotAccess(this.access);

  final BeakAccess access;

  @override
  bool allows(BeakPrincipal? principal) => !access.allows(principal);
}
