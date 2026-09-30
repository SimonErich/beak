import 'package:beak_core/beak_core.dart';

import 'beak_auth_guard.dart';

/// Per-resource authorization decisions, consulted by every generated
/// handler before it acts.
///
/// A `null` principal is an anonymous request; denials surface as 401
/// (anonymous) or 403 (authenticated) through the handlers. Implement this
/// to gate the generated API by role, then pass the instance to
/// [BeakServer]'s `policy` parameter. The methods receive the [BeakPrincipal]
/// resolved by the auth guard and the target [BeakModel] (plus the record `id`
/// or the upload column and storage key for the mutating hooks), so a policy
/// compares models by type and never by table name.
///
/// Most applications should not implement this by hand: [BeakPolicies] is the
/// typed rule set that compiles to these hooks and denies everything it does
/// not list. Implement the hooks directly only for rules the rule set cannot
/// express.
///
/// ```dart
/// final class AdminOnlyWrites implements BeakPolicy {
///   const AdminOnlyWrites();
///
///   bool _isAdmin(BeakPrincipal? p) => p?.hasRole('admin') ?? false;
///
///   @override
///   bool canView(BeakPrincipal? principal, BeakModel model) =>
///       principal != null;
///
///   @override
///   bool canCreate(BeakPrincipal? principal, BeakModel model) =>
///       _isAdmin(principal);
///
///   @override
///   bool canUpdate(BeakPrincipal? principal, BeakModel model, Object id) =>
///       _isAdmin(principal);
///
///   @override
///   bool canDelete(BeakPrincipal? principal, BeakModel model, Object id) =>
///       _isAdmin(principal);
///
///   @override
///   bool canDeleteUpload(
///     BeakPrincipal? principal,
///     BeakModel model,
///     BeakUploadColumn column,
///     String storageKey,
///   ) => _isAdmin(principal);
/// }
/// ```
abstract interface class BeakPolicy {
  /// Whether [principal] may read records of [model].
  bool canView(BeakPrincipal? principal, BeakModel model);

  /// Whether [principal] may create records of [model].
  bool canCreate(BeakPrincipal? principal, BeakModel model);

  /// Whether [principal] may update the record of [model] with [id].
  bool canUpdate(BeakPrincipal? principal, BeakModel model, Object id);

  /// Whether [principal] may delete the record of [model] with [id].
  bool canDelete(BeakPrincipal? principal, BeakModel model, Object id);

  /// Whether [principal] may delete the stored upload under [storageKey]
  /// held by [model]'s file [column].
  ///
  /// A dedicated hook: upload removal identifies the file by its storage
  /// key, not by a record id, so it must never flow through [canDelete]'s
  /// record-id parameter.
  bool canDeleteUpload(
    BeakPrincipal? principal,
    BeakModel model,
    BeakUploadColumn column,
    String storageKey,
  );
}

/// A policy that also narrows *which rows* a principal may touch.
///
/// [BeakPolicy] answers "may this principal read orders at all", which is not
/// the same question as "may this principal read *these* orders". Without a
/// row scope, a policy that intends "a customer sees only their own orders"
/// is bypassed by `POST /api/orders/query` with any filter the caller likes,
/// because the filter comes from the client.
///
/// Implement this instead of [BeakPolicy] and every read and write of the
/// table is intersected with [scopeFor] — query, aggregate, get-one, update,
/// delete, graph commits and export alike, so there is no endpoint left to
/// forget.
///
/// Build the filter from the model's typed field references, so no column
/// name is ever written as a string:
///
/// ```dart
/// final class OwnOrdersOnly extends BeakAllowAllPolicy
///     implements BeakRowPolicy {
///   const OwnOrdersOnly();
///
///   @override
///   BeakFilter? scopeFor(BeakPrincipal? principal, BeakModel model) {
///     if (model is! OrderModel || principal == null) {
///       return null;
///     }
///     return OrderModel.userId.eq(principal.id);
///   }
/// }
/// ```
// --8<-- [start:BeakRowPolicy]
abstract interface class BeakRowPolicy implements BeakPolicy {
  /// The filter every read and write of [model] is additionally constrained
  /// by, or `null` when [principal] may touch every row.
  ///
  /// Returning a filter that matches nothing is how a policy says "no rows":
  /// the request still succeeds, with an empty page, which is what a row
  /// scope means — as opposed to `canView` returning false, which is a 403.
  BeakFilter? scopeFor(BeakPrincipal? principal, BeakModel model);
}
// --8<-- [end:BeakRowPolicy]

/// The row scope [policy] applies to [model], or `null` when it declares
/// none.
///
/// The one place that knows a plain [BeakPolicy] has no row scope, so callers
/// do not each repeat the type test.
BeakFilter? beakRowScope(
  BeakPolicy policy,
  BeakPrincipal? principal,
  BeakModel model,
) => policy is BeakRowPolicy ? policy.scopeFor(principal, model) : null;

/// The default policy: everything is allowed — panels stay open until an
/// app configures a real policy.
///
/// Meant for tests and quick starts. A production server should pass a
/// [BeakPolicies] rule set instead, which denies whatever it does not list.
///
/// Declared `base` rather than `final` so a hand-written policy can extend it
/// and override only what it restricts. "Allow everything except deletes" is
/// the common shape, and spelling out five permissive methods to express it
/// is exactly the boilerplate that makes people skip writing a policy at all.
base class BeakAllowAllPolicy implements BeakPolicy {
  /// Creates the permissive default policy.
  const BeakAllowAllPolicy();

  @override
  bool canView(BeakPrincipal? principal, BeakModel model) => true;

  @override
  bool canCreate(BeakPrincipal? principal, BeakModel model) => true;

  @override
  bool canUpdate(BeakPrincipal? principal, BeakModel model, Object id) => true;

  @override
  bool canDelete(BeakPrincipal? principal, BeakModel model, Object id) => true;

  @override
  bool canDeleteUpload(
    BeakPrincipal? principal,
    BeakModel model,
    BeakUploadColumn column,
    String storageKey,
  ) => true;
}

/// Throws the status-correct typed exception when a policy decision denied
/// access, and does nothing when it allowed it.
///
/// A denied `null` [principal] raises a [BeakAuthenticationException] (401);
/// a denied authenticated principal raises a [BeakAuthorizationException]
/// (403). [action] and [model] are woven into the human-readable message
/// (e.g. `Sign in to update "products".`). Call it right after evaluating a
/// [BeakPolicy] method in a handler:
///
/// ```dart
/// enforcePolicyDecision(
///   allowed: policy.canCreate(beakPrincipal(request), model),
///   principal: beakPrincipal(request),
///   action: 'create',
///   model: model,
/// );
/// ```
// --8<-- [start:enforcePolicyDecision]
void enforcePolicyDecision({
  required bool allowed,
  required BeakPrincipal? principal,
  required String action,
  required BeakModel model,
}) {
  if (allowed) {
    return;
  }
  if (principal == null) {
    throw BeakAuthenticationException('Sign in to $action "${model.table}".');
  }
  throw BeakAuthorizationException(
    'Principal "${principal.id}" is not allowed to $action "${model.table}".',
  );
}

// --8<-- [end:enforcePolicyDecision]

/// Optional key-aware restriction in addition to resource and row read policy.
/// Generated upload URL routes apply row ownership automatically when scoped.
abstract interface class BeakUploadReadPolicy {
  /// Whether a principal may resolve this upload's URL after ordinary read
  /// gates: [storageKey] is held by [model]'s file [column].
  bool canViewUpload(
    BeakPrincipal? principal,
    BeakModel model,
    BeakUploadColumn column,
    String storageKey,
  );
}
