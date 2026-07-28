part of 'beak_block.dart';

/// Places its children on a column grid; each child's [BeakBlock.span]
/// decides how many tracks it covers.
///
/// Provide either a fixed [columns] count or a [minColumnWidthInPixels]
/// for an auto-fitting grid — not both. Renders onto `OiGrid` with
/// `OiSpan` placement, so spans resolve responsively.
final class BeakGridBlock extends BeakBlock {
  /// Creates a grid of [children].
  // --8<-- [start:BeakGridBlock]
  const BeakGridBlock({
    required this.children,
    this.columns,
    this.minColumnWidthInPixels,
    this.gapInPixels = 16,
    super.span,
  }) : assert(
         columns == null || minColumnWidthInPixels == null,
         'Provide either columns or minColumnWidthInPixels, not both.',
       );
  // --8<-- [end:BeakGridBlock]

  /// The blocks to place, in reading order.
  final List<BeakBlock> children;

  /// Fixed number of grid columns, when set.
  final int? columns;

  /// Minimum column width for an auto-fitting grid, when set.
  final double? minColumnWidthInPixels;

  /// Spacing between grid tracks.
  final double gapInPixels;
}
