import 'package:beak_core/beak_core.dart';

import 'beak_auth_guard.dart';

/// Per-resource authorization decisions, consulted by every generated
/// handler before it acts.
///
/// A `null` principal is an anonymous request; denials surface as 401
/// (anonymous) or 403 (authenticated) through the handlers. Implement this
/// to gate the generated API by role, then pass the instance to
/// [BeakServer]'s `policy` parameter. The methods receive the [BeakPrincipal]
/// resolved by the auth guard and the target `table` (plus the record `id` or
/// upload `storageKey` for the mutating hooks).
///
/// ```dart
/// final class AdminOnlyWrites implements BeakPolicy {
///   const AdminOnlyWrites();
///
///   bool _isAdmin(BeakPrincipal? p) => p?.hasRole('admin') ?? false;
///
///   @override
///   bool canView(BeakPrincipal? principal, String table) => principal != null;
///
///   @override
///   bool canCreate(BeakPrincipal? principal, String table) =>
///       _isAdmin(principal);
///
///   @override
///   bool canUpdate(BeakPrincipal? principal, String table, Object id) =>
///       _isAdmin(principal);
///
///   @override
///   bool canDelete(BeakPrincipal? principal, String table, Object id) =>
///       _isAdmin(principal);
///
///   @override
///   bool canDeleteUpload(
///     BeakPrincipal? principal,
///     String table,
///     String columnKey,
///     String storageKey,
///   ) => _isAdmin(principal);
/// }
/// ```
abstract interface class BeakPolicy {
  /// Whether [principal] may read records of [table].
  bool canView(BeakPrincipal? principal, String table);

  /// Whether [principal] may create records of [table].
  bool canCreate(BeakPrincipal? principal, String table);

  /// Whether [principal] may update the record of [table] with [id].
  bool canUpdate(BeakPrincipal? principal, String table, Object id);

  /// Whether [principal] may delete the record of [table] with [id].
  bool canDelete(BeakPrincipal? principal, String table, Object id);

  /// Whether [principal] may delete the stored upload under [storageKey]
  /// held by [table]'s file column [columnKey].
  ///
  /// A dedicated hook: upload removal identifies the file by its storage
  /// key, not by a record id, so it must never flow through [canDelete]'s
  /// record-id parameter.
  bool canDeleteUpload(
    BeakPrincipal? principal,
    String table,
    String columnKey,
    String storageKey,
  );
}

/// The default policy: everything is allowed — panels stay open until an
/// app configures a real policy.
final class BeakAllowAllPolicy implements BeakPolicy {
  /// Creates the permissive default policy.
  const BeakAllowAllPolicy();

  @override
  bool canView(BeakPrincipal? principal, String table) => true;

  @override
  bool canCreate(BeakPrincipal? principal, String table) => true;

  @override
  bool canUpdate(BeakPrincipal? principal, String table, Object id) => true;

  @override
  bool canDelete(BeakPrincipal? principal, String table, Object id) => true;

  @override
  bool canDeleteUpload(
    BeakPrincipal? principal,
    String table,
    String columnKey,
    String storageKey,
  ) => true;
}

/// Throws the status-correct typed exception when a policy decision denied
/// access, and does nothing when it allowed it.
///
/// A denied `null` [principal] raises a [BeakAuthenticationException] (401);
/// a denied authenticated principal raises a [BeakAuthorizationException]
/// (403). [action] and [table] are woven into the human-readable message
/// (e.g. `Sign in to update "products".`). Call it right after evaluating a
/// [BeakPolicy] method in a handler:
///
/// ```dart
/// enforcePolicyDecision(
///   allowed: policy.canCreate(beakPrincipal(request), model.table),
///   principal: beakPrincipal(request),
///   action: 'create',
///   table: model.table,
/// );
/// ```
void enforcePolicyDecision({
  required bool allowed,
  required BeakPrincipal? principal,
  required String action,
  required String table,
}) {
  if (allowed) {
    return;
  }
  if (principal == null) {
    throw BeakAuthenticationException('Sign in to $action "$table".');
  }
  throw BeakAuthorizationException(
    'Principal "${principal.id}" is not allowed to $action "$table".',
  );
}
