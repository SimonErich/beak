/// Image transform runner for Beak — executes [BeakImageTransform] pipelines
/// (resize, format re-encode, thumbnails) using `package:image`.
///
/// The single public type, [ImageTransformRunner], is the concrete
/// `BeakTransformRunner` the upload endpoint registers so image columns can
/// resize, re-encode and generate thumbnails on upload. `beak_core` ships no
/// pixel codec of its own, so wiring this package in is what gives an app
/// image processing.
///
/// ```dart
/// import 'package:beak_core/beak_core.dart';
/// import 'package:beak_image/beak_image.dart';
///
/// const runner = ImageTransformRunner();
/// final result = await runner.run(uploadedBytes, const [
///   BeakImageTransform.resize(widthInPixels: 1200),
///   BeakImageTransform.webp(quality: 82),
///   BeakImageTransform.thumbnail(
///     size: BeakDimensions(widthInPixels: 200, heightInPixels: 200),
///   ),
/// ]);
/// // result.bytes is the WebP-encoded primary image;
/// // result.variants['thumbnail'] is the 200x200 cover-cropped rendition.
/// ```
library;

export 'src/image_transform_runner.dart';

/// The version of the `beak_image` package.
const String beakImageVersion = '0.0.1';
