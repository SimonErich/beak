import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';

import 'beak_action.dart';
import '../data/beak_resource_repository.dart';
import '../localization/beak_localizations.dart';

/// Localizes framework actions while leaving caller-supplied labels intact.
String beakActionLabel(BeakAction action, BuildContext context) {
  final strings = BeakLocalizations.of(context);
  return switch (action) {
    BeakCreateAction() => strings.create,
    BeakEditAction() => strings.edit,
    BeakViewAction() => strings.view,
    BeakDeleteAction() => strings.delete,
    BeakArchiveAction() => strings.archive,
    _ => action.label,
  };
}

/// Runs [action] against its targets.
///
/// Shows the confirmation dialog first when
/// [BeakAction.requiresConfirmation] is set (cancelling aborts without
/// running), then dispatches by action kind — [record] for a
/// [BeakRecordAction], [records] for a [BeakBulkAction], neither for a
/// [BeakGlobalAction]. A record action with a null [record] is a no-op.
/// This is the single execution path both [BeakActionButton] and the table
/// row/bulk actions route through.
// --8<-- [start:executeBeakAction]
Future<void> executeBeakAction({
  required BeakAction action,
  required BeakActionContext context,
  BeakRecord? record,
  List<BeakRecord> records = const [],
}) async {
  if (!context.checkPermission(action)) return;
  if (action.requiresConfirmation) {
    final label = beakActionLabel(action, context.buildContext);
    final bool confirmed = await context.overlays.confirm(
      title: '$label?',
      confirmLabel: label,
      destructive: action.color == BeakColor.error,
    );
    if (!confirmed || !context.checkPermission(action)) {
      return;
    }
  }
  final result = await BeakResourceRepository(context.dataSource).run(() async {
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
  });
  if (result case BeakErr(:final error)) context.reportError(error);
}
// --8<-- [end:executeBeakAction]

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
    final pending = useState(false);
    final label = beakActionLabel(action, context);
    Future<void> run() async {
      if (pending.value) return;
      pending.value = true;
      try {
        await executeBeakAction(
          action: action,
          context: actionContext,
          record: record,
          records: records,
        );
      } finally {
        if (context.mounted) pending.value = false;
      }
    }

    if (compact) {
      return OiButton.icon(
        icon: action.icon ?? OiIcons.play,
        label: label,
        onTap: pending.value ? null : run,
      );
    }
    return switch (action.color) {
      BeakColor.primary => OiButton.primary(
        label: label,
        icon: action.icon,
        onTap: pending.value ? null : run,
      ),
      BeakColor.error => OiButton.destructive(
        label: label,
        icon: action.icon,
        onTap: pending.value ? null : run,
      ),
      _ => OiButton.secondary(
        label: label,
        icon: action.icon,
        onTap: pending.value ? null : run,
      ),
    };
  }
}
