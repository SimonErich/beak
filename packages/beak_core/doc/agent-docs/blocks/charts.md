# Charts

> Supply typed chart data and presentation for the chart families, including heatmap, bubble and candlestick.

`BeakChartBlock` describes a chart and its data source. Use it in cards, grids or a custom screen. Keep loading callbacks typed and return explicit empty data when no points exist. A failed request should retain an error state rather than manufacture values.

For counts, sums, conditional metrics and grouped charts, prefer [population summaries](summaries.md). They load the full authorized population and refresh automatically after mutations. Use custom loaders for data that does not fit the summary contract.

```dart title="packages/beak_frontend/lib/src/blocks/beak_chart_block.dart"
part of 'beak_block.dart';

/// A composable, data-bound chart: a query, a typed record→point mapping,
/// and the chart family to draw.
///
/// As a member of the block union, a chart drops into any grid, card, or
/// page. It runs [query] through the data source, maps records to typed
/// [BeakChartPoint]s via [map], and draws the [type] family. Bubble,
/// candlestick and heatmap charts have blocks of their own.
///
/// ```dart
/// BeakChartBlock(
///   title: 'Stock per variant',
///   type: BeakChartType.bar,
///   query: const ProductVariantModel().query(
///     filter: ProductVariantModel.active.eq(true),
///   ),
///   map: (records) => [
///     for (final record in records)
///       BeakChartPoint(
///         label: ProductVariantModel.name.readFrom(record) ?? '',
///         value: (ProductVariantModel.stock.readFrom(record) ?? 0).toDouble(),
///       ),
///   ],
///   span: const BeakSpan(columns: 8),
/// );
/// ```
final class BeakChartBlock extends BeakBlock {
  /// Creates a chart block.
  const BeakChartBlock({
    required this.title,
    required this.type,
    required this.query,
    required this.map,
    this.heightInPixels = 260,
    super.span,
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
