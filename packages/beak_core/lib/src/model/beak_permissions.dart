import 'package:meta/meta.dart';

import '../auth/beak_access.dart';
import '../auth/beak_principal.dart';
import '../behavior/beak_model_behavior.dart';

/// Standard resource operations presented by a Beak panel.
enum BeakOperation {
  /// List and inspect records.
  read,

  /// Create a record.
  create,

  /// Change an existing record.
  update,

  /// Remove or archive a record through its configured operation.
  delete,
}

// --8<-- [start:BeakPermissions]
/// Who may do what with a model, as data.
///
/// A permission is a constant [BeakAccess] value per operation, checked
/// against a [BeakPrincipal]. The server and the panel evaluate the same
/// constant, each with the principal it knows, so what the panel offers and
/// what the server allows cannot drift apart. The panel only hides controls;
/// the server still enforces its own policy on every request.
///
/// ```dart
/// const permissions = BeakPermissions(
///   read: BeakAccess.role('staff'),
///   write: BeakAccess.role('manager'),
///   actions: {'refund': BeakAccess.role('finance')},
/// );
///
/// const manager = BeakPrincipal(id: 'u1', roles: {'manager'});
/// permissions.allows(BeakOperation.update, manager); // true
/// permissions.allows(BeakOperation.read, manager); // false
/// ```
///
/// Nothing is granted by default: an operation with no access value is
/// denied, for a `null` principal as well. [create], [update] and [delete]
/// fall back to [write] when unset, so most models name only [read] and
/// [write]. A model without a host policy uses [BeakPermissions.allowAll].
@immutable
final class BeakPermissions {
  /// Grants each operation to whoever its access value admits.
  ///
  /// [create], [update] and [delete] default to [write]. An operation whose
  /// access value is still `null` is denied. [actions] holds an access value
  /// per command name; a command without one is governed by [update].
  const BeakPermissions({
    this.read,
    this.write,
    this.create,
    this.update,
    this.delete,
    this.actions = const {},
  });

  /// Unrestricted access for models without a host policy: every operation
  /// and every action is open to anyone, anonymous requests included.
  const BeakPermissions.allowAll()
    : read = BeakAccess.anyone,
      write = BeakAccess.anyone,
      create = null,
      update = null,
      delete = null,
      actions = const {};

  /// Who may list and inspect records. Denied when `null`.
  final BeakAccess? read;

  /// Who may change data: the default for [create], [update] and [delete].
  final BeakAccess? write;

  /// Who may create records, instead of [write].
  final BeakAccess? create;

  /// Who may change records, instead of [write]. Also the default for a
  /// command without its own entry in [actions].
  final BeakAccess? update;

  /// Who may delete records, instead of [write].
  final BeakAccess? delete;

  /// Who may run a command, by its [BeakModelAction.name].
  ///
  /// A command not listed here is governed by [update].
  final Map<String, BeakAccess> actions;

  /// The access value that governs [operation], or `null` when none does.
  BeakAccess? accessFor(BeakOperation operation) => switch (operation) {
    BeakOperation.read => read,
    BeakOperation.create => create ?? write,
    BeakOperation.update => update ?? write,
    BeakOperation.delete => delete ?? write,
  };

  /// Whether [principal] may perform [operation]; a `null` principal is an
  /// anonymous request.
  bool allows(BeakOperation operation, BeakPrincipal? principal) =>
      accessFor(operation)?.allows(principal) ?? false;

  /// The access value that governs [action], or `null` when none does.
  BeakAccess? accessForAction(BeakModelAction action) =>
      actions[action.name] ?? update ?? write;

  /// Whether [principal] may run [action].
  ///
  /// The command's own entry in [actions] decides when there is one, and
  /// [update] (then [write]) otherwise.
  bool allowsAction(BeakModelAction action, BeakPrincipal? principal) =>
      accessForAction(action)?.allows(principal) ?? false;
}
// --8<-- [end:BeakPermissions]
