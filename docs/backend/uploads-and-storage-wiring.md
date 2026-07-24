---
title: Uploads and storage wiring
description: How a file column becomes an upload endpoint, the validate-transform-store pipeline each upload runs, and how you pick a storage driver with one environment variable.
---

# Uploads and storage wiring

By the end of this page you can turn on file uploads for a model's image or file
columns, understand the validate-transform-store pipeline each upload runs, and
point storage at memory, local disk, S3, or FTP by setting one environment
variable. No upload endpoint is hand-written: declare a file column, configure a
driver, and the route appears.

Uploads build on the [file and storage columns](../models/files-and-storage-columns.md)
you already defined. The reference store's product has an image column, and that
is what wires into an endpoint here.

```dart title="apps/reference_admin_models/lib/src/product.dart"
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

## The pipeline: validate, transform, store

`UploadService` is the logic layer behind the upload routes. It resolves the
target column, enforces that column's file rules, runs the image transform
pipeline, and stores every result through the configured driver. Handlers stay
thin; the service throws only typed exceptions.

```mermaid
flowchart LR
  U[Multipart upload] --> C{File or image column}
  C -->|file| V1[Validate size and type]
  C -->|image| D[Decode and read dimensions]
  D --> V2[Validate size, type, dimensions, aspect]
  V2 --> T[Run transforms]
  V1 --> S[Driver.put]
  T --> S
  S --> R[BeakStoredFile with variants]
```

The entry point is `handle`, which pattern-matches on the resolved column. A file
column takes the plain path; an image column takes the transform path; anything
else is a validation error, because you cannot upload to a string column.

```dart title="packages/beak_backend/lib/src/uploads/upload_service.dart"
Future<BeakStoredFile> handle({
  required String table,
  required String columnKey,
  required BeakUpload upload,
}) async {
  switch (_columnOf(table, columnKey)) {
    case final BeakFileColumn fileColumn:
      return _storeFile(fileColumn, upload);
    case final BeakImageColumn imageColumn:
      return _storeImage(imageColumn, upload);
    case final BeakColumn other:
      throw BeakValidationException(
        'Column "$columnKey" of "$table" is a ${other.runtimeType}; '
        'uploads need a file or image column.',
      );
  }
}
```

For an image, the service first decodes the bytes (an empty transform pipeline is
a decode pass-through that also yields the real dimensions), validates size, type,
dimensions, and aspect ratio against the column, then runs the column's
transforms. The reference product's transforms produce a WebP main file plus a
160x160 thumbnail, and both come back as a `BeakStoredFile` with its `variants`
map populated. Client filenames are never trusted for storage keys; the service
mints its own.

## The upload routes

Registering a model adds two routes under its mount point, so the full paths are
`POST` and `DELETE /api/{table}/{columnKey}/upload`.

```dart title="packages/beak_backend/lib/src/uploads/upload_router.dart"
void registerUploadRoutes(
  Router router, {
  required BeakModel model,
  required UploadService service,
  BeakPolicy policy = const BeakAllowAllPolicy(),
}) {
  final handlers = BeakUploadHandlers(
    model: model,
    service: service,
    policy: policy,
  );
  router
    ..post('/<columnKey>/upload', handlers.upload)
    ..delete('/<columnKey>/upload', handlers.remove);
}
```

The upload handler checks `canCreate` (uploading a file is creating one), then
reads the multipart body into a typed `BeakUpload` and delegates to the service.

```dart title="packages/beak_backend/lib/src/uploads/upload_handler.dart"
Future<Response> upload(Request request, String columnKey) async {
  enforcePolicyDecision(
    allowed: policy.canCreate(beakPrincipal(request), model.table),
    principal: beakPrincipal(request),
    action: 'upload to',
    table: model.table,
  );
  final upload = await _readUpload(request, _sizeLimitFor(columnKey));
  final stored = await service.handle(
    table: model.table,
    columnKey: columnKey,
    upload: upload,
  );
  return Response(201, body: jsonEncode(stored.toJson()));
}
```

The size limit is enforced *while reading*, not after. `_readBounded` fails the
moment the buffered part grows past the column's `maxSizeInBytes`, so an oversize
upload never buffers fully into memory.

```dart title="packages/beak_backend/lib/src/uploads/upload_handler.dart"
Future<Uint8List> _readBounded(
  Stream<List<int>> source,
  int? maxSizeInBytes,
) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in source) {
    builder.add(chunk);
    if (maxSizeInBytes != null && builder.length > maxSizeInBytes) {
      throw BeakValidationException(
        'Upload rejected.',
        fieldErrors: {
          'size': ['The file exceeds the limit of $maxSizeInBytes bytes.'],
        },
      );
    }
  }
  return builder.takeBytes();
}
```

Deletion is gated by the dedicated `canDeleteUpload` hook, because a stored file
is named by its storage key, not by a record id. The service also guards that the
key belongs to the column's storage path before it touches the driver, so a
request cannot delete an arbitrary object by guessing keys.

```dart title="packages/beak_backend/lib/src/uploads/upload_service.dart"
if (!key.startsWith('$storagePath/')) {
  throw BeakValidationException(
    'Key "$key" does not belong to column "$columnKey" '
    '(expected the "$storagePath/" prefix).',
  );
}
```

Uploading a product image against the reference store on port 8080:

```bash
curl -sX POST http://localhost:8080/api/products/image/upload \
  -F 'file=@house-roast.png;type=image/png'
