/// Pure value objects backing Beak's image/file columns and their rules.
///
/// Declared here (not in the storage packages) so columns stay pure data:
/// Phase 05 builds the storage-driver layer on top of these types.
library;

import 'package:meta/meta.dart';

/// A known upload/file type, pairing a canonical MIME type with the file
/// extensions it is recognized by.
enum BeakFileType {
  /// JPEG raster image.
  jpeg('image/jpeg', ['jpg', 'jpeg']),

  /// PNG raster image.
  png('image/png', ['png']),

  /// WebP raster image.
  webp('image/webp', ['webp']),

  /// GIF raster image.
  gif('image/gif', ['gif']),

  /// SVG vector image.
  svg('image/svg+xml', ['svg']),

  /// PDF document.
  pdf('application/pdf', ['pdf']),

  /// Comma-separated values document.
  csv('text/csv', ['csv']),

  /// JSON document.
  json('application/json', ['json']),

  /// ZIP archive.
  zip('application/zip', ['zip']),

  /// MP4 video.
  mp4('video/mp4', ['mp4']),

  /// MP3 audio.
  mp3('audio/mpeg', ['mp3']);

  const BeakFileType(this.mimeType, this.extensions);

  /// Canonical MIME type, e.g. `image/png`.
  final String mimeType;

  /// Lower-case file extensions (without the leading dot) recognized as this
  /// type.
  final List<String> extensions;

  /// Whether this type belongs to the `image/` MIME family.
  bool get isImage => mimeType.startsWith('image/');

  /// The default set of raster image types accepted by image columns.
  ///
  /// [svg] is deliberately excluded (it can carry scripts and cannot be
  /// transformed like a raster); add it explicitly where needed.
  static const List<BeakFileType> images = [jpeg, png, webp, gif];
}

/// Pixel dimensions of an image or thumbnail rendition.
@immutable
final class BeakDimensions {
  /// Creates dimensions of [widthInPixels] by [heightInPixels].
  const BeakDimensions({
    required this.widthInPixels,
    required this.heightInPixels,
  }) : assert(widthInPixels > 0, 'widthInPixels must be positive'),
       assert(heightInPixels > 0, 'heightInPixels must be positive');

  /// Creates square dimensions of [sizeInPixels] per side.
  const BeakDimensions.square(int sizeInPixels)
    : this(widthInPixels: sizeInPixels, heightInPixels: sizeInPixels);

  /// Horizontal size in pixels.
  final int widthInPixels;

  /// Vertical size in pixels.
  final int heightInPixels;

  @override
  bool operator ==(Object other) =>
      other is BeakDimensions &&
      other.widthInPixels == widthInPixels &&
      other.heightInPixels == heightInPixels;

  @override
  int get hashCode => Object.hash(widthInPixels, heightInPixels);

  @override
  String toString() => 'BeakDimensions(${widthInPixels}x$heightInPixels)';
}

/// A single step of an image column's transform pipeline, executed in
/// declaration order on upload (Phase 05 implements the execution).
@immutable
sealed class BeakImageTransform {
  const BeakImageTransform();

  /// Resizes to [widthInPixels] and/or [heightInPixels]; the aspect ratio is
  /// preserved when only one target dimension is given.
  const factory BeakImageTransform.resize({
    int? widthInPixels,
    int? heightInPixels,
  }) = BeakResizeTransform;

  /// Re-encodes as WebP at [quality] (0–100).
  const factory BeakImageTransform.webp({int quality}) = BeakWebpTransform;

  /// Produces an additional thumbnail rendition of [size].
  const factory BeakImageTransform.thumbnail({required BeakDimensions size}) =
      BeakThumbnailTransform;
}

/// Resize step; see [BeakImageTransform.resize].
final class BeakResizeTransform extends BeakImageTransform {
  /// Creates a resize step targeting [widthInPixels] and/or [heightInPixels].
  const BeakResizeTransform({this.widthInPixels, this.heightInPixels})
    : assert(
        widthInPixels != null || heightInPixels != null,
        'resize needs at least one target dimension',
      );

  /// Target width in pixels, if constrained.
  final int? widthInPixels;

  /// Target height in pixels, if constrained.
  final int? heightInPixels;
}

/// WebP re-encode step; see [BeakImageTransform.webp].
final class BeakWebpTransform extends BeakImageTransform {
  /// Creates a WebP re-encode step at [quality] (0–100).
  const BeakWebpTransform({this.quality = 80})
    : assert(quality >= 0 && quality <= 100, 'quality must be within 0–100');

  /// Encoding quality from 0 (smallest) to 100 (lossless-like).
  final int quality;
}

/// Thumbnail rendition step; see [BeakImageTransform.thumbnail].
final class BeakThumbnailTransform extends BeakImageTransform {
  /// Creates a thumbnail step rendering at [size].
  const BeakThumbnailTransform({required this.size});

  /// Pixel dimensions of the generated thumbnail.
  final BeakDimensions size;
}
