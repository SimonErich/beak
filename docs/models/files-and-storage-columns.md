---
title: Files and storage columns
description: Declare image and file columns with size, type, dimension, and transform rules that Beak enforces on upload and mirrors in the form.
---

# Files and storage columns

After this page you can add an image or file field to a model, bound it with
size and type limits, generate thumbnails and format renditions on upload, and
know where the bytes land and how they are validated.

Two columns carry uploads: `BeakImageColumn` for pictures and `BeakFileColumn`
for everything else. Both store the file's key/URL as their value, and both let
you write the upload rules right on the column, the same place every other rule
lives. You describe the file's constraints once. Beak runs the picker, the
validation, and the transforms.

## The shared upload column

Both columns extend one sealed intermediate, `BeakUploadColumn`, which holds the
three settings every upload has: where it lands and what gates it.

```dart title="packages/beak_core/lib/src/columns/beak_column.dart"
sealed class BeakUploadColumn extends BeakColumn {
  /// Creates an upload-backed column storing files under [storagePath].
  const BeakUploadColumn({
    required super.key,
    required super.label,
    required this.storagePath,
    super.visibleOn,
    super.sortable,
    super.searchable,
    super.filterable,
    super.rules,
    this.maxSizeInBytes,
    this.allowedTypes = const [],
  });

  /// Storage subfolder uploads of this column land in.
  final String storagePath;

  /// Highest accepted upload size in bytes, if bounded.
  final int? maxSizeInBytes;

  /// Accepted upload types; empty means unrestricted.
  final List<BeakFileType> allowedTypes;

  /// Values are stored file keys/URLs.
  @override
  Type get valueType => String;
}
```

| Setting | Type | Meaning |
| --- | --- | --- |
| `storagePath` | `String` | subfolder the file is written under, e.g. `products` or `users/avatars` |
| `maxSizeInBytes` | `int?` | largest accepted upload; `null` means unbounded |
| `allowedTypes` | `List<BeakFileType>` | accepted types; empty means anything goes |

`allowedTypes` is typed: `BeakFileType` is an enum pairing a canonical MIME type
with its extensions, so you say `BeakFileType.png`, never `'image/png'`.

## Image columns

`BeakImageColumn` renders a thumbnail in table cells, an image picker in forms,
and the full image in detail views. On top of the shared upload settings it adds
dimension limits, an optional thumbnail, and a transform pipeline.

```dart title="packages/beak_core/lib/src/columns/beak_image_column.dart"
final class BeakImageColumn extends BeakUploadColumn {
  const BeakImageColumn({
    required super.key,
    required super.label,
    required super.storagePath,
    super.visibleOn,
    super.sortable,
    super.searchable,
    super.filterable,
    super.rules,
    super.maxSizeInBytes,
    super.allowedTypes = BeakFileType.images,
    this.maxDimensions,
    this.aspectRatio,
    this.thumbnail,
    this.transforms = const [],
  });
```

Note the default: an image column's `allowedTypes` defaults to
`BeakFileType.images` (JPEG, PNG, WebP, GIF). SVG is deliberately left out
because it can carry scripts and cannot be transformed like a raster; add it
explicitly if you need it.

| Field | Type | Meaning |
| --- | --- | --- |
| `maxDimensions` | `BeakDimensions?` | largest accepted source size in pixels |
| `aspectRatio` | `double?` | required width/height ratio, if enforced |
| `thumbnail` | `BeakDimensions?` | size of an auto-generated thumbnail rendition |
| `transforms` | `List<BeakImageTransform>` | pipeline run in order on upload |

The products model's photo shows the full set: a 5 MB cap, raster formats only,
a thumbnail, and a transform pipeline.

```dart
/// Product photo: max 5 MB, raster formats only, thumbnail + webp
/// renditions generated on upload.
static const image = BeakImageColumn(
  key: 'image',
  label: 'Image',
  storagePath: 'products',
  maxSizeInBytes: 5 * 1024 * 1024,
  allowedTypes: [BeakFileType.jpeg, BeakFileType.png, BeakFileType.webp],
  thumbnail: BeakDimensions(widthInPixels: 160, heightInPixels: 160),
  transforms: [
    BeakThumbnailTransform(
      size: BeakDimensions(widthInPixels: 160, heightInPixels: 160),
    ),
    BeakFormatTransform.webp(),
  ],
);
```

The **superdashboard** showcase uses the simpler form for avatars: rules
and a thumbnail, no transform pipeline.

```dart title="examples/superdashboard/lib/models/people/user.dart"
static const avatar = BeakImageColumn(
  key: 'avatar',
  label: 'Avatar',
  storagePath: 'users/avatars',
  maxSizeInBytes: 5 * 1024 * 1024,
  allowedTypes: [BeakFileType.jpeg, BeakFileType.png, BeakFileType.webp],
  thumbnail: BeakDimensions(widthInPixels: 96, heightInPixels: 96),
);
```

