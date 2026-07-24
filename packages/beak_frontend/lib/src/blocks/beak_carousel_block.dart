part of 'beak_block.dart';

/// A content/image carousel bound to a query — each row becomes a slide.
///
/// Renders onto `OiCarousel` (autoplay, arrows, indicators). [query] returns
/// the slides; [imageUrlField] is the image URL and [captionField] an
/// optional caption. Slide content comes from seeded data, never hardcoded.
final class BeakCarouselBlock extends BeakBlock {
  /// Creates a carousel block.
  const BeakCarouselBlock({
    required this.query,
    required this.imageUrlField,
    this.captionField,
    this.heightInPixels = 320,
    this.autoplay = true,
    super.span,
  });

  /// The query producing one row per slide.
  final BeakQuerySpec query;

  /// The column holding each slide's image URL.
  final BeakColumn imageUrlField;

  /// The column holding each slide's caption, if any.
  final BeakColumn? captionField;

  /// Rendered height.
  final double heightInPixels;

  /// Whether the carousel advances on its own.
  final bool autoplay;
}
