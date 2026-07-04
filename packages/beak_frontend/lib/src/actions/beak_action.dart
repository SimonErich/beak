import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../data/optimistic.dart';
import '../panel/beak_routes.dart';

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
final class BeakActionContext {
  /// Creates the execution context handed to every action.
  const BeakActionContext({
    required this.buildContext,
    required this.model,
    required this.dataSource,
    required this.router,
    this.refresh,
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
}

/// A typed panel action: what it is called, how it renders, and whether it
/// asks before running.
///
/// The sealed hierarchy fixes the three target shapes — one record
/// ([BeakRecordAction]), the current selection ([BeakBulkAction]), or the
/// page ([BeakGlobalAction]) — so surfaces switch over them exhaustively.
/// The built-in view/edit/delete/create actions subclass these; declare
/// custom ones on a [BeakResource] to extend the generated pages.
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
final class BeakRecordAction extends BeakAction {
  /// Creates a record action running [onExecute].
  const BeakRecordAction({
    required super.key,
    required super.label,
    required this.onExecute,
    super.icon,
    super.color,
    super.requiresConfirmation,
  });

  /// Runs the action on [BeakRecord].
  final Future<void> Function(BeakRecord record, BeakActionContext context)
  onExecute;
}

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
