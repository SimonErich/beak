import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';

import '../data/optimistic.dart';

part 'built_in_actions.dart';

/// Everything an executing action may reach for: the resource's model, the
/// data source, the router for navigation, the build context for overlays
/// (confirmations, optimistic undo), and a hook to refresh the surface the
/// action ran from.
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
/// asks before running. The sealed hierarchy fixes the three target shapes
/// — one record, the selection, or the page — so surfaces switch
/// exhaustively.
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

/// A page-level action (e.g. "Create"), independent of any record.
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
