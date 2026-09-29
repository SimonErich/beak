import 'package:serverpod/serverpod.dart';

/// Serverpod scopes Beak defines.
abstract final class BeakScopes {
  /// Opens the Beak admin tunnel. Deliberately not `Scope.admin`: an app's
  /// own admins do not get the panel by accident.
  static const Scope admin = Scope('beak.admin');
}

/// Gates an endpoint on a signed-in user holding [BeakScopes.admin].
///
/// Getter-only on purpose. Serverpod's analyzer never turns mixin members
/// into RPCs, while these virtual getters still gate every call at runtime,
/// before any Beak code runs:
///
/// ```dart
/// class BeakAdminEndpoint extends Endpoint with BeakAdminGate {
///   Future<String> dispatch(Session session, String request) =>
///       bookshopBeak.dispatch(session, request);
/// }
/// ```
mixin BeakAdminGate on Endpoint {
  @override
  bool get requireLogin => true;

  // Not const: Scope overrides ==, so a const set of scopes does not compile.
  @override
  Set<Scope> get requiredScopes => {BeakScopes.admin};
}
