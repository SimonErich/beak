---
title: Charts
description: Supply typed chart data and presentation for the chart families, including heatmap, bubble and candlestick.
type: guide
audience: [beginner, expert]
status: draft
---

# Charts

`BeakChartBlock` describes a chart and its data source. Use it in cards, grids or a custom screen. Keep loading callbacks typed and return explicit empty data when no points exist. A failed request should retain an error state rather than manufacture values.

For counts, sums, conditional metrics and grouped charts, prefer [population summaries](summaries.md). They load the full authorized population and refresh automatically after mutations. Use custom loaders for data that does not fit the summary contract.

```dart title="packages/beak_frontend/lib/src/blocks/beak_chart_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_chart_block.dart"
```

## Continue reading

- [Dashboards](../panel/dashboards.md)
- [Advanced charts](charts.md)


## Tick label spacing

`OiChartAxisTheme.labelGap` sets the separation between the plot and axis tick
labels. It applies to Cartesian charts and standalone `OiChartAxisWidget`;
bar category labels use the same override. Null preserves existing defaults:
4px for numeric/grid ticks, and the existing bar category spacing. This changes
label placement, not data bounds or bar/category sizing.

```dart
OiChartThemeData(axis: OiChartAxisTheme(labelGap: 8))
```

Configure this through the Obers component chart theme. A theme copy preserves
the token, and gap changes repaint axis labels.
