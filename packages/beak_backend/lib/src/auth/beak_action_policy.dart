import 'package:beak_core/beak_core.dart';

import 'beak_auth_guard.dart';
import 'beak_policy.dart';

/// Optional action-specific authorization in addition to normal record access.
abstract interface class BeakActionPolicy implements BeakPolicy {
  /// Whether this principal may execute [action] of [model] on this identity.
  /// [id] is null only for commands explicitly permitted during creation.
  bool canExecuteAction(
    BeakPrincipal? principal,
    BeakModel model,
    Object? id,
    BeakModelAction action,
  );
}
