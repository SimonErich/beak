import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../file_rules/beak_dimensions.dart';
import 'beak_image_transform.dart';

/// Executes an image column's transform pipeline on upload.
///
/// `beak_core` deliberately ships no pixel codec: implementations live in
/// driver-level packages (Phase 06) that bring an image library. The upload
/// endpoint decodes, runs the configured pipeline through this interface and
/// stores the results via the configured `BeakStorageDriver`.
abstract interface class BeakTransformRunner {
  /// Runs [pipeline] over [source] in order and returns the transformed
  /// primary image plus any named variants (e.g. thumbnails).
  Future<BeakTransformedImage> run(
    Uint8List source,
    List<BeakImageTransform> pipeline,
  );
}

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
