import 'package:meta/meta.dart';

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

/// Live model-level presentation permissions.
///
/// Callbacks read the host's current account each time an action or route is
/// evaluated. Missing rules deny access. These checks never replace backend
/// authorization: every endpoint must still enforce its own policy.
@immutable
final class BeakPermissions {
  /// Uses [rules], denying operations without an explicit rule.
  const BeakPermissions(Map<BeakOperation, bool Function()> rules)
    : _rules = rules;

  /// Preserves unrestricted presentation for models without a host policy.
  const BeakPermissions.allowAll() : _rules = null;

  final Map<BeakOperation, bool Function()>? _rules;

  /// Whether [operation] is allowed for the current account.
  bool allows(BeakOperation operation) =>
      _rules == null || (_rules[operation]?.call() ?? false);
}
