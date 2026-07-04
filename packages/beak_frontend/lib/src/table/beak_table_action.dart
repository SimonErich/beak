import 'package:flutter/widgets.dart';

/// A typed row or bulk action surfaced on a [BeakDataTable] — the table
/// widget's raw hook. The resource-level action system (`BeakAction` and
/// friends) adapts onto it in the generated pages; use this directly only
/// when composing a table without `BeakResource`.
///
/// The same type serves both surfaces: passed in [BeakDataTable.actions] it
/// renders one icon button per row (invoked with that single row's key), and
/// in [BeakDataTable.bulkActions] it renders in the selection bar (invoked
/// with every selected key). [onRun] always receives the raw primary-key
/// values, never stringified row keys.
///
/// ```dart
/// BeakTableAction(
///   id: 'archive',
///   label: 'Archive',
///   icon: OiIcons.archive,
///   destructive: true,
///   onRun: (recordIds) async {
///     for (final id in recordIds) {
///       await dataSource.delete('products', id);
///     }
///   },
/// )
/// ```
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
