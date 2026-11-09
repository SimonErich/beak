import 'package:beak_core/beak_core.dart';

import 'beak_action_policy.dart';
import 'beak_field_policy.dart';
import 'beak_policy.dart';

/// Refuses every operation a model's [BeakModel.capabilities] leave out,
/// whatever the wrapped policy says.
///
/// A model's capabilities name the operations its transport supports. A policy
/// decides who may use an operation, and a policy that is more permissive than
/// the model (an allow-all default, a hand-written one, a role rule that grants
/// `write` on a read-only model) must not turn an unsupported operation into a
/// working one. `beakApiRouter` and the graph commit service wrap every
/// policy in this decorator, so no policy has to repeat the check.
///
/// Everything else is the wrapped policy's: the row scope, the field rules,
/// the commands and the upload key checks pass through, and a wrapped policy
/// that does not implement one of those optional interfaces keeps its
/// default of allowing it.
final class BeakCapabilityPolicy
    implements
        BeakRowPolicy,
        BeakFieldPolicy,
        BeakReadOnlyFieldPolicy,
        BeakActionPolicy,
        BeakUploadReadPolicy {
  /// Wraps [policy].
  const BeakCapabilityPolicy(this.policy);

  /// [policy] with its capabilities enforced; a policy that already is
  /// returns unchanged, so wrapping is safe to repeat.
  static BeakPolicy enforcing(BeakPolicy policy) =>
      policy is BeakCapabilityPolicy ? policy : BeakCapabilityPolicy(policy);

  /// The policy that decides who may use the operations the model supports.
  final BeakPolicy policy;

  static bool _supports(BeakModel model, BeakOperation operation) =>
      model.capabilities.contains(operation);

  @override
  bool canView(BeakPrincipal? principal, BeakModel model) =>
      _supports(model, BeakOperation.read) && policy.canView(principal, model);

  @override
  bool canCreate(BeakPrincipal? principal, BeakModel model) =>
      _supports(model, BeakOperation.create) &&
      policy.canCreate(principal, model);

  @override
  bool canUpdate(BeakPrincipal? principal, BeakModel model, Object id) =>
      _supports(model, BeakOperation.update) &&
      policy.canUpdate(principal, model, id);

  @override
  bool canDelete(BeakPrincipal? principal, BeakModel model, Object id) =>
      _supports(model, BeakOperation.delete) &&
      policy.canDelete(principal, model, id);

  /// Removing a stored file follows the delete operation, as it does in
  /// [BeakPolicies].
  @override
  bool canDeleteUpload(
    BeakPrincipal? principal,
    BeakModel model,
    BeakUploadColumn column,
    String storageKey,
  ) =>
      _supports(model, BeakOperation.delete) &&
      policy.canDeleteUpload(principal, model, column, storageKey);

  @override
  BeakFilter? scopeFor(BeakPrincipal? principal, BeakModel model) =>
      beakRowScope(policy, principal, model);

  @override
  bool canReadField(
    BeakPrincipal? principal,
    BeakModel model,
    BeakFieldRef<Object> field,
  ) => switch (policy) {
    final BeakFieldPolicy fields => fields.canReadField(
      principal,
      model,
      field,
    ),
    _ => true,
  };

  @override
  bool canWriteField(
    BeakPrincipal? principal,
    BeakModel model,
    BeakFieldRef<Object> field,
  ) => switch (policy) {
    final BeakFieldPolicy fields => fields.canWriteField(
      principal,
      model,
      field,
    ),
    _ => true,
  };

  @override
  bool isFieldReadOnly(
    BeakPrincipal? principal,
    BeakModel model,
    BeakFieldRef<Object> field,
  ) => switch (policy) {
    final BeakReadOnlyFieldPolicy fields => fields.isFieldReadOnly(
      principal,
      model,
      field,
    ),
    _ => false,
  };

  @override
  bool canExecuteAction(
    BeakPrincipal? principal,
    BeakModel model,
    Object? id,
    BeakModelAction action,
  ) => switch (policy) {
    final BeakActionPolicy actions => actions.canExecuteAction(
      principal,
      model,
      id,
      action,
    ),
    _ => true,
  };

  @override
  bool canViewUpload(
    BeakPrincipal? principal,
    BeakModel model,
    BeakUploadColumn column,
    String storageKey,
  ) => switch (policy) {
    final BeakUploadReadPolicy uploads => uploads.canViewUpload(
      principal,
      model,
      column,
      storageKey,
    ),
    _ => true,
  };
}
