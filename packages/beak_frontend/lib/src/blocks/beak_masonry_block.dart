part of 'beak_block.dart';

/// Distributes children across vertical columns, each column packing
/// items top-down (Pinterest-style).
///
/// Renders onto `OiMasonry`.
final class BeakMasonryBlock extends BeakBlock {
  /// Creates a masonry layout of [children] across [columns].
  const BeakMasonryBlock({
    required this.children,
    this.columns = 3,
    this.gapInPixels = 16,
    super.span,
  }) : assert(columns >= 1, 'columns must be >= 1');

  /// The blocks to distribute.
  final List<BeakBlock> children;

  /// Number of vertical columns.
  final int columns;

  /// Spacing between columns and items.
  final double gapInPixels;
}
