part of 'beak_block.dart';

/// A data-bound video player — plays the first row of [query]. Renders onto
/// `OiVideoPlayer`.
final class BeakVideoBlock extends BeakBlock {
  /// Creates a video block over [query], reading its source from [urlField]
  /// and an optional poster from [posterField].
  const BeakVideoBlock({
    required this.query,
    required this.urlField,
    this.posterField,
    this.title,
    this.autoPlay = false,
    this.loop = false,
    super.span,
  });

  /// The query whose first row supplies the video.
  final BeakQuerySpec query;

  /// The column holding the video source URL.
  final BeakColumn urlField;

  /// The column holding an optional poster image URL.
  final BeakColumn? posterField;

  /// An accessible label / caption for the player.
  final String? title;

  /// Whether the video starts playing automatically.
  final bool autoPlay;

  /// Whether the video loops.
  final bool loop;
}
