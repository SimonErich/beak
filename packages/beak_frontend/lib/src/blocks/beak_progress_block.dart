part of 'beak_block.dart';

/// A labelled linear progress bar. Renders onto `OiProgress`.
final class BeakProgressBlock extends BeakBlock {
  /// Creates a progress bar filled to [value] (0..1), optionally captioned.
  const BeakProgressBlock({required this.value, this.label, super.span});

  /// Fill fraction in the range 0..1.
  final double value;

  /// An optional caption shown above the bar.
  final String? label;
}
