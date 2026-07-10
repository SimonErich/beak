part of 'beak_block.dart';

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

  /// The chart heading.
  final String title;

  /// The query supplying the records.
  final BeakQuerySpec query;

  /// Maps the records to matrix cells.
  final BeakMatrixMapper map;

  /// An explicit row order, if any (otherwise inferred from the cells).
  final List<String>? rowLabels;

  /// An explicit column order, if any (otherwise inferred from the cells).
  final List<String>? columnLabels;

  /// The chart height in pixels.
  final double heightInPixels;
}
