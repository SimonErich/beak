part of 'beak_block.dart';

/// A data-bound image gallery — each row becomes a thumbnail. Renders onto
/// `OiGallery`.
final class BeakGalleryBlock extends BeakBlock {
  /// Creates a gallery over [query].
  const BeakGalleryBlock({
    required this.query,
    required this.imageUrlField,
    this.captionField,
    this.columns = 4,
    super.span,
  });

  /// The query producing one row per image.
  final BeakQuerySpec query;

  /// The column holding each image's URL.
  final BeakColumn imageUrlField;

  /// The column holding each image's caption, if any.
  final BeakColumn? captionField;

  /// The number of columns.
  final int columns;
}
