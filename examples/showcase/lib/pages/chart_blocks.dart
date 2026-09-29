import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

import 'chart_data.dart';

/// Every chart family, each bound to a query and a mapper from records to
/// points.
BeakScreen chartBlocksPage() => BeakScreen(
  path: '/charts',
  title: 'Charts',
  icon: const BeakIconToken(OiIcons.chartBar),
  navigationGroup: 'Blocks',
  body: BeakGridBlock(
    columns: 2,
    gapInPixels: 20,
    children: [
      _daily('Birds seen (line)', BeakChartType.line),
      _daily('Birds seen (area)', BeakChartType.area),
      _capacity('Capacity (bar)', BeakChartType.bar),
      _capacity('Capacity (pie)', BeakChartType.pie),
      _capacity('Capacity (donut)', BeakChartType.donut),
      _capacity('Capacity (radar)', BeakChartType.radar),
      _capacity('Capacity (funnel)', BeakChartType.funnel),
      _bubbles(),
      _candles(),
      _heatmap(),
    ],
  ),
);

/// A chart is a query, a type and the mapper turning its rows into points.
// --8<-- [start:chart]
BeakBlock _daily(String title, BeakChartType type) => BeakChartBlock(
  title: title,
  type: type,
  query: sightingsByDay(),
  map: sightingPoints,
);
// --8<-- [end:chart]

/// The same block over another table, with another mapper and more height for
/// the legends of the categorical charts.
BeakBlock _capacity(String title, BeakChartType type) => BeakChartBlock(
  title: title,
  type: type,
  query: habitatsByCapacity(),
  map: habitatPoints,
  heightInPixels: 360,
);

/// Wingspan against weight, sized by clutch.
// --8<-- [start:bubbles]
BeakBlock _bubbles() => BeakBubbleChartBlock(
  title: 'Wingspan by weight, sized by clutch',
  query: specimensBySize(),
  map: specimenBubbles,
);
// --8<-- [end:bubbles]

/// Open, high, low and close.
// --8<-- [start:candles]
BeakBlock _candles() => BeakCandlestickChartBlock(
  span: const BeakSpan(columns: 2),
  title: 'Birdseed per kilogram (candlestick)',
  query: candlesByDay(),
  map: priceCandles,
);
// --8<-- [end:candles]

/// Weekday against week.
// --8<-- [start:heatmap]
BeakBlock _heatmap() => BeakHeatmapChartBlock(
  span: const BeakSpan(columns: 2),
  title: 'Birds seen by weekday and week',
  query: sightingsByDay(),
  map: sightingCells,
  rowLabels: weekdayLabels,
  columnLabels: weekLabels(4),
);
// --8<-- [end:heatmap]
