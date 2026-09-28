import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';

import '../blocks/beak_chart_data.dart';
import '../blocks/beak_chart_family.dart';
import '../data/beak_resource_repository.dart';

export '../blocks/beak_chart_data.dart';

/// A dashboard chart: a query, a typed record→point mapping, and the
/// chart family to render with (`obers_ui_charts`).
///
/// List these on [BeakPanelConfig.dashboardCharts]. The [query] runs
/// through the repository, [map] turns the returned records into typed
/// [BeakChartPoint]s, and [type] picks the chart family.
///
/// ```dart
/// BeakChart(
///   title: 'Stock per variant',
///   type: BeakChartType.bar,
///   query: const ProductVariantModel().query(),
///   map: stockPerVariant,
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
