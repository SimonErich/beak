import 'package:beak_core/beak_core.dart';

import '../auth/beak_auth_adapter.dart';

/// Where a resource finds the principal its model's permissions are checked
/// against.
///
/// A [BeakPermissions] value is data, so evaluating it needs the signed-in
/// principal. The panel attaches its auth adapter here when it registers its
/// dependencies, and [BeakResource]'s access getters read [current], which
/// follows the adapter's live state: a signal read inside a widget rebuild
/// keeps tracking sign-in, sign-out and a role change.
///
/// With no adapter attached, or nobody signed in, [current] is `null`: the
/// anonymous request, which only an `anyone` access value admits.
// TODO(beak-access): section D (panel access) replaces this static bridge with
// a BeakPanelAccess that BeakPanel registers from the adapter state and that
// BeakResource.isVisibleTo and the allows*To methods take as an argument.
// Delete this file when that lands.
abstract final class BeakPrincipalBridge {
  static BeakAuthAdapter? _adapter;
  static Object? _owner;

  /// Makes [adapter] the source of [current], on behalf of [owner].
  static void attach(BeakAuthAdapter? adapter, {required Object owner}) {
    _adapter = adapter;
    _owner = owner;
  }

  /// Lets go of the adapter [owner] attached, unless another owner attached
  /// one since.
  static void detach({required Object owner}) {
    if (identical(_owner, owner)) {
      _adapter = null;
      _owner = null;
    }
  }

  /// The principal of the signed-in account, or `null` for an anonymous
  /// request.
  static BeakPrincipal? get current => switch (_adapter?.state.value) {
    BeakAuthAuthenticated(:final identity) => identity.principal,
    _ => null,
  };
}
