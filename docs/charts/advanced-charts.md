---
title: Advanced charts
description: The three richer chart blocks (bubble, candlestick, and heatmap), each with its own typed point and mapper for data a single value cannot describe.
---

# Advanced charts

After this page you can draw the three chart families that need more than a label
and a value: a bubble chart (an x/y position sized by a third measure), a
candlestick chart (open, high, low, close), and a heatmap (a value at a row and
column). Each is a block with its own typed point and mapper, and each follows
the same query-plus-mapper shape as the [single-series charts](chart-basics.md).

All three examples come from the showcase app (`apps/beak_superdashboard`, port
8180), which seeds a small analytics table behind each one.

## Bubble charts

A `BeakBubbleChartBlock` turns each record into a point at (x, y) sized by a third
value, drawing onto `OiBubbleChart`. Use it when two continuous measures relate
and a third weights the point, price against stock weighted by cost, say.

```dart title="packages/beak_frontend/lib/src/blocks/beak_bubble_chart_block.dart"
/// A data-bound bubble chart: each record becomes an (x, y) point sized by a
/// third value. Renders onto `OiBubbleChart`.
final class BeakBubbleChartBlock extends BeakBlock {
  /// Creates a bubble chart titled [title] over [query].
  const BeakBubbleChartBlock({
    required this.title,
    required this.query,
    required this.map,
    this.heightInPixels = 300,
    super.span,
  });
```

Its point carries the three axes plus an optional label:

```dart title="packages/beak_frontend/lib/src/dashboard/beak_chart.dart"
/// One point of a bubble chart: a position ([x], [y]) plus a magnitude
/// ([size], the third dimension), optionally [label]led.
final class BeakBubblePoint {
  /// Creates a bubble at ([x], [y]) sized by [size].
  const BeakBubblePoint({
    required this.x,
    required this.y,
    required this.size,
    this.label,
  });

  /// The horizontal position.
  final double x;

  /// The vertical position.
  final double y;

  /// The bubble's magnitude (its area encodes this).
  final double size;

  /// An optional label for the point.
  final String? label;
}
```

The mapper is a `BeakBubbleMapper` (`List<BeakBubblePoint> Function(List<BeakRecord>)`).
The showcase reads the catalog: price on x, stock on y, cost as the bubble size.

```dart title="apps/beak_superdashboard/lib/services/dashboard_charts.dart"
/// Maps `products` rows onto bubble points: price × stock, sized by cost.
List<BeakBubblePoint> productBubblePoints(List<BeakRecord> records) => [
  for (final record in records)
    BeakBubblePoint(
      x: _asDouble(record['price']?.raw),
      y: _asDouble(record['stock']?.raw),
      size: _asDouble(record['cost']?.raw),
      label: record['name']?.raw?.toString(),
    ),
];
```

Drop it into a grid like any block:

```dart title="apps/beak_superdashboard/lib/screens/charts_screen.dart"
const BeakBubbleChartBlock(
  title: 'Catalog: price × stock, sized by cost',
  query: BeakQuerySpec(table: 'products', pagination: analyticsPage),
  map: productBubblePoints,
),
```

## Candlestick charts

A `BeakCandlestickChartBlock` draws an OHLC (open, high, low, close) series onto
`OiCandlestickChart`, the classic financial bar. Each record is one candle.

```dart title="packages/beak_frontend/lib/src/blocks/beak_candlestick_chart_block.dart"
/// A data-bound candlestick (OHLC) chart. Renders onto `OiCandlestickChart`.
final class BeakCandlestickChartBlock extends BeakBlock {
  /// Creates a candlestick chart titled [title] over [query].
  const BeakCandlestickChartBlock({
    required this.title,
    required this.query,
    required this.map,
    this.heightInPixels = 320,
    super.span,
  });
```

The `BeakCandle` point holds the four prices at a horizontal position `x` (a day
index or epoch millis):

```dart title="packages/beak_frontend/lib/src/dashboard/beak_chart.dart"
/// One candle of an OHLC chart at position [x] (a time or index).
final class BeakCandle {
  /// Creates a candle at [x] with the four prices.
  const BeakCandle({
    required this.x,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  /// The horizontal position (e.g. a day index or epoch millis).
  final double x;

  /// The opening price.
  final double open;

  /// The session high.
  final double high;

  /// The session low.
  final double low;

  /// The closing price.
  final double close;
}
```

The mapper is a `BeakCandleMapper`. Because a candlestick chart is meaningless
out of order, the showcase sorts the rows by their `sort_index` before assigning
each an x position:

```dart title="apps/beak_superdashboard/lib/services/dashboard_charts.dart"
/// Maps `price_candles` rows onto ordered OHLC candles.
List<BeakCandle> priceCandles(List<BeakRecord> records) {
  final rows = [...records]
    ..sort((a, b) {
      final ai = (a['sort_index']?.raw as num?)?.toInt() ?? 0;
      final bi = (b['sort_index']?.raw as num?)?.toInt() ?? 0;
      return ai.compareTo(bi);
    });
  return [
    for (final (index, record) in rows.indexed)
      BeakCandle(
        x: index.toDouble(),
        open: _asDouble(record['open']?.raw),
        high: _asDouble(record['high']?.raw),
        low: _asDouble(record['low']?.raw),
        close: _asDouble(record['close']?.raw),
      ),
  ];
}
```

