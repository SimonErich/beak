import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../file_rules/beak_dimensions.dart';
import 'beak_image_transform.dart';

/// Executes an image column's transform pipeline on upload.
///
/// `beak_core` deliberately ships no pixel codec: implementations live in
/// driver-level packages that bring an image library. The upload
/// endpoint reads the size from the header through [inspect], checks the
/// column's dimension rules, and only then decodes once through [run] before
/// storing the results via the configured `BeakStorageDriver`.
// --8<-- [start:BeakTransformRunner]
abstract interface class BeakTransformRunner {
  /// Reads the pixel size [source] declares without decoding a pixel.
  ///
  /// This is what makes a dimension rule enforceable before memory is spent:
  /// a few dozen bytes can declare a bitmap of gigabytes. Throws a
  /// `BeakValidationException` when [source] is not a readable supported
  /// image.
  Future<BeakDimensions> inspect(Uint8List source);

  /// Runs [pipeline] over [source] in order and returns the transformed
  /// primary image plus any named variants (e.g. thumbnails).
  ///
  /// Decodes [source] once, and refuses one whose declared size is beyond
  /// what the implementation is willing to hold in memory.
  Future<BeakTransformedImage> run(
    Uint8List source,
    List<BeakImageTransform> pipeline,
  );
}
// --8<-- [end:BeakTransformRunner]

/// The output of a transform pipeline: encoded bytes plus decoded metadata.
///
/// Thumbnail steps yield entries in [variants], keyed by their configured
/// variant name; a variant's own [variants] map is always empty.
@immutable
final class BeakTransformedImage {
  /// Creates a transformed image of [bytes] with decoded metadata.
  const BeakTransformedImage({
    required this.bytes,
    required this.mimeType,
    required this.dimensions,
    this.variants = const {},
  });

  /// The encoded image bytes.
  final Uint8List bytes;

  /// MIME type of the encoding, e.g. `image/webp`.
  final String mimeType;

  /// Pixel dimensions of the encoded image.
  final BeakDimensions dimensions;

  /// Additional named renditions produced by thumbnail steps.
  final Map<String, BeakTransformedImage> variants;
}
