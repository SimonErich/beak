# beak_image

The image transform runner of Beak. It executes the pipeline an image column
declares (resize, re-encode, thumbnails) on `package:image` and hands back the
processed image plus its named variants.

Part of [Beak](https://github.com/SimonErich/beak), a configuration-driven
admin-panel framework for Dart and Flutter. It is pure Dart.

## When you depend on it

An app does not have to. `beak_core` defines the image column, its
`BeakImageTransform` steps and the `BeakTransformRunner` interface, but ships no
pixel codec. `beak_backend` depends on this package and uses
`const ImageTransformRunner()` as the default `transformRunner` of its upload
service, so an image column on a Beak server transforms on upload with nothing to
register.

Depend on `beak_image` directly to run a pipeline outside the server, in a
worker or a script that reprocesses stored images. To use another codec or an
image service, implement `BeakTransformRunner` and pass it as
`defaults.build(transformRunner: ...)`.

## Declare the pipeline on the column

The pipeline lives on the schema class, next to the file rules that gate the
upload:

```dart title="examples/showcase/lib/resources/specimens/models/specimen.dart"
  /// A portrait, resized on upload (image column).
  @Image(
    storagePath: 'specimens',
    maxSizeInBytes: 5242880,
    allowedTypes: [BeakFileType.png, BeakFileType.jpeg, BeakFileType.webp],
    transforms: [
      BeakThumbnailTransform(
        size: BeakDimensions.square(320),
        name: 'thumbnail',
      ),
    ],
  )
  late final BeakImageRef? photo;
```

The upload endpoint validates the file, runs the pipeline, stores the primary
image and each variant through the configured storage driver, and returns a
`BeakStoredFile` that lists them.

## Run a pipeline yourself

```dart
import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:beak_image/beak_image.dart';

Future<BeakTransformedImage> thumbnails(Uint8List uploadedBytes) {
  const runner = ImageTransformRunner();
  return runner.run(uploadedBytes, const [
    BeakImageTransform.resize(widthInPixels: 1200),
    BeakImageTransform.webp(),
    BeakImageTransform.thumbnail(
      size: BeakDimensions(widthInPixels: 200, heightInPixels: 200),
      name: 'thumb',
    ),
  ]);
}
```

For a 1600 x 900 PNG, the result is `image/webp` at 1200 x 675, and
`result.variants['thumb']` is an `image/webp` 200 x 200 crop. Steps run in
declaration order, and a thumbnail is encoded in the format the pipeline has
chosen at that point, so put the format step before it.

## Rules the runner follows

- **Sources.** PNG, JPEG, WebP and GIF. Anything else, or bytes that do not
  decode, throws a `BeakValidationException`.
- **Header first.** `inspect` reads the declared width and height from the
  header without decoding a pixel, which is how the upload endpoint checks
  `maxDimensions` and `aspectRatio` before any memory is spent. `run` decodes
  the image once.
- **A pixel ceiling.** `run` refuses an image whose header declares more than
  `maxPixelCount` pixels (`ImageTransformRunner.defaultMaxPixelCount`, 50
  million, about 200 MB decoded) with a `BeakValidationException`, so a file of
  a few dozen bytes cannot ask for gigabytes.
- **Resize.** With one dimension the image scales and keeps its aspect ratio.
  With both, `BeakImageFit` decides: `contain` (the default) fits inside,
  `cover` fills and crops from the centre, `fill` stretches.
- **Thumbnails** are cover-cropped to their exact size. Two thumbnails with the
  same name throw a `BeakConfigurationException`; the default name is
  `thumbnail`.
- **Format.** `BeakImageFormat` is `jpg`, `png` or `webp`. Without a format step
  the image keeps its source format, and a JPEG gets quality
  `ImageTransformRunner.defaultQualityPercent` (80).
- **Empty pipeline.** The bytes and MIME type pass through untouched, but the
  source is still decoded, so a file that is not an image still throws.

## Main types

| Type | What it is |
| --- | --- |
| `ImageTransformRunner` | The `const` runner, and the only type this package exports. It is stateless, so one instance serves every upload. `maxPixelCount` sets its ceiling. |
| `beakImageVersion` | The package version string. |

The collaborators come from `beak_core`: `BeakTransformRunner` (the interface the
runner implements), `BeakImageTransform` (`resize`, `format`, `webp` and
`thumbnail` steps), `BeakTransformedImage` (`bytes`, `mimeType`, `dimensions`,
`variants`), `BeakDimensions`, `BeakImageFormat` and `BeakImageFit`.

## Limits

- **WebP is lossless.** The runner encodes WebP with `package:image`'s lossless
  encoder, so `quality` on a WebP step changes nothing (a pipeline with
  `webp(quality: 10)` and one with `webp(quality: 90)` produce the same bytes).
  Choose `jpg` when you want to trade fidelity for size.
- **The whole image is decoded.** Memory grows with the decoded size, not the
  file size, up to `maxPixelCount`. Bound uploads with `maxSizeInBytes` and
  `maxDimensions` on the column. The ceiling counts the pixels of one frame, so
  an animated GIF with many frames costs more than it says.

## Continue reading

- [Files and storage columns](https://simonerich.github.io/beak/models/files-and-storage-columns/): file rules, dimensions and transforms on a column.
- [Uploads and storage wiring](https://simonerich.github.io/beak/backend/uploads-and-storage-wiring/): where the runner sits in the upload path.
- [Storage internals](https://simonerich.github.io/beak/architecture/storage-internals/): the pipeline from request to stored variants.

## Status

Pre-1.0 and versioned in lockstep with the other `beak_*` packages (0.9.0). Not on pub.dev yet: depend on it from git with `ref: v0.9.0` once that tag exists, or from a checkout with `path:`. What changed: the [root changelog](https://github.com/SimonErich/beak/blob/main/CHANGELOG.md). Contributing: [CONTRIBUTING.md](https://github.com/SimonErich/beak/blob/main/CONTRIBUTING.md).

## License

Apache-2.0 © Marqably GmbH. See [LICENSE](https://github.com/SimonErich/beak/blob/main/LICENSE).
