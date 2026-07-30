import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'time_series_point.beak.dart';

/// The time-series-points resource — chart data as rows.
@Resource()
final class TimeSeriesPoint extends BeakSchema {
  /// Series key, e.g. `sales_revenue` or `audience_organic`.
  @Column(filterable: true, rules: [BeakMaxLength(60)])
  late final String series;

  /// Bucket label shown on the axis, e.g. `Jan`.
  @Display()
  @Column(rules: [BeakMaxLength(40)])
  late final String label;

  /// Measured value.
  @Column(sortable: true)
  late final double? value;

  /// The bucket's moment, for time ordering.
  @Column(label: 'Date', sortable: true)
  late final DateTime? bucketDate;

  /// Ordering index within a series.
  @Column(label: 'Order', sortable: true, min: 0)
  late final int? sortIndex;
}
