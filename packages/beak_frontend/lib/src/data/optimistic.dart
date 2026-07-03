import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

/// Beak's optimistic-mutation façade over `OiOptimisticAction`: apply the
/// change locally right away, offer undo, and only commit to the backend
/// once the undo window passes (rolling back on failure).
abstract final class BeakOptimistic {
  /// Applies a mutation optimistically.
  ///
  /// [apply] updates local state immediately; [rollback] must restore it
  /// exactly; [commit] performs the backend call after the undo window.
  /// Resolves to `true` when the mutation committed, `false` when it was
  /// undone or the commit failed (after rolling back).
  static Future<bool> mutate(
    BuildContext context, {
    required VoidCallback apply,
    required VoidCallback rollback,
    required Future<void> Function() commit,
    required String message,
    Duration undoDuration = const Duration(seconds: 5),
  }) => OiOptimisticAction.execute(
    context,
    apply: apply,
    onRollback: rollback,
    commit: commit,
    message: message,
    undoDuration: undoDuration,
  );
}
