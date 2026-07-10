part of 'beak_block.dart';

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

  /// The chart heading.
  final String title;

  /// The query supplying the records.
  final BeakQuerySpec query;

  /// Maps the records to bubble points.
  final BeakBubbleMapper map;

  /// The chart height in pixels.
  final double heightInPixels;
}
