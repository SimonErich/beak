part of 'beak_block.dart';

/// A composable, data-bound chart: a query, a typed record→point mapping,
/// and the chart family to draw.
///
/// Where `BeakChart` lives only on the flat dashboard, a [BeakChartBlock]
/// joins the block union, so charts drop into any grid, card, or page. It
/// runs [query] through the data source, maps records to typed
/// [BeakChartPoint]s via [map], and draws the [type] family.
///
/// ```dart
/// BeakChartBlock(
///   title: 'Sales this year',
///   type: BeakChartType.area,
///   query: BeakQuerySpec(table: 'time_series_points', filter: salesSeries),
///   map: (records) => [for (final r in records) BeakChartPoint(...)],
///   span: BeakSpan(columns: 8),
/// );
/// ```
final class BeakChartBlock extends BeakBlock {
  /// Creates a chart block.
  const BeakChartBlock({
    required this.title,
    required this.type,
    required this.query,
    required this.map,
    this.heightInPixels = 260,
    super.span,
  });

  /// The chart heading.
  final String title;

  /// The chart family.
  final BeakChartType type;

  /// The query producing the chart's records.
  final BeakQuerySpec query;

  /// The typed record→point mapping.
  final BeakChartMapper map;

  /// Rendered height (charts need bounded constraints).
  final double heightInPixels;
}
