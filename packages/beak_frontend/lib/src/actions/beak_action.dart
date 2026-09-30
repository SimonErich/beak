import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import 'beak_uri_action.dart';
import '../data/optimistic.dart';
import '../data/beak_record_batch.dart';
import '../form/beak_import_view.dart';
import '../data/beak_data_changes.dart';
import '../overlays/beak_overlays.dart';
import '../localization/beak_localizations.dart';
import '../panel/beak_back_button.dart';
import '../panel/beak_routes.dart';
import '../panel/beak_resource_screen.dart';
import '../documents/beak_record_document.dart';
import '../documents/beak_document_delivery.dart';
import '../formatting/beak_formatting.dart';

part 'built_in_actions.dart';

/// Everything an executing action may reach for: the resource's model, the
/// data source, the router for navigation, the build context for overlays
/// (confirmations, optimistic undo), and a hook to refresh the surface the
/// action ran from.
///
/// Beak constructs this and hands it to every action's `onExecute`; custom
/// actions read from it rather than capturing widget state:
///
/// ```dart
/// Future<void> archive(BeakRecord record, BeakActionContext context) async {
///   final Object? id = context.model.primaryKeyOf(record);
///   if (id == null) return;
///   await context.dataSource.update(
///     context.model.table,
///     id,
///     BeakRecord(values: {'archived': const BeakBoolValue(true)}),
///   );
///   await context.refresh?.call();
/// }
/// ```
// --8<-- [start:BeakActionContext]
final class BeakActionContext {
  /// Creates the execution context handed to every action.
  const BeakActionContext({
    required this.buildContext,
    required this.model,
    required this.dataSource,
    required this.router,
    this.refresh,
    this.stageRemoval,
    this.onError,
    this.canExecute,
  });

  /// The context overlays (dialogs, undo toasts) mount from.
  final BuildContext buildContext;

  /// The model of the resource the action runs on.
  final BeakModel model;

  /// The source mutations run against.
  final BeakDataSource dataSource;

  /// The panel router, for navigating actions.
  final GoRouter router;

  /// Reloads the surface the action ran from (e.g. the list), if any.
  final Future<void> Function()? refresh;

  /// Hides a list record immediately and returns its undo/rollback callback.
  /// Resource tables provide this automatically; detail surfaces omit it.
  final VoidCallback Function(Object id)? stageRemoval;

  /// Optional host notification boundary for failures.
  final void Function(BeakException error)? onError;

  /// Live presentation authorization, rechecked before and after confirmation.
  /// Server-side authorization remains required for every mutation.
  final bool Function(BeakAction action)? canExecute;

  /// Checks current permissions and reports a denied action without executing it.
  bool checkPermission(BeakAction action) {
    if (!buildContext.mounted) return false;
    if (canExecute?.call(action) ?? true) return true;
    reportError(
      BeakAuthorizationException(
        BeakLocalizations.of(buildContext).actionDenied,
      ),
    );
    return false;
  }

  /// Reports a typed failure through the host or the default overlay.
  ///
  /// The default overlay shows a domain failure's own message, and the
  /// generic text for a failure that describes the deployment (see
  /// [BeakLocalizations.errorMessage]).
  void reportError(BeakException error) {
    if (onError case final report?) {
      report(error);
    } else if (buildContext.mounted) {
      overlays.toast(
        BeakLocalizations.of(buildContext).errorMessage(error),
        level: OiToastLevel.error,
      );
    }
  }

  /// The declarative overlay handle — confirmations, modals, sheets, and
  /// toasts — bound to this action's [buildContext].
  BeakOverlays get overlays => BeakOverlays(buildContext);
}
// --8<-- [end:BeakActionContext]

/// A typed panel action: what it is called, how it renders, and whether it
/// asks before running.
///
/// The sealed hierarchy fixes the three target shapes — one record
/// ([BeakRecordAction]), the current selection ([BeakBulkAction]), or the
/// page ([BeakGlobalAction]) — so surfaces switch over them exhaustively.
/// The built-in view/edit/delete/create actions subclass these; declare
/// custom ones on a [BeakResource] to extend the generated pages.
// --8<-- [start:BeakAction]
sealed class BeakAction {
  /// Creates an action identified by [key] and labelled [label].
  const BeakAction({
    required this.key,
    required this.label,
    this.icon,
    this.color,
    this.requiresConfirmation = false,
  });

  /// Stable identifier (test hooks, telemetry).
  final String key;

  /// The button label.
  final String label;

  /// The button icon, if any.
  final IconData? icon;

  /// Semantic color driving the button variant ([BeakColor.error] renders
  /// destructively, [BeakColor.primary] prominently).
  final BeakColor? color;

  /// Whether a confirmation dialog gates execution.
  final bool requiresConfirmation;
}
// --8<-- [end:BeakAction]

