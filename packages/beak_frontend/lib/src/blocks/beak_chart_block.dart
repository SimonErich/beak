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