# 201 {"key":"products/...webp","url":"...","variants":{"thumbnail":{...}}}
```

| Method and path | Body | Success | Gated by |
| --- | --- | --- | --- |
| `POST /api/{table}/{columnKey}/upload` | multipart, field `file` | `201` `BeakStoredFile` | `canCreate` |
| `DELETE /api/{table}/{columnKey}/upload` | `{"key": ...}` | `204` | `canDeleteUpload` |

See [Auth and policies](auth-and-policies.md) for the two gates, and
[Files and storage columns](../models/files-and-storage-columns.md) for the file
rules the service enforces.

## Choosing a driver

A `BeakStorageDriver` is where bytes actually land. Beak keeps drivers behind a
`BeakStorageRegistry`. `createDefaultStorageRegistry` builds one with every
built-in driver: `memory` and `local` come from `beak_core`, and `s3` and `ftp`
are plugged in from their own packages, so nothing is hard-wired into core.

```dart title="packages/beak_backend/lib/src/server/storage_wiring.dart"
BeakStorageRegistry createDefaultStorageRegistry() {
  final registry = BeakStorageRegistry();
  registerS3Storage(registry);
  registerFtpStorage(registry);
  return registry;
}
```

`resolveStorage` takes a `BeakStorageConfig` and returns the driver it selects.
The server resolves once at startup and injects the driver into the upload
service.

```dart title="packages/beak_backend/lib/src/server/storage_wiring.dart"
BeakStorageDriver resolveStorage(
  BeakStorageConfig config, {
  BeakStorageRegistry? registry,
}) => (registry ?? createDefaultStorageRegistry()).resolve(config);
```

To add a driver of your own, register it on the registry before you resolve, and
pass that registry to `resolveStorage`. See
[Custom storage drivers](../extending/custom-storage-drivers.md) for the driver
interface.

### One environment variable picks the driver

The apps read `BEAK_STORAGE_DRIVER` and turn it into a `BeakStorageConfig?`. The
reference server does this in `referenceStorageConfig`: `s3` builds a
`BeakS3Config` from the `BEAK_S3_*` variables, `memory` selects the in-memory
driver (tests), and an absent value disables uploads entirely.

```dart title="apps/reference_admin_server/lib/src/server_builder.dart"
BeakStorageConfig? referenceStorageConfig(Map<String, String> environment) {
  switch (environment['BEAK_STORAGE_DRIVER']) {
    case 's3':
      String require(String key) {
        final String? value = environment[key];
        if (value == null || value.isEmpty) {
          throw BeakConfigurationException(
            '$key is required when BEAK_STORAGE_DRIVER=s3.',
          );
        }
        return value;
      }

      return BeakS3Config(
        endpoint: Uri.parse(require('BEAK_S3_ENDPOINT')),
        bucket: require('BEAK_S3_BUCKET'),
        accessKey: require('BEAK_S3_ACCESS_KEY'),
        secretKey: require('BEAK_S3_SECRET_KEY'),
        region: require('BEAK_S3_REGION'),
        usePathStyle: environment['BEAK_S3_USE_PATH_STYLE'] == 'true',
      );
    case 'memory':
      return const BeakMemoryStorageConfig();
    case null || '':
      return null;
    case final String other:
      throw BeakConfigurationException(
        'Unsupported BEAK_STORAGE_DRIVER "$other" (use "s3" or "memory").',
      );
  }
}
```

The `require` closure is why an incomplete config fails loudly at startup instead
of surfacing as a mysterious 500 on the first upload. Selecting `s3` with a
missing `BEAK_S3_BUCKET` throws a `BeakConfigurationException` before the server
binds.

| Variable | Meaning |
| --- | --- |
| `BEAK_STORAGE_DRIVER` | `s3`, `memory`, or absent (uploads off) |
| `BEAK_S3_ENDPOINT` | the object-store endpoint URL |
| `BEAK_S3_BUCKET` | the bucket uploads land in |
| `BEAK_S3_ACCESS_KEY` / `BEAK_S3_SECRET_KEY` | credentials |
| `BEAK_S3_REGION` | the region string |
| `BEAK_S3_USE_PATH_STYLE` | `true` for MinIO and path-style hosts |

The repo's docker-compose stack ships a MinIO container, and the committed
`.env.example` points at it with path-style on, so `melos run up` plus the sample
values gives you a working S3-compatible target locally. See
[Environment and config](../deployment/environment-and-config.md) for the full
variable list.

## Turning uploads on

The wiring meets at `BeakServer`. Pass a resolved `storage` driver and the server
builds the `UploadService` and registers the upload routes for every model with a
file column. Pass `null` (the default) and there are no upload endpoints at all.

```dart title="apps/reference_admin_server/bin/reference_admin_server.dart"
final storageConfig = referenceStorageConfig(environment);
final server = buildReferenceServer(
  config: config,
  adapter: Worm.adapter(),
  storage: storageConfig == null ? null : resolveStorage(storageConfig),
);
```

That is the whole loop: an environment variable becomes a config, the config
resolves to a driver, the driver goes into the server, and every image column in
the registry gains a validated, transforming upload endpoint.

## Continue reading

- [Files and storage columns](../models/files-and-storage-columns.md) the column
  side: file rules, dimensions, and transforms.
- [Running the server](running-the-server.md) the `BeakServer` constructor that
  ties the driver in.
- [Custom storage drivers](../extending/custom-storage-drivers.md) writing a
  driver for a backend Beak does not ship.
- [Environment and config](../deployment/environment-and-config.md) every
  `BEAK_*` variable, including the storage set.
- [Auth and policies](auth-and-policies.md) the `canCreate` and
  `canDeleteUpload` gates on the upload routes.
