import 'package:flutter/widgets.dart';
import 'package:obers_ui_charts/obers_ui_charts.dart';

import 'beak_chart_data.dart';

/// Renders [points] as the [type] chart family from `obers_ui_charts`,
/// titled [title].
///
/// The single mapping from typed [BeakChartPoint]s to obers chart widgets,
/// used by the `BeakChartBlock` renderer. Internal to the package: the
/// barrel does not export it.
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
  BeakChartType.radar => OiRadarChart(
    label: title,
    axes: [for (final point in points) point.label],
    series: [
      OiRadarSeries(
        label: title,
        values: [for (final point in points) point.value],
      ),
    ],
  ),
  BeakChartType.funnel => OiFunnelChart(
    label: title,
    stages: [
      for (final point in points)
        OiFunnelStage(label: point.label, value: point.value),
    ],
  ),
};
