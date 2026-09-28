import 'beak_policy.dart';
import 'beak_auth_guard.dart';

/// Optional action-specific authorization in addition to normal record access.
abstract interface class BeakActionPolicy implements BeakPolicy {
  /// Whether this principal may execute the named command on this identity.
  /// [id] is null only for commands explicitly permitted during creation.
  bool canExecuteAction(
    BeakPrincipal? principal,
    String table,
    Object? id,
    String action,
  );
}
