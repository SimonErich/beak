part of 'beak_block.dart';

/// A colored status pill. Renders onto `OiBadge`.
final class BeakBadgeBlock extends BeakBlock {
  /// Creates a badge labelled [label] in [color].
  const BeakBadgeBlock(
    this.label, {
    this.color = BeakColor.primary,
    super.span,
  });

  /// The badge text.
  final String label;

  /// The badge color.
  final BeakColor color;
}
