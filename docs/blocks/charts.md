---
title: Charts
description: Draw a query as a line, bar, pie, donut, area, radar or funnel chart, or as a bubble, candlestick or heat map, by mapping records to typed points.
type: guide
audience: [beginner, expert]
status: stable
---

# Charts

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
--8<-- "packages/beak_frontend/lib/src/blocks/beak_chart_data.dart:BeakChartType"
```

## A first chart

```dart title="examples/showcase/lib/pages/chart_blocks.dart"
--8<-- "examples/showcase/lib/pages/chart_blocks.dart:chart"
```

The Aviary uses this one helper for a line and an area chart of birds seen per day. `title` heads the card and labels the chart for screen readers, `type` picks the family, and `heightInPixels` (260) bounds it, because charts need a bounded height.

The query and the mapper are ordinary Dart. The query goes through the panel's data source like any other:

```dart title="examples/showcase/lib/pages/chart_data.dart"
--8<-- "examples/showcase/lib/pages/chart_data.dart:chartPage"
```

That page size is not decoration. A query returns 25 rows unless told otherwise, the sightings table has 28, and a chart over the default page silently draws 25 points and leaves the last three days off. Give a chart query a page size that covers your data, and sort it in the query, because the block draws the points in the order the mapper returns them.

The mapper receives the loaded records and returns typed points. It reads fields through the generated references (`readFrom(record)`), so no column name is a string:

```dart title="examples/showcase/lib/pages/chart_data.dart"
--8<-- "examples/showcase/lib/pages/chart_data.dart:sightingPoints"
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
--8<-- "examples/showcase/lib/pages/chart_data.dart:habitatsByCapacity"
```

A pie lays its legend out in the height it reserves for one row, so a fifth name would overflow it. Keep categorical charts to a handful of categories, or raise `heightInPixels`, as the Aviary does for these (360). For twenty categories, use a bar chart or a table.

```dart title="examples/showcase/lib/pages/chart_data.dart"
--8<-- "examples/showcase/lib/pages/chart_data.dart:habitatPoints"
```

## Advanced charts

Three shapes need more than a label and a value, so they have blocks of their own, each with its own point type.

### Bubbles

```dart title="examples/showcase/lib/pages/chart_blocks.dart"
--8<-- "examples/showcase/lib/pages/chart_blocks.dart:bubbles"
```

```dart title="examples/showcase/lib/pages/chart_data.dart"
--8<-- "examples/showcase/lib/pages/chart_data.dart:specimenBubbles"
```

A bubble sits at `x` and `y`, and its area encodes `size`. `label` is optional and names the point. Bubbles, candles and cells use `double`s throughout, so convert integers with `.toDouble()`, as the mapper does.

### Candlesticks

```dart title="examples/showcase/lib/pages/chart_blocks.dart"
--8<-- "examples/showcase/lib/pages/chart_blocks.dart:candles"
```

```dart title="examples/showcase/lib/pages/chart_data.dart"
--8<-- "examples/showcase/lib/pages/chart_data.dart:priceCandles"
```

A candle carries `open`, `high`, `low` and `close` at a position `x`. The x axis is numeric: the Aviary numbers its candles from the first trading day, and a real time axis would put epoch milliseconds there. Charts of this kind have no date axis, so expect index labels.

### Heat maps

```dart title="examples/showcase/lib/pages/chart_blocks.dart"
--8<-- "examples/showcase/lib/pages/chart_blocks.dart:heatmap"
```

```dart title="examples/showcase/lib/pages/chart_data.dart"
--8<-- "examples/showcase/lib/pages/chart_data.dart:sightingCells"
```

A `BeakMatrixCell` names its `row` and `column` by string and carries a `value`. Without `rowLabels` and `columnLabels`, the block takes the distinct labels in the order it first sees them. With them, the order is yours, and a cell whose row or column is not in the list is dropped without a message. The Aviary lists Monday to Sunday and four weeks. A fifth week of data would vanish.

## Styling

Charts read the theme. Series and segments take their colors from the theme's chart palette (`colors.chart`), and the grid, axes, legend and density come from `components.chart`. Set them once in the panel theme and every chart follows. The bars and donuts inside a [summary](summaries.md) read the same axis, grid and legend tokens, though their series colors come from the summary's own palette. Foodio's theme, for example:

```dart title="examples/foodio-adminpanel/lib/theme/gabel_theme.dart"
--8<-- "examples/foodio-adminpanel/lib/theme/gabel_theme.dart:gabelChartTheme"
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
--8<-- "packages/beak_frontend/lib/src/blocks/beak_chart_data.dart:BeakChartMapper"
```

Every block class with its constructor is on [Blocks](../reference/blocks.md).

## Continue reading

- [Maps](maps.md) shade countries or pin coordinates from a query.
- [Population summaries](summaries.md) server-side totals with loading, error and refresh built in.
- [Dashboards](../panel/dashboards.md) charts next to metrics on an overview page.
- [Colors and tokens](../theming/colors-and-tokens.md) the palette every chart reads.
