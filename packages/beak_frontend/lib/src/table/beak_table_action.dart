import 'package:flutter/widgets.dart';

/// A typed row or bulk action surfaced on a [BeakDataTable] — the table
/// widget's raw hook. The resource-level action system (`BeakAction` and
/// friends) adapts onto it in the generated pages; use this directly only
/// when composing a table without `BeakResource`.
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

  /// Runs the action over the target records' raw primary keys (row and
  /// bulk invocations both deliver the typed key values, never
  /// stringified row keys).
  final Future<void> Function(List<Object> recordIds) onRun;
}
