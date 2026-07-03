import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:obers_ui/obers_ui.dart';

import 'beak_chart.dart';
import 'beak_stat.dart';

/// The generated dashboard: a row of aggregate stat cards over the data
/// source followed by the configured charts — zero per-panel dashboard
/// code.
class BeakDashboard extends HookWidget {
  /// Creates the dashboard rendering [stats] and [charts] over
  /// [dataSource].
  const BeakDashboard({
    required this.stats,
    required this.charts,
    required this.dataSource,
    super.key,
  });

  /// The metric cards, in order.
  final List<BeakStat> stats;

  /// The charts, in order.
  final List<BeakChart> charts;

  /// The source stats and charts load from.
  final BeakDataSource dataSource;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: OiColumn(
      breakpoint: context.breakpoint,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stats.isNotEmpty)
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final stat in stats)
                SizedBox(
                  width: 220,
                  child: BeakStatCard(stat: stat, dataSource: dataSource),
                ),
            ],
          ),
        for (final chart in charts)
          BeakChartCard(chart: chart, dataSource: dataSource),
      ],
    ),
  );
}
