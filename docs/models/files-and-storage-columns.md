---
title: Files and storage columns
description: Declare image and file fields with size, type, dimension and transform rules that Beak enforces on upload and mirrors in the form.
---

# Files and storage columns

After this page you can add an image or file field to a resource, bound it with
size and type limits, generate thumbnails and format renditions on upload, and
know where the bytes land and how they are validated.

Two annotations carry uploads: `@Image` for pictures and `@FileField` for
everything else. Both go on a field whose type says it stores a file reference,
and both take their rules right there, the same place every other rule lives. You
describe the file's constraints once. Beak runs the picker, the validation and
the transforms.

```dart title="examples/store/lib/models/product.dart"
/// The spec sheet customers download.
@FileField(
  storagePath: 'products/specs',
  maxSizeInBytes: 10 * 1024 * 1024,
  allowedTypes: [BeakFileType.pdf],
)
late final BeakFileRef? specSheet;
```

`BeakImageRef` and `BeakFileRef` are extension types over `String`: the field
holds the stored file's key, and the type is how the field says which annotation
belongs on it.

## The shared upload settings

Three settings are common to both annotations: where the file lands, and what
gates it.

| Setting | Type | Meaning |
| --- | --- | --- |
| `storagePath` | `String` | subfolder the file is written under, for example `products` or `users/avatars` |
| `maxSizeInBytes` | `int?` | largest accepted upload; `null` means unbounded |
| `allowedTypes` | `List<BeakFileType>` | accepted types |

`allowedTypes` is typed: `BeakFileType` is an enum pairing a canonical MIME type
with its extensions, so you write `BeakFileType.png`, never `'image/png'`.

Both annotations generate a column extending one sealed intermediate,
`BeakUploadColumn`, which is where those three live on the output side:

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
    super.indexed,
    super.unique,
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
}
```

## Image fields

`@Image` renders a thumbnail in table cells, an image picker in forms, and the
full image in detail views. On top of the shared settings it adds dimension
limits, an optional thumbnail, and a transform pipeline.

| Parameter | Type | Meaning |
| --- | --- | --- |
| `maxDimensions` | `BeakDimensions?` | largest accepted source size in pixels |
| `aspectRatio` | `double?` | required width/height ratio, if enforced |
| `thumbnail` | `BeakDimensions?` | size of an auto-generated thumbnail rendition |
| `transforms` | `List<BeakImageTransform>` | pipeline run in order on upload |

The store's product photo uses the full set: a 5 MB cap, raster formats only, a
thumbnail, and a two-step pipeline.

```dart title="examples/store/lib/models/product.dart"
@Image(
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
)
late final BeakImageRef? image;
```

Leave `allowedTypes` off and the generated column falls back to
`BeakFileType.images`: JPEG, PNG, WebP and GIF. SVG is deliberately excluded,
because it can carry scripts and cannot be transformed like a raster. Add it
explicitly if you need it.

The superdashboard showcase uses the simpler form for avatars, rules and a
thumbnail with no pipeline:

```dart title="examples/superdashboard/lib/models/people/user.dart"
@Image(
  storagePath: 'users/avatars',
  maxSizeInBytes: 5 * 1024 * 1024,
  allowedTypes: [BeakFileType.jpeg, BeakFileType.png, BeakFileType.webp],
  thumbnail: BeakDimensions(widthInPixels: 96, heightInPixels: 96),
)
late final BeakImageRef? avatar;
```

An `@Image` field takes `@Column` alongside it when it also needs a shared option
such as `visibleOn`. The two annotations sit on the same field and configure
different halves of the column.

The generated column is a `BeakImageColumn`:

```dart title="packages/beak_core/lib/src/columns/beak_image_column.dart"
const BeakImageColumn({
  required super.key,
  required super.label,
  required super.storagePath,
  super.visibleOn,
  super.sortable,
  super.searchable,
  super.filterable,
  super.indexed,
  super.unique,
  super.rules,
  super.maxSizeInBytes,
  super.allowedTypes = BeakFileType.images,
  this.maxDimensions,
  this.aspectRatio,
  this.thumbnail,
  this.transforms = const [],
});
```

## File fields

`@FileField` is the generic attachment: a PDF, a CSV, an archive. It adds nothing
beyond the shared settings and renders through a download/preview widget instead
of an image. Reach for it whenever the file is not a picture.

```dart title="examples/superdashboard/lib/models/files/managed_file.dart"
/// The stored file.
@FileField(storagePath: 'files/store')
late final BeakFileRef? file;
```

With no `allowedTypes` and no `maxSizeInBytes`, anything goes. That is fine for
an internal file manager and wrong for a public upload form, so bound the ones
strangers can reach.

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

A thumbnail step (and the annotation's `thumbnail` shortcut) produces an
additional stored rendition. Those renditions come back on the upload result as
named `variants`, so the panel can show the small version in a table and the full
one in detail.

```dart title="packages/beak_core/lib/src/storage/beak_stored_file.dart"
/// Additional stored renditions (e.g. `thumbnail`), keyed by variant name.
final Map<String, BeakStoredFileVariant> variants;
```

## Upload validation

The size, type, dimension and aspect-ratio rules are not decoration: they run
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

`storagePath` is a subfolder, not a destination. Which store it is a subfolder of
is decided at boot, by the environment, not by the resource:

```bash
BEAK_STORAGE_DRIVER=s3
BEAK_S3_ENDPOINT=http://localhost:9000
BEAK_S3_BUCKET=acme-uploads
BEAK_S3_ACCESS_KEY=...
BEAK_S3_SECRET_KEY=...
BEAK_S3_REGION=us-east-1
```

`BEAK_STORAGE_DRIVER` takes `s3`, `ftp`, `local` or `memory`, each reading its own
variables. Leave it unset and the server runs without upload endpoints, which is
the right default for an app that has no upload fields yet. A driver named
without the variables it needs fails at boot with the missing name in the
message, rather than at the first upload.

Under those variables sits a sealed `BeakStorageConfig` family, one variant per
driver. It is also what you build directly when you host the server yourself:

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

The S3 and FTP drivers are separate packages, so a project that stores nothing in
S3 does not build its client. Declare the ones you use in `lib/server.dart` and
`beak prepare` wires them into the host:

```dart title="examples/superdashboard/lib/server.dart"
BeakStorageRegistry beakStorageRegistry() {
  final registry = createDefaultStorageRegistry();
  registerS3Storage(registry);
  return registry;
}
```

Either way the field does not care which driver is active. It only names the
folder, so swapping local disk for S3 in production is an environment change,
not a schema change.

The [uploads and storage wiring](../backend/uploads-and-storage-wiring.md) page
covers how the upload endpoint, the validator, the transform runner and the
driver fit together on the server.

## Continue reading

- [Column types](column-types.md) the other eleven column kinds.
- [Validation rules](validation-rules.md) the file rules mirrored on the client.
- [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md) the
  server side of an upload.
- [Custom storage drivers](../extending/custom-storage-drivers.md) writing a
  driver for a store Beak does not ship.
