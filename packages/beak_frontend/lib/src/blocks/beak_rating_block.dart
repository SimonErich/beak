part of 'beak_block.dart';

/// A star rating. Renders onto `OiStarRating`.
final class BeakRatingBlock extends BeakBlock {
  /// Creates a rating showing [value] out of [maxStars].
  const BeakRatingBlock({
    required this.value,
    this.maxStars = 5,
    this.readOnly = true,
    super.span,
  });

  /// The current rating.
  final double value;

  /// The number of stars.
  final int maxStars;

  /// Whether the rating is display-only.
  final bool readOnly;
}
