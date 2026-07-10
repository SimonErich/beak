import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the activity-heatmap resource — one row × column cell of
/// the orders-by-weekday-and-month heatmap.
abstract final class ActivityHeatCellColumns {
  /// The row key (weekday).
  static const rowLabel = BeakStringColumn(
    key: 'row_label',
    label: 'Weekday',
    searchable: true,
  );

  /// The column key (month).
  static const columnLabel = BeakStringColumn(
    key: 'column_label',
    label: 'Month',
    searchable: true,
  );

  /// The cell's magnitude (order count).
  static const value = BeakIntColumn(
    key: 'value',
    label: 'Orders',
    min: 0,
    sortable: true,
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    rowLabel,
    columnLabel,
    value,
  ];
}

/// The activity-heatmap resource — the matrix behind the heatmap chart.
final class ActivityHeatCellModel extends BeakModel {
  /// Creates the activity-heatmap model.
  const ActivityHeatCellModel();

  @override
  String get table => 'activity_heatmap';

  @override
  String get displayColumnKey => 'row_label';

  @override
  List<BeakColumn> get columns => ActivityHeatCellColumns.values;
}
