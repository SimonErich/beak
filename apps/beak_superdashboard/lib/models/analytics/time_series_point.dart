import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the time-series-points resource — one tall table that
/// backs every line/area/bar chart, keyed by [series].
abstract final class TimeSeriesPointColumns {
  /// Series key, e.g. `sales_revenue` or `audience_organic`.
  static const series = BeakStringColumn(
    key: 'series',
    label: 'Series',
    filterable: true,
    rules: [BeakRequired(), BeakMaxLength(60)],
  );

  /// Bucket label shown on the axis, e.g. `Jan`.
  static const label = BeakStringColumn(
    key: 'label',
    label: 'Label',
    rules: [BeakRequired(), BeakMaxLength(40)],
  );

  /// Measured value.
  static const value = BeakDecimalColumn(
    key: 'value',
    label: 'Value',
    sortable: true,
  );

  /// The bucket's moment, for time ordering.
  static const bucketDate = BeakDateTimeColumn(
    key: 'bucket_date',
    label: 'Date',
    sortable: true,
  );

  /// Ordering index within a series.
  static const sortIndex = BeakIntColumn(
    key: 'sort_index',
    label: 'Order',
    min: 0,
    sortable: true,
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    series,
    label,
    value,
    bucketDate,
    sortIndex,
  ];
}

/// The time-series-points resource — chart data as rows.
final class TimeSeriesPointModel extends BeakModel {
  /// Creates the time-series-points model.
  const TimeSeriesPointModel();

  @override
  String get table => 'time_series_points';

  @override
  String get displayColumnKey => 'label';

  @override
  List<BeakColumn> get columns => TimeSeriesPointColumns.values;

  @override
  List<BeakRelationship> get relationships => const [];
}
