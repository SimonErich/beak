import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:obers_ui_charts/obers_ui_charts.dart';

import '../data/beak_resource_repository.dart';

/// The chart families a [BeakChart] or [BeakChartBlock] can render as.
///
/// Every family here maps from the same `List<BeakChartPoint>` shape; richer
/// shapes (scatter, bubble, candlestick, heatmap…) are the domain of the
/// showcase charts, added as they are wired.
enum BeakChartType {
  /// A line chart over the mapped points.
  line,

  /// A vertical bar chart, one category per point.
  bar,

  /// A pie chart, one segment per point.
  pie,

  /// A donut (ring) chart, one segment per point.
  donut,

  /// An area chart over the mapped points.
  area,
}

/// One typed chart data point — the shape [BeakChartMapper]s produce, so
/// mapping records to series never touches `dynamic`.
final class BeakChartPoint {
  /// Creates a point labelled [label] with [value]; [x] positions it on
  /// continuous axes (defaults to its index).
  const BeakChartPoint({required this.label, required this.value, this.x});

  /// The category/point label.
  final String label;

  /// The measured value.
  final double value;

  /// Explicit x position for line/area charts, if any.
  final double? x;
}

/// Maps a query's records onto typed chart points.
///
/// Implementations read fields through the shared column constants, never
/// string literals:
///
/// ```dart
/// List<BeakChartPoint> stockPerProduct(List<BeakRecord> records) => [
///   for (final record in records)
///     BeakChartPoint(
///       label: record[ProductColumns.name.key]?.raw?.toString() ?? '',
///       value: switch (record[ProductColumns.stock.key]?.raw) {
///         final num stock => stock.toDouble(),
///         _ => 0,
///       },
///     ),
/// ];
/// ```
typedef BeakChartMapper =
    List<BeakChartPoint> Function(List<BeakRecord> records);

/// A dashboard chart: a query, a typed record→point mapping, and the
/// chart family to render with (`obers_ui_charts`).
///
/// List these on [BeakPanelConfig.dashboardCharts]. The [query] runs
/// through the repository, [map] turns the returned records into typed
/// [BeakChartPoint]s, and [type] picks the chart family.
///
/// ```dart
/// const BeakChart(
///   title: 'Stock per product',
///   type: BeakChartType.bar,
///   query: BeakQuerySpec(table: 'products'),
///   map: stockPerProduct,
/// );
/// ```
final class BeakChart {
  /// Creates a chart titled [title] rendering [query] through [map].
  const BeakChart({
    required this.title,
    required this.type,
    required this.query,
    required this.map,
    this.heightInPixels = 260,
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

/// Renders one [BeakChart]: runs its query through a
/// [BeakResourceRepository], maps the records to typed points via
/// [BeakChart.map], and draws the configured chart family.
///
/// The dashboard builds these from [BeakPanelConfig.dashboardCharts]; the
/// card re-queries whenever its `dataSource` or `chart` changes and drops
/// the result if it unmounts mid-load. Query failures leave it empty.
class BeakChartCard extends HookWidget {
  /// Creates the card for [chart] over [dataSource].
  const BeakChartCard({
    required this.chart,
    required this.dataSource,
    super.key,
  });

  /// The chart on display.
  final BeakChart chart;

  /// The source the query runs against.
  final BeakDataSource dataSource;

  @override
  Widget build(BuildContext context) {
    final points = useState(const <BeakChartPoint>[]);
    useEffect(() {
      var cancelled = false;
      Future<void> load() async {
        final result = await BeakResourceRepository(
          dataSource,
        ).query(chart.query);
        if (cancelled) {
          return;
        }
        if (result case BeakOk(:final value)) {
          points.value = chart.map(value.items);
        }
      }

      load();
      return () => cancelled = true;
    }, [dataSource, chart]);

    return OiCard(
      title: OiLabel.smallStrong(chart.title),
      child: SizedBox(
        height: chart.heightInPixels,
        child: beakChartWidget(chart.type, chart.title, points.value),
      ),
    );
  }
}

/// Renders [points] as the [type] chart family from `obers_ui_charts`,
/// titled [title].
///
/// The single mapping from typed [BeakChartPoint]s to obers chart widgets —
/// shared by the dashboard's [BeakChartCard] and the composable
/// `BeakChartBlock` so both draw identical charts.
Widget beakChartWidget(
  BeakChartType type,
  String title,
  List<BeakChartPoint> points,
) => switch (type) {
  BeakChartType.line => OiLineChart(
    label: title,
    series: [
      OiLineSeries(
        label: title,
        points: [
          for (final (index, point) in points.indexed)
            OiLinePoint(
              x: point.x ?? index.toDouble(),
              y: point.value,
              label: point.label,
            ),
        ],
      ),
    ],
  ),
  BeakChartType.bar => OiBarChart(
    label: title,
    categories: [
      for (final point in points)
        OiBarCategory(label: point.label, values: [point.value]),
    ],
  ),
  BeakChartType.pie => OiPieChart(
    label: title,
    segments: [
      for (final point in points)
        OiPieSegment(label: point.label, value: point.value),
    ],
  ),
  BeakChartType.donut => OiDonutChart(
    label: title,
    segments: [
      for (final point in points)
        OiPieSegment(label: point.label, value: point.value),
    ],
  ),
  BeakChartType.area => OiAreaChart<BeakChartPoint>(
    label: title,
    series: [
      OiAreaSeries<BeakChartPoint>(
        id: title,
        label: title,
        data: points,
        xMapper: (point) => point.x ?? points.indexOf(point).toDouble(),
        yMapper: (point) => point.value,
      ),
    ],
  ),
};
