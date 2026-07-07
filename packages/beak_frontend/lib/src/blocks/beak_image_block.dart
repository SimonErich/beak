part of 'beak_block.dart';

/// An image loaded from a URL.
///
/// Renders onto `OiImage` with the panel's placeholder and error states.
final class BeakImageBlock extends BeakBlock {
  /// Creates an image block for [url], described by [alt].
  const BeakImageBlock(
    this.url, {
    required this.alt,
    this.widthInPixels,
    this.heightInPixels,
    this.fit = BoxFit.cover,
    super.span,
  });

  /// The image source URL.
  final String url;

  /// Accessibility description of the image.
  final String alt;

  /// Fixed render width, when set.
  final double? widthInPixels;

  /// Fixed render height, when set.
  final double? heightInPixels;

  /// How the image fills its box.
  final BoxFit fit;
}
