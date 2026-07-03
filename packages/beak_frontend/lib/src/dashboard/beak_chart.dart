import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:obers_ui_charts/obers_ui_charts.dart';

import '../data/beak_resource_repository.dart';

/// The chart families a [BeakChart] can render as.
enum BeakChartType {
  /// A line chart over the mapped points.
  line,

  /// A bar chart, one category per point.
  bar,

  /// A pie chart, one segment per point.
  pie,

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
typedef BeakChartMapper =
    List<BeakChartPoint> Function(List<BeakRecord> records);

/// A dashboard chart: a query, a typed record→point mapping, and the
/// chart family to render with (`obers_ui_charts`).
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

/// Renders one [BeakChart]: runs its query through the repository, maps
/// the records to typed points, and draws the configured chart family.
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
        child: _chartOf(points.value),
      ),
    );
  }

  Widget _chartOf(List<BeakChartPoint> points) => switch (chart.type) {
    BeakChartType.line => OiLineChart(
      label: chart.title,
      series: [
        OiLineSeries(
          label: chart.title,
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
      label: chart.title,
      categories: [
        for (final point in points)
          OiBarCategory(label: point.label, values: [point.value]),
      ],
    ),
    BeakChartType.pie => OiPieChart(
      label: chart.title,
      segments: [
        for (final point in points)
          OiPieSegment(label: point.label, value: point.value),
      ],
    ),
    BeakChartType.area => OiAreaChart<BeakChartPoint>(
      label: chart.title,
      series: [
        OiAreaSeries<BeakChartPoint>(
          id: chart.title,
          label: chart.title,
          data: points,
          xMapper: (point) => point.x ?? points.indexOf(point).toDouble(),
          yMapper: (point) => point.value,
        ),
      ],
    ),
  };
}
