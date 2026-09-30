import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:image/image.dart' as img;

import 'image_header.dart';

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

/// Executes [BeakImageTransform] pipelines with `package:image` — the
/// concrete [BeakTransformRunner] the upload endpoint registers.
///
/// Sources must be one of the raster formats image columns accept (PNG,
/// JPEG, WebP, GIF); anything else, and any damaged file, throws a
/// [BeakValidationException]. An animated GIF is read for its first frame.
/// Thumbnails are cover-cropped to their exact configured size and encoded
/// with the format state at their point in the pipeline. WebP output uses
/// `package:image`'s lossless encoder, so a format step's quality applies to
/// JPEG only.
///
/// A file can be a few dozen bytes and still declare a bitmap of gigabytes,
/// and a decoder allocates the declared bitmap first. So [inspect] reads the
/// size from the header alone (the upload endpoint checks the column's
/// dimension rules against it), and [run] refuses anything above
/// [maxPixelCount] before it decodes.
///
/// It is stateless and `const`-constructible; register one instance with the
/// backend and reuse it for every upload:
///
/// ```dart
/// const runner = ImageTransformRunner();
/// final result = await runner.run(sourceBytes, const [
///   BeakImageTransform.resize(
///     widthInPixels: 800,
///     heightInPixels: 800,
///     fit: BeakImageFit.cover,
///   ),
///   BeakImageTransform.format(format: BeakImageFormat.jpg, quality: 85),
/// ]);
/// print(result.mimeType); // image/jpeg
/// print(result.dimensions); // 800x800
/// ```
final class ImageTransformRunner implements BeakTransformRunner {
  /// Creates a transform runner that decodes images of up to [maxPixelCount]
  /// pixels.
  const ImageTransformRunner({this.maxPixelCount = defaultMaxPixelCount})
    : assert(maxPixelCount > 0, 'maxPixelCount must be positive');

  /// JPEG quality (0–100) applied when the pipeline includes no format step.
  static const int defaultQualityPercent = 80;

  /// The default [maxPixelCount]: 50 megapixels, above any phone or DSLR
  /// photo and about 200 MB decoded.
  static const int defaultMaxPixelCount = 50 * 1000 * 1000;

  /// The most pixels (width times height) [run] decodes; a larger declared
  /// bitmap is refused with a [BeakValidationException] before any pixel is
  /// allocated.
  final int maxPixelCount;

  /// Reads the size [source] declares from its header, decoding nothing.
  ///
  /// Throws a [BeakValidationException] when [source] is not a readable
  /// PNG, JPEG, WebP or GIF.
  @override
  Future<BeakDimensions> inspect(Uint8List source) async =>
      readImageHeaderDimensions(source) ??
      (throw const BeakValidationException(
        'The uploaded file is not a supported raster image '
        '(PNG, JPEG, WebP or GIF).',
      ));

  /// Runs [pipeline] over the encoded [source] image in declaration order.
  ///
  /// Returns the transformed primary image plus any thumbnail variants keyed
  /// by name. An empty [pipeline] passes [source] through untouched (same
  /// bytes, same MIME type). Throws a [BeakValidationException] when [source]
  /// is not a decodable PNG/JPEG/WebP/GIF, and a [BeakConfigurationException]
  /// when two thumbnail steps share a variant name.
  ///
  /// ```dart
  /// final transformed = await const ImageTransformRunner().run(
  ///   bytes,
  ///   const [
  ///     BeakImageTransform.thumbnail(
  ///       size: BeakDimensions(widthInPixels: 64, heightInPixels: 64),
  ///       name: 'avatar',
  ///     ),
  ///   ],
  /// );
  /// final avatarBytes = transformed.variants['avatar']!.bytes;
  /// ```
  @override
  Future<BeakTransformedImage> run(
    Uint8List source,
    List<BeakImageTransform> pipeline,
  ) async {
    final BeakDimensions declared = await inspect(source);
    _requireWithinCeiling(declared);
    final _RunnerFormat? sourceFormat = _RunnerFormat.forSource(source);
    if (sourceFormat == null) {
      throw const BeakValidationException(
        'The uploaded file is not a supported raster image '
        '(PNG, JPEG, WebP or GIF).',
      );
    }
    final img.Image decoded = _decodeFirstFrame(source);
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

  /// Decodes [source], its first frame only: every frame of a decoded
  /// animation is a full bitmap in memory, so the pixel ceiling would count
  /// one frame of many.
  ///
  /// A damaged file makes the codec throw whatever it tripped over (a
  /// `RangeError`, an `ImageException`); that is the uploader's mistake, so it
  /// leaves as a [BeakValidationException] like any other undecodable file. So
  /// does a stream that decodes to an empty bitmap.
  static img.Image _decodeFirstFrame(Uint8List source) {
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(source, frame: 0);
    } on Object {
      throw const BeakValidationException(
        'The uploaded file could not be decoded as an image.',
      );
    }
    // A damaged stream can decode to an empty bitmap.
    if (decoded == null || decoded.width < 1 || decoded.height < 1) {
      throw const BeakValidationException(
        'The uploaded file could not be decoded as an image.',
      );
    }
    return decoded;
  }

  void _requireWithinCeiling(BeakDimensions declared) {
    final int width = declared.widthInPixels;
    final int height = declared.heightInPixels;
    // Each side is checked first so the product cannot overflow.
    if (width > maxPixelCount ||
        height > maxPixelCount ||
        width * height > maxPixelCount) {
      throw BeakValidationException(
        'The image is $width x $height pixels; at most $maxPixelCount '
        'pixels are accepted.',
      );
    }
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
