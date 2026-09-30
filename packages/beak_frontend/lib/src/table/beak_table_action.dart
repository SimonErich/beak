import 'package:flutter/widgets.dart';
import 'package:beak_core/beak_core.dart';
import '../presentation/beak_action_presentation.dart';
import '../presentation/beak_record_template.dart';

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
    this.visibleWhen,
    this.placement = BeakActionPlacement.icon,
    this.semanticLabel,
    this.labelValue,
    this.selectionLabel,
    this.group,
  });

  /// Stable identifier (test hooks, telemetry).
  final String id;

  /// The button label.
  final String label;

  /// Optional record-aware label; dependencies are loaded with table rows.
  final BeakValueBinding<String>? labelValue;

  /// Optional count-aware label for selection actions.
  final String Function(int count)? selectionLabel;

  /// Semantic grouping in an overflow menu.
  final String? group;

  /// Full action name retained when the visible label is shortened.
  final String? semanticLabel;

  /// The icon shown on row-action buttons.
  final IconData? icon;

  /// Whether the action destroys data (rendered destructively).
  final bool destructive;

  /// Optional row-level availability, reevaluated when the record refreshes.
  final bool Function(BeakRecord record)? visibleWhen;

  /// Placement when composed in a row.
  final BeakActionPlacement placement;

  /// Runs the action over the target records' raw primary keys (row and
  /// bulk invocations both deliver the typed key values, never
  /// stringified row keys).
  final Future<void> Function(List<Object> recordIds) onRun;
}
