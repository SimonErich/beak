# Charts

> Draw a query as a line, bar, pie, donut, area, radar or funnel chart, or as a bubble, candlestick or heat map, by mapping records to typed points.

A chart block is a query and a function. The query says which rows, the function turns them into points, and the block draws them. After this page you can put any of ten chart shapes on a custom screen, and you know why the Aviary asks for the largest page before it draws a line.

For counts, sums and grouped totals, read [Population summaries](summaries.md) first. A summary is computed by the server over the whole population and refreshes after a write. A chart block draws the rows you query, so it fits data a summary cannot express: a time series of readings, a scatter of two columns, prices.

## At a glance

| Block | Point type | Draws |
| --- | --- | --- |
| `BeakChartBlock` | `BeakChartPoint` | one of seven families, chosen by `type` |
| `BeakBubbleChartBlock` | `BeakBubblePoint` | bubbles at (x, y), sized by a third value |
| `BeakCandlestickChartBlock` | `BeakCandle` | open, high, low and close per position |
| `BeakHeatmapChartBlock` | `BeakMatrixCell` | a grid of cells shaded by value |

`BeakChartType` picks the family of a `BeakChartBlock`, and every family maps from the same list of `BeakChartPoint`s:

```dart title="packages/beak_frontend/lib/src/blocks/beak_chart_data.dart"
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

  /// A radar chart — one axis per point, a single series of their values.
  radar,

  /// A funnel chart — one stage per point.
  funnel,
}
```

## A first chart

```dart title="examples/showcase/lib/pages/chart_blocks.dart"
BeakBlock _daily(String title, BeakChartType type) => BeakChartBlock(
  title: title,
  type: type,
  query: sightingsByDay(),
  map: sightingPoints,
);
```

The Aviary uses this one helper for a line and an area chart of birds seen per day. `title` heads the card and labels the chart for screen readers, `type` picks the family, and `heightInPixels` (260) bounds it, because charts need a bounded height.

The query and the mapper are ordinary Dart. The query goes through the panel's data source like any other:

```dart title="examples/showcase/lib/pages/chart_data.dart"
/// The largest page a server answers with, which holds every seeded row, so a
/// chart never draws a silently truncated first page (a query returns 25 rows
/// by default).
const BeakPagination chartPage = BeakPagination(
  perPage: BeakPagination.maxPerPage,
);
```

That page size is not decoration. A query returns 25 rows unless told otherwise, the sightings table has 28, and a chart over the default page silently draws 25 points and leaves the last three days off. Give a chart query a page size that covers your data, and sort it in the query, because the block draws the points in the order the mapper returns them.

The mapper receives the loaded records and returns typed points. It reads fields through the generated references (`readFrom(record)`), so no column name is a string:

```dart title="examples/showcase/lib/pages/chart_data.dart"
/// One line point per sighting day.
List<BeakChartPoint> sightingPoints(List<BeakRecord> records) => [
  for (final record in records)
    if (SightingModel.spottedOn.readFrom(record) case final DateTime day)
      BeakChartPoint(
        label: _dayLabel(day),
        value: (SightingModel.birdsSeen.readFrom(record) ?? 0).toDouble(),
      ),
];
```

`BeakChartPoint` has a `label`, a `value` and an optional `x`. The x position matters for line and area charts, where it defaults to the point's index. The other families use the label as the category, the segment or the axis name. A record that cannot produce a point (here a sighting without a date) is skipped by the mapper's own `if`, not by the block.

## The seven families

`BeakChartType` has `line`, `bar`, `pie`, `donut`, `area`, `radar` and `funnel`. They differ in what a point means:

| `type` | A point is | Reads |
| --- | --- | --- |
| `line`, `area` | a position on the x axis | `x` (or index) and `value` |
| `bar` | a category | `label` and `value` |
| `pie`, `donut` | a segment | `label` and `value` |
| `radar` | an axis with a value on it | `label` and `value`, one series |
| `funnel` | a stage | `label` and `value` |

The categorical families show a legend, and it has a limit. The Aviary's capacity charts (bar, pie, donut, radar and funnel) are fed only the four largest habitats, and the source says why:

```dart title="examples/showcase/lib/pages/chart_data.dart"
/// The four largest habitats, largest first.
///
/// Four, because a pie chart lays its legend out in the height it reserves
/// for one row, and more names than one row holds would overflow it.
BeakQuerySpec habitatsByCapacity() => const HabitatModel().query(
  sorts: [HabitatModel.capacity.descending()],
  pagination: const BeakPagination(perPage: 4),
);
```

