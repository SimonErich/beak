part of 'beak_block.dart';

/// Lays its children out horizontally with a uniform gap.
///
/// Renders onto `OiRow`, which collapses into a column on narrow
/// breakpoints so rows stay readable on small screens.
final class BeakRowBlock extends BeakBlock {
  /// Creates a horizontal run of [children] separated by [gapInPixels].
  const BeakRowBlock({
    required this.children,
    this.gapInPixels = 16,
    super.span,
  });

  /// The blocks to lay out, start to end.
  final List<BeakBlock> children;

  /// Horizontal spacing between children.
  final double gapInPixels;
}
