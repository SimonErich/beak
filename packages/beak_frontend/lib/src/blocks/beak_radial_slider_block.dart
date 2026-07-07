part of 'beak_block.dart';

/// An interactive knob input — drag around the arc to pick a value.
///
/// Renders onto `OiRadialSlider`. A self-contained showcase control: it owns
/// its value locally (no binding), demonstrating the round-slider widget.
final class BeakRadialSliderBlock extends BeakBlock {
  /// Creates a radial slider labelled [label].
  const BeakRadialSliderBlock({
    required this.label,
    this.min = 0,
    this.max = 100,
    this.initialValue = 40,
    this.sizeInPixels = 200,
    super.span,
  });

  /// The control label.
  final String label;

  /// The minimum value.
  final double min;

  /// The maximum value.
  final double max;

  /// The value the knob starts at.
  final double initialValue;

  /// The rendered diameter.
  final double sizeInPixels;
}