## File columns

`BeakFileColumn` is the generic attachment: a PDF, a CSV, an archive. It adds
nothing beyond the shared upload settings and renders through the custom
download/preview widget. Reach for it whenever the file is not an image.

```dart title="packages/beak_core/lib/src/columns/beak_file_column.dart"
final class BeakFileColumn extends BeakUploadColumn {
  /// Creates a file column storing uploads under [storagePath].
  const BeakFileColumn({
    required super.key,
    required super.label,
    required super.storagePath,
    super.visibleOn,
    super.sortable,
    super.searchable,
    super.filterable,
    super.rules,
    super.maxSizeInBytes,
    super.allowedTypes,
  });
```

```dart title="packages/beak_core/lib/src/columns/beak_file_column.dart"
static const attachment = BeakFileColumn(
  key: 'attachment',
  label: 'Attachment',
  storagePath: 'articles/files',
  maxSizeInBytes: 10 * 1024 * 1024,
  allowedTypes: [BeakFileType.pdf],
);
```

## The transform pipeline

`transforms` is a list of steps run in declaration order on upload. The base is
sealed and JSON-serializable, so the pipeline travels over the wire and the
server's transform runner switches over it exhaustively. Compose steps with the
named factories.

```dart title="packages/beak_core/lib/src/storage/transforms/beak_image_transform.dart"
const pipeline = <BeakImageTransform>[
  BeakImageTransform.resize(widthInPixels: 1280, fit: BeakImageFit.contain),
  BeakImageTransform.webp(quality: 80),
  BeakImageTransform.thumbnail(size: BeakDimensions.square(160)),
];
```

There are three step kinds:

| Factory | Produces |
| --- | --- |
| `BeakImageTransform.resize(...)` | a resized image; keeps aspect ratio when only one dimension is given |
| `BeakImageTransform.format(...)` / `.webp(...)` | the image re-encoded to another format at a quality |
| `BeakImageTransform.thumbnail(...)` | an extra named rendition at a fixed size |

A `thumbnail` step (and the column's `thumbnail` shortcut) produces an
additional stored rendition. Those renditions come back on the upload result as
named `variants`, so the panel can show the small version in a table and the
full one in detail.

```dart title="packages/beak_core/lib/src/storage/beak_stored_file.dart"
/// Additional stored renditions (e.g. `thumbnail`), keyed by variant name.
final Map<String, BeakStoredFileVariant> variants;
```

## Upload validation

The size, type, dimension, and aspect-ratio rules are not decoration: they run
server-side on the upload endpoint through `BeakUploadValidator`, which is pure
logic with no I/O. It returns the upload unchanged when every rule passes, or a
`BeakValidationException` whose `fieldErrors` are keyed by the aspect that
failed: `size`, `type`, `dimensions`, or `aspectRatio`.

```dart title="packages/beak_core/lib/src/storage/beak_upload_validator.dart"
const validator = BeakUploadValidator();
final result = validator.validate(
  upload,
  maxSizeInBytes: 5 * 1024 * 1024,
  allowedTypes: BeakFileType.images,
  maxDimensions: const BeakDimensions.square(4096),
  actualDimensions: decodedSize, // pass null for non-images
);
```

The same limits are mirrored client-side by the standalone
[`BeakAllowedFileTypes` and `BeakMaxFileSize` rules](validation-rules.md#file-rules),
so the picker rejects an over-size or wrong-type file before it uploads. As
always, the server has the final word.

## Where the bytes land

`storagePath` is a subfolder, not a full location. The actual destination
(memory, local disk, S3, or FTP) is chosen once at app init by a
`BeakStorageConfig` and resolved to a driver. The column does not care which
driver is active; it only names the folder. Swapping local disk for S3 in
production is a config change, not a model change.

```dart title="packages/beak_core/lib/src/storage/beak_storage_config.dart"
final BeakStorageConfig config = isProduction
    ? BeakS3Config(
        endpoint: Uri.parse('https://s3.eu-central-1.amazonaws.com'),
        bucket: 'uploads',
        accessKey: env.s3AccessKey,
        secretKey: env.s3SecretKey,
        region: 'eu-central-1',
      )
    : BeakLocalDiskStorageConfig(
        rootDir: 'storage/uploads',
        publicBaseUrl: Uri.parse('http://localhost:8080/uploads'),
      );
```

The [uploads and storage wiring](../backend/uploads-and-storage-wiring.md) page
covers how the upload endpoint, the validator, the transform runner, and the
driver fit together on the server.

## Continue reading

- [Column types](column-types.md) the other twelve column kinds.
- [Validation rules](validation-rules.md) the file rules mirrored on the client.
- [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md) the
  server side of an upload.
- [Custom storage drivers](../extending/custom-storage-drivers.md) writing a
  driver for a store Beak does not ship.