A pie lays its legend out in the height it reserves for one row, so a fifth name would overflow it. Keep categorical charts to a handful of categories, or raise `heightInPixels`, as the Aviary does for these (360). For twenty categories, use a bar chart or a table.

```dart title="examples/showcase/lib/pages/chart_data.dart"
/// One category per habitat, sized by capacity.
List<BeakChartPoint> habitatPoints(List<BeakRecord> records) => [
  for (final record in records)
    BeakChartPoint(
      label: HabitatModel.name.readFrom(record) ?? '',
      value: (HabitatModel.capacity.readFrom(record) ?? 0).toDouble(),
    ),
];
```

## Advanced charts

Three shapes need more than a label and a value, so they have blocks of their own, each with its own point type.

### Bubbles

```dart title="examples/showcase/lib/pages/chart_blocks.dart"
BeakBlock _bubbles() => BeakBubbleChartBlock(
  title: 'Wingspan by weight, sized by clutch',
  query: specimensBySize(),
  map: specimenBubbles,
);
```

```dart title="examples/showcase/lib/pages/chart_data.dart"
/// One bubble per specimen: wingspan by weight, sized by clutch.
List<BeakBubblePoint> specimenBubbles(List<BeakRecord> records) => [
  for (final record in records)
    BeakBubblePoint(
      x: (SpecimenModel.wingspanInCentimeters.readFrom(record) ?? 0).toDouble(),
      y: SpecimenModel.weightInGrams.readFrom(record) ?? 0,
      size: (SpecimenModel.clutchSize.readFrom(record) ?? 1).toDouble(),
      label: SpecimenModel.commonName.readFrom(record),
    ),
];
```

A bubble sits at `x` and `y`, and its area encodes `size`. `label` is optional and names the point. Bubbles, candles and cells use `double`s throughout, so convert integers with `.toDouble()`, as the mapper does.

### Candlesticks

```dart title="examples/showcase/lib/pages/chart_blocks.dart"
BeakBlock _candles() => BeakCandlestickChartBlock(
  span: const BeakSpan(columns: 2),
  title: 'Birdseed per kilogram (candlestick)',
  query: candlesByDay(),
  map: priceCandles,
);
```

```dart title="examples/showcase/lib/pages/chart_data.dart"
/// One candle per trading day, numbered from the first.
List<BeakCandle> priceCandles(List<BeakRecord> records) => [
  for (final (index, record) in records.indexed)
    BeakCandle(
      x: index.toDouble(),
      open: PriceCandleModel.open.readFrom(record) ?? 0,
      high: PriceCandleModel.high.readFrom(record) ?? 0,
      low: PriceCandleModel.low.readFrom(record) ?? 0,
      close: PriceCandleModel.close.readFrom(record) ?? 0,
    ),
];
```

A candle carries `open`, `high`, `low` and `close` at a position `x`. The x axis is numeric: the Aviary numbers its candles from the first trading day, and a real time axis would put epoch milliseconds there. Charts of this kind have no date axis, so expect index labels.

### Heat maps

```dart title="examples/showcase/lib/pages/chart_blocks.dart"
BeakBlock _heatmap() => BeakHeatmapChartBlock(
  span: const BeakSpan(columns: 2),
  title: 'Birds seen by weekday and week',
  query: sightingsByDay(),
  map: sightingCells,
  rowLabels: weekdayLabels,
  columnLabels: weekLabels(4),
);
```

```dart title="examples/showcase/lib/pages/chart_data.dart"
/// Heat-map cells: weekday against week, valued by birds seen.
List<BeakMatrixCell> sightingCells(List<BeakRecord> records) {
  final days = [
    for (final record in records)
      if (SightingModel.spottedOn.readFrom(record) case final DateTime day)
        (day: day, birds: SightingModel.birdsSeen.readFrom(record) ?? 0),
  ];
  if (days.isEmpty) return const [];
  final first = days
      .map((entry) => entry.day)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  return [
    for (final (:day, :birds) in days)
      BeakMatrixCell(
        row: weekdayLabels[day.weekday - 1],
        column: 'Week ${day.difference(first).inDays ~/ 7 + 1}',
        value: birds.toDouble(),
      ),
  ];
}
```

A `BeakMatrixCell` names its `row` and `column` by string and carries a `value`. Without `rowLabels` and `columnLabels`, the block takes the distinct labels in the order it first sees them. With them, the order is yours, and a cell whose row or column is not in the list is dropped without a message. The Aviary lists Monday to Sunday and four weeks. A fifth week of data would vanish.

## Styling

