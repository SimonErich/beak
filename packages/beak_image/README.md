# beak_image

The image transform runner for Beak: executes `BeakImageTransform` pipelines
(resize, re-encode, thumbnails) on `package:image`.

Part of [**Beak**](https://github.com/marqably/beak), a low-code,
configuration-driven admin-panel framework for Dart/Flutter. See the
[architecture guide](../../docs/architecture.md) for how the packages fit
together.

## What it is

Pure Dart. `beak_core` defines the image column, its `BeakImageTransform`
pipeline steps and the `BeakTransformRunner` interface, but ships no pixel
codec of its own. `beak_image` is the concrete runner: it decodes an uploaded
image with `package:image`, applies each transform in declaration order, and
returns the re-encoded primary image plus any named thumbnail variants. Wiring
this package into the upload endpoint is what gives an app real image
processing. The single entry point is `ImageTransformRunner`.

## Usage

```dart
import 'package:beak_core/beak_core.dart';
import 'package:beak_image/beak_image.dart';

const runner = ImageTransformRunner();

final result = await runner.run(uploadedBytes, const [
  BeakImageTransform.resize(widthInPixels: 1200),
  BeakImageTransform.webp(quality: 82),
  BeakImageTransform.thumbnail(
    size: BeakDimensions(widthInPixels: 200, heightInPixels: 200),
    name: 'thumb',
  ),
]);

print(result.mimeType); // image/webp
final thumbBytes = result.variants['thumb']!.bytes; // 200x200 cover crop
```

Sources must be a supported raster format (PNG, JPEG, WebP, GIF); anything
else throws a `BeakValidationException`. Thumbnails are cover-cropped to their
exact size and encoded with the format state at their point in the pipeline.
An empty pipeline passes the source bytes through untouched.

## Key types

- `ImageTransformRunner` — the `const`-constructible runner; the only type
  this package exports. Register one instance and reuse it per upload.
- `beakImageVersion` — the package version string.

Collaborators come from `beak_core`: `BeakTransformRunner` (implemented
interface), `BeakImageTransform` (the resize/format/thumbnail pipeline steps),
`BeakTransformedImage` (the `bytes`/`mimeType`/`dimensions`/`variants` result),
`BeakDimensions`, `BeakImageFormat` and `BeakImageFit`.

## Status

Pre-1.0, part of the Beak monorepo. Consumed by the
[reference admin](../../apps/reference_admin). Contributions welcome — see
[CONTRIBUTING](../../CONTRIBUTING.md) at the repo root.

## License

Apache-2.0 © Marqably GmbH. See [LICENSE](LICENSE).
