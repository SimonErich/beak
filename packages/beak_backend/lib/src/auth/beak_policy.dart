import 'package:beak_core/beak_core.dart';

import 'beak_auth_guard.dart';

/// Per-resource authorization decisions, consulted by every generated
/// handler before it acts.
///
/// A `null` principal is an anonymous request; denials surface as 401
/// (anonymous) or 403 (authenticated) through the handlers.
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

/// Fails a denied policy decision with the status-correct typed exception:
/// 401 for anonymous requests, 403 for authenticated ones.
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
