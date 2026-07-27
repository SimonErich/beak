import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'activity_heat_cell.beak.dart';

/// The activity-heatmap resource — the matrix behind the heatmap chart.
@Resource(table: 'activity_heatmap')
final class ActivityHeatCell extends BeakSchema {
  /// The row key (weekday).
  @Display()
  @Column(label: 'Weekday', searchable: true)
  late final String? rowLabel;

  /// The column key (month).
  @Column(label: 'Month', searchable: true)
  late final String? columnLabel;

  /// The cell's magnitude (order count).
  @Column(label: 'Orders', sortable: true, min: 0)
  late final int? value;

  /// Deterministic cell order: weekday-major, months chronological — the
  /// heatmap sorts by this so its first-seen column order is stable.
  @Column(label: 'Order', sortable: true, min: 0)
  late final int? sortIndex;
}
