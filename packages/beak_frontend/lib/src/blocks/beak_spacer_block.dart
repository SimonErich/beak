part of 'beak_block.dart';

/// Fixed vertical whitespace between blocks.
final class BeakSpacerBlock extends BeakBlock {
  /// Creates [heightInPixels] of vertical space.
  const BeakSpacerBlock({this.heightInPixels = 16, super.span});

  /// The whitespace height.
  final double heightInPixels;
}
