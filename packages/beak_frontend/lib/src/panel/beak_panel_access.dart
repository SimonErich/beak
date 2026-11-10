import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:signals/signals_flutter.dart';

import '../auth/beak_auth_adapter.dart';
import '../di/beak_locator.dart';

/// What the signed-in account may see and do in the panel.
///
/// A model's [BeakPermissions] are data, so answering "may this account update
/// orders?" needs the account's [BeakPrincipal]. The panel derives one access
/// object from its auth adapter and registers it in its dependency container;
/// resources, routes, navigation, the command bar, screens and visibility
/// blocks all ask it, so a role granted or revoked while the panel is open
/// shows up without a reload. The server enforces its own policy on every
/// request: the panel only decides what to offer.
///
/// ```dart
/// final access = BeakPanelAccess.of(context);
/// if (access.can(const OrderModel(), BeakOperation.update)) {
///   // offer the edit action
/// }
/// if (access.has('adminReadSales')) {
///   // show the sales overview
/// }
/// ```
///
/// Every question reads a signal. Inside a `Watch`, a hook widget that obtained
/// the access through [of], or a `BeakVisibilityBlock`, the answer is tracked
/// and the widget builds again when the account's roles change.
final class BeakPanelAccess {
  /// Answers from the principal [principal] currently holds.
  ///
  /// `null` is the anonymous request, which only an `anyone` access value
  /// admits.
  BeakPanelAccess(ReadonlySignal<BeakPrincipal?> principal)
    : _principal = principal;

  /// Follows [adapter]: the principal of the identity it reports as signed in,
  /// and `null` for every other state (loading, signed out, failed).
  factory BeakPanelAccess.fromAuth(BeakAuthAdapter adapter) => BeakPanelAccess(
    computed(
      () => switch (adapter.state.value) {
        BeakAuthAuthenticated(:final identity) => identity.principal,
        _ => null,
      },
    ),
  );

  /// A fixed [principal], for a panel without authentication and for tests.
  factory BeakPanelAccess.fixed(BeakPrincipal? principal) =>
      BeakPanelAccess(signal(principal));

  /// The access of an anonymous request.
  static final BeakPanelAccess anonymous = BeakPanelAccess.fixed(null);

  final ReadonlySignal<BeakPrincipal?> _principal;

  /// The principal permissions are checked against, `null` while nobody is
  /// signed in.
  BeakPrincipal? get principal => _principal.value;

  /// Whether the account holds [role].
  bool has(String role) => principal?.hasRole(role) ?? false;

  /// Whether the account holds at least one of [roles].
  bool hasAny(Iterable<String> roles) => roles.any(has);

  /// Whether the model's permissions grant [operation], whatever the model's
  /// capabilities say.
  ///
  /// For a workflow the model's transport does not expose as a standard
  /// operation, such as a custom create screen. Prefer [can].
  bool permits(BeakModel model, BeakOperation operation) =>
      model.permissions.allows(operation, principal);

  /// Whether the account may perform [operation] on [model]: the model
  /// supports it (its `capabilities`) and its permissions admit the account.
  bool can(BeakModel model, BeakOperation operation) =>
      model.capabilities.contains(operation) && permits(model, operation);

  /// Whether the account may list and open [model]'s records.
  bool canRead(BeakModel model) => can(model, BeakOperation.read);

  /// Whether the account may run [action], a command of [model]'s behavior.
  ///
  /// Needs read access plus the command's own entry in the model's permissions,
  /// or `update` when it has none.
  bool canAction(BeakModel model, BeakModelAction action) =>
      canRead(model) && model.permissions.allowsAction(action, principal);

  /// The access of the nearest panel above [context].
  ///
  /// Depends on the panel's [BeakPanelAccessScope], so the widget builds again
  /// when the account's identity or roles change. Without a panel, and without
  /// a registered access, the answer is [anonymous].
  static BeakPanelAccess of(BuildContext context) {
    final scoped = context
        .dependOnInheritedWidgetOfExactType<BeakPanelAccessScope>();
    if (scoped != null) return scoped.access;
    final container = beakDependencies(context);
    return container.isRegistered<BeakPanelAccess>()
        ? container<BeakPanelAccess>()
        : anonymous;
  }
}

/// Makes the panel's [BeakPanelAccess] available to every widget below it.
///
/// [BeakPanel] rebuilds this scope when the account's principal changes, so
/// [BeakPanelAccess.of] answers with fresh roles without any widget asking a
/// signal directly.
final class BeakPanelAccessScope extends InheritedWidget {
  /// Creates a scope over [access].
  const BeakPanelAccessScope({
    required this.access,
    required super.child,
    super.key,
  });

  /// The account's current access.
  final BeakPanelAccess access;

  @override
  bool updateShouldNotify(BeakPanelAccessScope oldWidget) =>
      oldWidget.access != access;
}
