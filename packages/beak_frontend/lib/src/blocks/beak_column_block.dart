part of 'beak_block.dart';

/// Lays its children out vertically with a uniform gap.
///
/// Children stretch to the full available width — the natural shape for
/// stacked page content. Renders onto `OiColumn`.
final class BeakColumnBlock extends BeakBlock {
  /// Creates a vertical stack of [children] separated by [gapInPixels].
  const BeakColumnBlock({
    required this.children,
    this.gapInPixels = 16,
    super.span,
  });

  /// The blocks to stack, top to bottom.
  final List<BeakBlock> children;

  /// Vertical spacing between children.
  final double gapInPixels;
}