/// An action over one record (a table row or the record on a show page).
///
/// [onExecute] receives the target [BeakRecord] and the [BeakActionContext].
/// Set [BeakAction.requiresConfirmation] to gate it behind a dialog, and
/// [BeakAction.color] to `BeakColor.error` to render it destructively.
///
/// ```dart
/// BeakRecordAction(
///   key: 'duplicate',
///   label: 'Duplicate',
///   icon: OiIcons.copy,
///   onExecute: (record, context) async {
///     await context.dataSource.create(context.model.table, record);
///     await context.refresh?.call();
///   },
/// );
/// ```
// --8<-- [start:BeakRecordAction]
final class BeakRecordAction extends BeakAction {
  /// Creates a record action running [onExecute].
  const BeakRecordAction({
    required super.key,
    required super.label,
    required this.onExecute,
    this.roles = const {
      BeakScreenRole.list,
      BeakScreenRole.read,
      BeakScreenRole.edit,
    },
    super.icon,
    super.color,
    super.requiresConfirmation,
  });

  /// Opens a record's website, email composer, phone dialer, or SMS composer.
  /// Uses the shared safe URI boundary and the standard action error handling.
  factory BeakRecordAction.link({
    required String key,
    required String label,
    required Uri? Function(BeakRecord record) uri,
    IconData? icon,
    Set<BeakScreenRole> roles = const {
      BeakScreenRole.list,
      BeakScreenRole.read,
    },
    BeakUriLauncher? launcher,
  }) {
    late final BeakRecordAction action;
    action = BeakRecordAction(
      key: key,
      label: label,
      icon: icon,
      roles: roles,
      onExecute: (record, context) async {
        if (!context.checkPermission(action)) return;
        final destination = uri(record);
        if (destination == null) {
          throw const BeakValidationException(
            'No contact address is available.',
          );
        }
        await launchBeakUri(destination, launcher: launcher);
      },
    );
    return action;
  }

  /// Prints a fresh authorized persisted snapshot, never an unsaved form draft.
  /// The standard action runner handles errors and prevents repeat dispatch.
  factory BeakRecordAction.document({
    required String key,
    required String label,
    required BeakRecordDocument document,
    Set<BeakScreenRole> roles = const {
      BeakScreenRole.list,
      BeakScreenRole.read,
      BeakScreenRole.edit,
    },
    IconData? icon,
    BeakDocumentDelivery Function() beginDelivery = beginBeakDocumentDelivery,
  }) {
    late final BeakRecordAction action;
    action = BeakRecordAction(
      key: key,
      label: label,
      icon: icon ?? OiIcons.printer,
      roles: roles,
      onExecute: (record, context) async {
        if (!context.checkPermission(action)) return;
        final id = context.model.primaryKeyOf(record);
        if (id == null) {
          throw const BeakValidationException(
            'Save the record before printing.',
          );
        }
        final delivery = beginDelivery();
        var shown = false;
        try {
          final snapshot = await document.load(
            model: context.model,
            id: id,
            source: context.dataSource,
            formatting: BeakFormatting.of(context.buildContext),
          );
          if (!context.checkPermission(action)) return;
          await delivery.show(snapshot);
          shown = true;
        } finally {
          if (!shown) delivery.cancel();
        }
      },
    );
    return action;
  }

  /// Generated resource surfaces that expose this action. Shared read/edit
  /// forms follow their live mode, including in-place Edit and Cancel.
  /// This is presentation only; resource and server permissions still apply.
  final Set<BeakScreenRole> roles;

  /// Runs the action on [BeakRecord].
  final Future<void> Function(BeakRecord record, BeakActionContext context)
  onExecute;
}
// --8<-- [end:BeakRecordAction]

/// An action over the currently selected records.
///
/// [onExecute] receives every selected [BeakRecord] at once, so bulk work
/// (mass update, export) runs in a single pass. Surfaced through a
/// [BeakResource]'s `bulkActions`.
final class BeakBulkAction extends BeakAction {
  /// Creates a bulk action running [onExecute].
  const BeakBulkAction({
    required super.key,
    required super.label,
    required this.onExecute,
    super.icon,
    super.color,
    super.requiresConfirmation,
  });

  /// Applies a typed patch through a validation preview and per-record receipts.
  ///
  /// The built-in review handles progress, cancellation and interrupted saves.
  factory BeakBulkAction.edit({
    required String key,
    required String label,
    required List<BeakFieldChange<Object>> changes,
    IconData? icon,
  }) => BeakBulkAction(
    key: key,
    label: label,
    icon: icon ?? OiIcons.pencil,
    onExecute: (records, context) async {
      await context.overlays.dialog<void>(
        title: label,
        builder: (close) => SingleChildScrollView(
          child: BeakBulkEditView(
            model: context.model,
            records: records,
            changes: changes,
            dataSource: context.dataSource,
            title: label,
          ),
        ),
      );
      if (context.buildContext.mounted) await context.refresh?.call();
    },
  );

  /// Runs the action over the selection.
  final Future<void> Function(
    List<BeakRecord> records,
    BeakActionContext context,
  )
  onExecute;
}

/// A page-level action (e.g. "Create" or "Export all"), independent of any
/// record.
///
/// [onExecute] receives only the [BeakActionContext]. Surfaced through a
/// [BeakResource]'s `globalActions` alongside the built-in
/// [BeakCreateAction].
final class BeakGlobalAction extends BeakAction {
  /// Creates a global action running [onExecute].
  const BeakGlobalAction({
    required super.key,
    required super.label,
    required this.onExecute,
    super.icon,
    super.color,
    super.requiresConfirmation,
  });

  /// Runs the action.
  final Future<void> Function(BeakActionContext context) onExecute;
}