The four price columns come from a typed model like any other. The
`price_candles` resource declares them as `BeakDecimalColumn`s with a `$` prefix:

```dart title="apps/beak_superdashboard/lib/models/analytics/price_candle.dart"
/// The opening price.
static const open = BeakDecimalColumn(
  key: 'open',
  label: 'Open',
  prefix: r'$',
);
```

A candlestick is wide, so the showcase spans it across the whole grid:

```dart title="apps/beak_superdashboard/lib/screens/charts_screen.dart"
const BeakCandlestickChartBlock(
  span: BeakSpan(columns: 2),
  title: 'Price history (candlestick)',
  query: BeakQuerySpec(
    table: 'price_candles',
    sorts: [BeakSort('sort_index')],
    pagination: analyticsPage,
  ),
  map: priceCandles,
),
```

## Heatmaps

A `BeakHeatmapChartBlock` shades a row-by-column matrix of values onto
`OiHeatmap`, one cell per record. It adds two optional lists, `rowLabels` and
`columnLabels`, that fix the axis order when you do not want it inferred from the
cells.

```dart title="packages/beak_frontend/lib/src/blocks/beak_heatmap_chart_block.dart"
/// A data-bound heatmap over a row × column matrix of values. Renders onto
/// `OiHeatmap`.
final class BeakHeatmapChartBlock extends BeakBlock {
  /// Creates a heatmap titled [title] over [query].
  const BeakHeatmapChartBlock({
    required this.title,
    required this.query,
    required this.map,
    this.rowLabels,
    this.columnLabels,
    this.heightInPixels = 320,
    super.span,
  });
```

Its point is a `BeakMatrixCell`: a value at a named row and column.

```dart title="packages/beak_frontend/lib/src/dashboard/beak_chart.dart"
/// One cell of a heatmap matrix: a [value] at ([row], [column]).
final class BeakMatrixCell {
  /// Creates a heatmap cell.
  const BeakMatrixCell({
    required this.row,
    required this.column,
    required this.value,
  });

  /// The row key.
  final String row;

  /// The column key.
  final String column;

  /// The cell's magnitude.
  final double value;
}
```

The `BeakMatrixMapper` reads the row key, column key, and value straight off each
record:

```dart title="apps/beak_superdashboard/lib/services/dashboard_charts.dart"
/// Maps `activity_heatmap` rows onto matrix cells.
List<BeakMatrixCell> activityHeatCells(List<BeakRecord> records) => [
  for (final record in records)
    BeakMatrixCell(
      row: record['row_label']?.raw?.toString() ?? '',
      column: record['column_label']?.raw?.toString() ?? '',
      value: _asDouble(record['value']?.raw),
    ),
];
```

The showcase pins the weekday order explicitly with `rowLabels` so the rows read
Monday to Sunday rather than alphabetically:

```dart title="apps/beak_superdashboard/lib/screens/charts_screen.dart"
const BeakHeatmapChartBlock(
  span: BeakSpan(columns: 2),
  title: 'Orders by weekday & month',
  query: BeakQuerySpec(
    table: 'activity_heatmap',
    sorts: [BeakSort('sort_index')],
    pagination: analyticsPage,
  ),
  map: activityHeatCells,
  rowLabels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
),
```

!!! note "Order is your job, not the chart's"
    Candlesticks and heatmaps read left to right and top to bottom in whatever
    order the rows arrive. Both examples carry a `sort_index` column, sort on it
    (in the query and again in the mapper for the candles), and the heatmap pins
    its rows with `rowLabels`. Give the chart a deterministic order and it stays
    stable across seeds and backends.

## The three at a glance

| Block | Point | Mapper typedef | Renders onto | Default height |
| --- | --- | --- | --- | --- |
| `BeakBubbleChartBlock` | `BeakBubblePoint` (x, y, size, label?) | `BeakBubbleMapper` | `OiBubbleChart` | 300 |
| `BeakCandlestickChartBlock` | `BeakCandle` (x, open, high, low, close) | `BeakCandleMapper` | `OiCandlestickChart` | 320 |
| `BeakHeatmapChartBlock` | `BeakMatrixCell` (row, column, value) | `BeakMatrixMapper` | `OiHeatmap` | 320 |

## Continue reading

- [Chart basics](chart-basics.md) the seven single-series families and the mapper pattern these build on.
- [Maps](maps.md) the choropleth and tile-map blocks, same shape, geographic output.
- [Data blocks](../blocks/data-blocks.md) the wider family of data-bound blocks.
- [Column types](../models/column-types.md) the typed columns the analytics models declare.
