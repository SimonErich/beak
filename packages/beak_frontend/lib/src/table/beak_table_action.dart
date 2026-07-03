import 'package:flutter/widgets.dart';

/// A typed row or bulk action surfaced on a [BeakDataTable] — Phase 14
/// grows this into the full action system; the shape stays source-typed
/// (no stringly callbacks).
final class BeakTableAction {
  /// Creates an action.
  const BeakTableAction({
    required this.id,
    required this.label,
    required this.onRun,
    this.icon,
    this.destructive = false,
  });

  /// Stable identifier (test hooks, telemetry).
  final String id;

  /// The button label.
  final String label;

  /// The icon shown on row-action buttons.
  final IconData? icon;

  /// Whether the action destroys data (rendered destructively).
  final bool destructive;

  /// Runs the action over the target records' primary keys.
  final Future<void> Function(List<Object> recordIds) onRun;
}
