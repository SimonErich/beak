part of 'beak_block.dart';

/// Lays its children out horizontally with a uniform gap.
///
/// A natural row preserves intrinsic child widths. An [expand] row distributes
/// available width by each child's span, and stacks when its smallest child
/// would become narrower than [minChildWidthInPixels].
final class BeakRowBlock extends BeakBlock {
  /// Creates a horizontal run of [children] separated by [gapInPixels].
  // --8<-- [start:BeakRowBlock]
  const BeakRowBlock({
    required this.children,
    this.gapInPixels = 16,
    this.expand = false,
    this.minChildWidthInPixels = 240,
    super.span,
  }) : assert(gapInPixels >= 0),
       assert(minChildWidthInPixels >= 0);
  // --8<-- [end:BeakRowBlock]

  /// The blocks to lay out, start to end.
  final List<BeakBlock> children;

  /// Horizontal spacing between children.
  final double gapInPixels;

  /// Fills bounded horizontal space using child span columns as flex weights.
  /// Gaps are subtracted once between actual children, not imaginary tracks.
  /// Unspecified spans have weight one. Unbounded rows keep intrinsic widths.
  final bool expand;

  /// Minimum width of each expanded child before the row stacks vertically.
  /// Uses container constraints rather than the viewport breakpoint. Set zero
  /// to keep a weighted row at every width. Ignored when [expand] is false.
  final double minChildWidthInPixels;
}
