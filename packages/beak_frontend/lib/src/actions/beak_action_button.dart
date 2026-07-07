import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';

import 'beak_action.dart';

/// Runs [action] against its targets.
///
/// Shows the confirmation dialog first when
/// [BeakAction.requiresConfirmation] is set (cancelling aborts without
/// running), then dispatches by action kind — [record] for a
/// [BeakRecordAction], [records] for a [BeakBulkAction], neither for a
/// [BeakGlobalAction]. A record action with a null [record] is a no-op.
/// This is the single execution path both [BeakActionButton] and the table
/// row/bulk actions route through.
Future<void> executeBeakAction({
  required BeakAction action,
  required BeakActionContext context,
  BeakRecord? record,
  List<BeakRecord> records = const [],
}) async {
  if (action.requiresConfirmation) {
    final bool confirmed = await context.overlays.confirm(
      title: '${action.label}?',
      confirmLabel: action.label,
      destructive: action.color == BeakColor.error,
    );
    if (!confirmed) {
      return;
    }
  }
  switch (action) {
    case final BeakRecordAction recordAction:
      final BeakRecord? target = record;
      if (target != null) {
        await recordAction.onExecute(target, context);
      }
    case final BeakBulkAction bulkAction:
      await bulkAction.onExecute(records, context);
    case final BeakGlobalAction globalAction:
      await globalAction.onExecute(context);
  }
}

/// Renders one [BeakAction] as the matching obers_ui button — prominent
/// for [BeakColor.primary], destructive for [BeakColor.error], compact
/// icon-only inside table rows — and executes it on tap via
/// [executeBeakAction].
///
/// The generated pages build these for you; construct one directly only
/// when hand-composing a page:
///
/// ```dart
/// BeakActionButton(
///   action: const BeakCreateAction(),
///   actionContext: actionContext,
/// );
/// ```
class BeakActionButton extends HookWidget {
  /// Creates the button for [action].
  ///
  /// [record]/[records] carry the targets of record and bulk actions;
  /// [compact] renders the icon-only row variant.
  const BeakActionButton({
    required this.action,
    required this.actionContext,
    this.record,
    this.records = const [],
    this.compact = false,
    super.key,
  });

  /// The action this button runs.
  final BeakAction action;

  /// The execution context handed to the action.
  final BeakActionContext actionContext;

  /// The target of a record action.
  final BeakRecord? record;

  /// The targets of a bulk action.
  final List<BeakRecord> records;

  /// Whether to render the icon-only row variant.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    Future<void> run() => executeBeakAction(
      action: action,
      context: actionContext,
      record: record,
      records: records,
    );
    if (compact) {
      return OiButton.icon(
        icon: action.icon ?? OiIcons.play,
        label: action.label,
        onTap: run,
      );
    }
    return switch (action.color) {
      BeakColor.primary => OiButton.primary(label: action.label, onTap: run),
      BeakColor.error => OiButton.destructive(label: action.label, onTap: run),
      _ => OiButton.secondary(label: action.label, onTap: run),
    };
  }
}
