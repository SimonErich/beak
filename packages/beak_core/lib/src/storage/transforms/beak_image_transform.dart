import 'package:meta/meta.dart';

import '../../common/beak_exception.dart';
import '../../common/json_support.dart';
import '../file_rules/beak_dimensions.dart';
import '../file_rules/beak_file_type.dart';

/// How a resize maps the source image onto the target box.
enum BeakImageFit {
  /// Fill the box preserving aspect ratio, cropping any overflow.
  cover,

  /// Fit inside the box preserving aspect ratio, leaving no crop.
  contain,

  /// Match the box exactly, distorting the aspect ratio if needed.
  fill,
}

/// A raster output format an image can be re-encoded to.
enum BeakImageFormat {
  /// JPEG encoding.
  jpg,

  /// PNG encoding.
  png,

  /// WebP encoding.
  webp;

  /// The [BeakFileType] this format produces.
  BeakFileType get fileType => switch (this) {
    jpg => BeakFileType.jpeg,
    png => BeakFileType.png,
    webp => BeakFileType.webp,
  };
}

/// A single step of an image column's transform pipeline, executed in
/// declaration order on upload by a `BeakTransformRunner` implementation.
///
/// The hierarchy is sealed and losslessly JSON-serializable so runners
/// switch exhaustively and pipelines can travel over the wire.
@immutable
sealed class BeakImageTransform {
  const BeakImageTransform();

  /// Resizes to [widthInPixels] and/or [heightInPixels] using [fit]; the
  /// aspect ratio is preserved when only one target dimension is given.
  const factory BeakImageTransform.resize({
    int? widthInPixels,
    int? heightInPixels,
    BeakImageFit fit,
  }) = BeakResizeTransform;

  /// Re-encodes as [format] at [quality] (0–100).
  const factory BeakImageTransform.format({
    required BeakImageFormat format,
    int quality,
  }) = BeakFormatTransform;

  /// Re-encodes as WebP at [quality] (0–100).
  const factory BeakImageTransform.webp({int quality}) =
      BeakFormatTransform.webp;

  /// Produces an additional [name]d rendition of [size].
  const factory BeakImageTransform.thumbnail({
    required BeakDimensions size,
    String name,
  }) = BeakThumbnailTransform;

  /// Decodes [json] (produced by [toJson]) back into a transform step.
  ///
  /// Throws a [BeakConfigurationException] on malformed input.
  static BeakImageTransform fromJson(Map<String, Object?> json) =>
      switch (json) {
        {'type': 'resize'} => BeakResizeTransform(
          widthInPixels: requireJsonIntOrNull(
            json,
            'widthInPixels',
            'BeakResizeTransform',
          ),
          heightInPixels: requireJsonIntOrNull(
            json,
            'heightInPixels',
            'BeakResizeTransform',
          ),
          fit: _fitByName(
            requireJsonString(json, 'fit', 'BeakResizeTransform'),
          ),
        ),
        {'type': 'format'} => BeakFormatTransform(
          format: _formatByName(
            requireJsonString(json, 'format', 'BeakFormatTransform'),
          ),
          quality: requireJsonInt(json, 'quality', 'BeakFormatTransform'),
        ),
        {'type': 'thumbnail'} => BeakThumbnailTransform(
          size: BeakDimensions.fromJson(
            requireJsonMap(json, 'size', 'BeakThumbnailTransform'),
          ),
          name: requireJsonString(json, 'name', 'BeakThumbnailTransform'),
        ),
        _ => throw BeakConfigurationException(
          'Malformed BeakImageTransform JSON: $json.',
        ),
      };

  static BeakImageFit _fitByName(String name) {
    final BeakImageFit? fit = BeakImageFit.values.asNameMap()[name];
    if (fit == null) {
      throw BeakConfigurationException('"$name" is not a BeakImageFit.');
    }
    return fit;
  }

  static BeakImageFormat _formatByName(String name) {
    final BeakImageFormat? format = BeakImageFormat.values.asNameMap()[name];
    if (format == null) {
      throw BeakConfigurationException('"$name" is not a BeakImageFormat.');
    }
    return format;
  }

  /// This transform step as a plain JSON-encodable object.
  Map<String, Object?> toJson();
}

/// Resize step; see [BeakImageTransform.resize].
final class BeakResizeTransform extends BeakImageTransform {
  /// Creates a resize step targeting [widthInPixels] and/or [heightInPixels].
  const BeakResizeTransform({
    this.widthInPixels,
    this.heightInPixels,
    this.fit = BeakImageFit.contain,
  }) : assert(
         widthInPixels != null || heightInPixels != null,
         'resize needs at least one target dimension',
       );

  /// Target width in pixels, if constrained.
  final int? widthInPixels;

  /// Target height in pixels, if constrained.
  final int? heightInPixels;

  /// How the source maps onto the target box.
  final BeakImageFit fit;

  @override
  Map<String, Object?> toJson() => {
    'type': 'resize',
    'widthInPixels': widthInPixels,
    'heightInPixels': heightInPixels,
    'fit': fit.name,
  };

  @override
  bool operator ==(Object other) =>
      other is BeakResizeTransform &&
      other.widthInPixels == widthInPixels &&
      other.heightInPixels == heightInPixels &&
      other.fit == fit;

  @override
  int get hashCode => Object.hash(widthInPixels, heightInPixels, fit);

  @override
  String toString() =>
      'BeakResizeTransform(width: $widthInPixels, height: $heightInPixels, '
      'fit: ${fit.name})';
}

/// Format re-encode step; see [BeakImageTransform.format].
final class BeakFormatTransform extends BeakImageTransform {
  /// Creates a re-encode step producing [format] at [quality] (0–100).
  const BeakFormatTransform({required this.format, this.quality = 80})
    : assert(quality >= 0 && quality <= 100, 'quality must be within 0–100');

  /// Creates a WebP re-encode step at [quality] (0–100).
  const BeakFormatTransform.webp({int quality = 80})
    : this(format: BeakImageFormat.webp, quality: quality);

  /// The output format to encode to.
  final BeakImageFormat format;

  /// Encoding quality from 0 (smallest) to 100 (lossless-like).
  final int quality;

  @override
  Map<String, Object?> toJson() => {
    'type': 'format',
    'format': format.name,
    'quality': quality,
  };

  @override
  bool operator ==(Object other) =>
      other is BeakFormatTransform &&
      other.format == format &&
      other.quality == quality;

  @override
  int get hashCode => Object.hash(format, quality);

  @override
  String toString() => 'BeakFormatTransform(${format.name}, quality: $quality)';
}

/// Thumbnail rendition step; see [BeakImageTransform.thumbnail].
final class BeakThumbnailTransform extends BeakImageTransform {
  /// Creates a thumbnail step rendering at [size], stored as the [name]d
  /// variant of the file.
  const BeakThumbnailTransform({required this.size, this.name = 'thumbnail'})
    : assert(name.length > 0, 'name must not be empty');

  /// Pixel dimensions of the generated thumbnail.
  final BeakDimensions size;

  /// Variant name the rendition is stored under.
  final String name;

  @override
  Map<String, Object?> toJson() => {
    'type': 'thumbnail',
    'size': size.toJson(),
    'name': name,
  };

  @override
  bool operator ==(Object other) =>
      other is BeakThumbnailTransform &&
      other.size == size &&
      other.name == name;

  @override
  int get hashCode => Object.hash(size, name);

  @override
  String toString() => 'BeakThumbnailTransform($name, $size)';
}
