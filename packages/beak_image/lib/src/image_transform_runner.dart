import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:image/image.dart' as img;

/// The raster formats the runner can decode *and* re-encode — exactly the
/// image types Beak's file rules admit into image columns
/// ([BeakFileType.images]).
enum _RunnerFormat {
  /// PNG in/out.
  png('image/png'),

  /// JPEG in/out.
  jpg('image/jpeg'),

  /// WebP in/out (encoding is lossless, see [ImageTransformRunner]).
  webp('image/webp'),

  /// GIF in/out (first frame only); reachable only as a source format.
  gif('image/gif');

  const _RunnerFormat(this.mimeType);

  /// MIME type of the encoded bytes.
  final String mimeType;

  /// The format of already-stored [bytes], or `null` when it is not a
  /// supported raster format.
  static _RunnerFormat? forSource(Uint8List bytes) {
    final img.ImageFormat detected;
    try {
      detected = img.findFormatForData(bytes);
    } on Object {
      // package:image's format probes read past the end of tiny buffers.
      return null;
    }
    return switch (detected) {
      img.ImageFormat.png => png,
      img.ImageFormat.jpg => jpg,
      img.ImageFormat.webp => webp,
      img.ImageFormat.gif => gif,
      _ => null,
    };
  }

  /// The runner format producing a [BeakImageFormat] target.
  static _RunnerFormat forTarget(BeakImageFormat format) => switch (format) {
    BeakImageFormat.jpg => jpg,
    BeakImageFormat.png => png,
    BeakImageFormat.webp => webp,
  };

  /// Encodes [image] in this format; [qualityPercent] applies to lossy
  /// encoders only.
  Uint8List encode(img.Image image, int qualityPercent) => switch (this) {
    png => img.encodePng(image),
    jpg => img.encodeJpg(image, quality: qualityPercent),
    webp => img.encodeWebP(image),
    gif => img.encodeGif(image),
  };
}

/// Executes `BeakImageTransform` pipelines with `package:image` — the
/// concrete [BeakTransformRunner] the upload endpoint registers (Phase 09).
///
/// Sources must be one of the raster formats image columns accept (PNG,
/// JPEG, WebP, GIF); anything else throws a [BeakValidationException].
/// Thumbnails are cover-cropped to their exact configured size and encoded
/// with the format state at their point in the pipeline. WebP output uses
/// `package:image`'s lossless encoder, so a format step's quality applies to
/// JPEG only.
final class ImageTransformRunner implements BeakTransformRunner {
  /// Creates a transform runner.
  const ImageTransformRunner();

  /// JPEG quality applied when the pipeline sets no format step.
  static const int defaultQualityPercent = 80;

  @override
  Future<BeakTransformedImage> run(
    Uint8List source,
    List<BeakImageTransform> pipeline,
  ) async {
    final _RunnerFormat? sourceFormat = _RunnerFormat.forSource(source);
    if (sourceFormat == null) {
      throw const BeakValidationException(
        'The uploaded file is not a supported raster image '
        '(PNG, JPEG, WebP or GIF).',
      );
    }
    final img.Image? decoded = img.decodeImage(source);
    if (decoded == null) {
      throw const BeakValidationException(
        'The uploaded file could not be decoded as an image.',
      );
    }
    if (pipeline.isEmpty) {
      return BeakTransformedImage(
        bytes: source,
        mimeType: sourceFormat.mimeType,
        dimensions: _dimensionsOf(decoded),
      );
    }

    img.Image image = decoded;
    _RunnerFormat format = sourceFormat;
    int qualityPercent = defaultQualityPercent;
    final Map<String, BeakTransformedImage> variants = {};
    for (final BeakImageTransform step in pipeline) {
      switch (step) {
        case BeakResizeTransform():
          image = _resize(image, step);
        case BeakFormatTransform(format: final target, :final quality):
          format = _RunnerFormat.forTarget(target);
          qualityPercent = quality;
        case BeakThumbnailTransform(:final size, :final name):
          if (variants.containsKey(name)) {
            throw BeakConfigurationException(
              'The transform pipeline produces two "$name" variants; '
              'thumbnail names must be unique.',
            );
          }
          final img.Image thumbnail = _cover(
            image,
            size.widthInPixels,
            size.heightInPixels,
          );
          variants[name] = BeakTransformedImage(
            bytes: format.encode(thumbnail, qualityPercent),
            mimeType: format.mimeType,
            dimensions: _dimensionsOf(thumbnail),
          );
      }
    }
    return BeakTransformedImage(
      bytes: format.encode(image, qualityPercent),
      mimeType: format.mimeType,
      dimensions: _dimensionsOf(image),
      variants: variants,
    );
  }

  static BeakDimensions _dimensionsOf(img.Image image) =>
      BeakDimensions(widthInPixels: image.width, heightInPixels: image.height);

  static img.Image _resize(img.Image image, BeakResizeTransform step) {
    final int? width = step.widthInPixels;
    final int? height = step.heightInPixels;
    if (width == null || height == null) {
      // A single-dimension target leaves nothing to crop or distort: every
      // fit degenerates to an aspect-preserving scale.
      return img.copyResize(
        image,
        width: width,
        height: height,
        interpolation: img.Interpolation.linear,
      );
    }
    return switch (step.fit) {
      BeakImageFit.contain => _contain(image, width, height),
      BeakImageFit.cover => _cover(image, width, height),
      BeakImageFit.fill => img.copyResize(
        image,
        width: width,
        height: height,
        interpolation: img.Interpolation.linear,
      ),
    };
  }

  static img.Image _contain(img.Image image, int width, int height) {
    final double scale = math.min(width / image.width, height / image.height);
    return img.copyResize(
      image,
      width: math.max(1, (image.width * scale).round()),
      height: math.max(1, (image.height * scale).round()),
      interpolation: img.Interpolation.linear,
    );
  }

  static img.Image _cover(img.Image image, int width, int height) {
    final double scale = math.max(width / image.width, height / image.height);
    final int scaledWidth = math.max(width, (image.width * scale).round());
    final int scaledHeight = math.max(height, (image.height * scale).round());
    final img.Image scaled = img.copyResize(
      image,
      width: scaledWidth,
      height: scaledHeight,
      interpolation: img.Interpolation.linear,
    );
    return img.copyCrop(
      scaled,
      x: (scaledWidth - width) ~/ 2,
      y: (scaledHeight - height) ~/ 2,
      width: width,
      height: height,
    );
  }
}