Charts read the theme. Series and segments take their colors from the theme's chart palette (`colors.chart`), and the grid, axes, legend and density come from `components.chart`. Set them once in the panel theme and every chart follows. The bars and donuts inside a [summary](summaries.md) read the same axis, grid and legend tokens, though their series colors come from the summary's own palette. Foodio's theme, for example:

```dart title="examples/foodio-adminpanel/lib/theme/gabel_theme.dart"
chart: OiChartThemeData(
  grid: OiChartGridTheme(
    color: line,
    width: 1,
    dashPattern: const [1, 1],
  ),
  centerValueStyle: text(28, 32, weight: 560),
  legend: OiChartLegendTheme(
    iconSize: 8,
    valueIconSize: 10,
    markerGap: 6,
    valueLabelStyle: body,
    valueStyle: text(
      14,
      20,
      weight: 500,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
  ),
  axis: OiChartAxisTheme(
    labelGap: 8,
    labelStyle: text(12, 16, weight: 500, tracking: .12),
    labelColor: muted,
  ),
  density: const OiChartDensityTheme(
    padding: EdgeInsets.fromLTRB(40, 8, 0, 38),
    radialInset: 7,
    barWidth: 18,
    sectionSpacing: 24,
  ),
),
```

`axis.labelGap` is the gap between the plot and its tick labels, and null keeps each chart's default. The chart blocks have no color parameter, so a chart that must look different is a theme change. [Colors and tokens](../theming/colors-and-tokens.md) covers the palette.

## Rules and limits

- A chart shows what its query returns. The default page is 25 rows. Pass `pagination` and `sorts` in the query.
- No loading state. The chart draws empty, then fills in. A [summary](summaries.md) has one.
- A failed read is shown. The chart keeps what it drew before, shows the panel's error line above it and offers Retry.
- Refresh after a write. The block fetches again when a write to its table is confirmed through the panel's data source.
- The mapper runs on the client. Mapping happens in the app on the rows that arrived, so all the rows reach the device. For thousands of rows, aggregate on the server with a summary.
- Points are in mapper order. Nothing sorts them, and line and area charts draw a segment between neighbors, so sort the query or the mapper's output.
- Categorical legends are fixed-height. See the four-habitat query above.
- Heat map labels are strict. Cells outside the label lists are dropped.
- The tile and vector maps are separate blocks. See [Maps](maps.md).

## Verify it

The Aviary draws every family against fixture rows, and the page test fails on a mapper that throws:

```console
$ cd examples/showcase
$ flutter test --no-pub test/aviary_pages_test.dart
...
Charts renders
...
All tests passed!
```

To see the page-size effect yourself, ask the Aviary API for the sightings the way a chart without `pagination` would:

```console
$ curl -s -X POST localhost:8082/api/sightings/query -H 'content-type: application/json' \
    -d '{"table":"sightings"}' | jq -c '{items: (.items | length), total, perPage}'
{"items":25,"total":28,"perPage":25}
```

## Reference

Required parameters are marked with a star. Every block also takes `span`.

| Block | Parameters (default) |
| --- | --- |
| `BeakChartBlock` | `title`*, `type`*, `query`*, `map`*, `heightInPixels` (260) |
| `BeakBubbleChartBlock` | `title`*, `query`*, `map`*, `heightInPixels` (300) |
| `BeakCandlestickChartBlock` | `title`*, `query`*, `map`*, `heightInPixels` (320) |
| `BeakHeatmapChartBlock` | `title`*, `query`*, `map`*, `rowLabels`, `columnLabels`, `heightInPixels` (320) |

| Point type | Fields |
| --- | --- |
| `BeakChartPoint` | `label`*, `value`*, `x` |
| `BeakBubblePoint` | `x`*, `y`*, `size`*, `label` |
| `BeakCandle` | `x`*, `open`*, `high`*, `low`*, `close`* |
| `BeakMatrixCell` | `row`*, `column`*, `value`* |

The mapper types are `BeakChartMapper`, `BeakBubbleMapper`, `BeakCandleMapper` and `BeakMatrixMapper`, each a function from `List<BeakRecord>` to a list of its point type:

```dart title="packages/beak_frontend/lib/src/blocks/beak_chart_data.dart"
typedef BeakChartMapper =
    List<BeakChartPoint> Function(List<BeakRecord> records);
```

Every block class with its constructor is on [Blocks](../reference/blocks.md).

## Continue reading

- [Maps](maps.md) shade countries or pin coordinates from a query.
- [Population summaries](summaries.md) server-side totals with loading, error and refresh built in.
- [Dashboards](../panel/dashboards.md) charts next to metrics on an overview page.
- [Colors and tokens](../theming/colors-and-tokens.md) the palette every chart reads.
