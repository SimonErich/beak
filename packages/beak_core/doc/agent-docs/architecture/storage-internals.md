# Storage internals

> See how a storage config resolves to a driver and how the validator and transform pipeline run.

After this page you can trace an uploaded file from a `BeakStorageConfig` to a stored object with a public URL, explain why the S3 and FTP drivers are unit-testable without a server, and describe the validate-transform-store pipeline that runs on every upload.

Beak stores files through a pluggable driver system. `beak_core` owns the abstraction (the config, the driver interface, the registry, the key rules, the validator, and the transform spec) and ships two drivers, `memory` and `local`. Driver packages add the rest: `beak_storage_s3`, `beak_storage_ftp`, and the pixel codec in `beak_image`. Nothing about S3 or FTP is hard-wired into core; they plug in at app init.

The abstraction lives in `packages/beak_core/lib/src/storage/`; the drivers live in `packages/beak_storage_s3`, `packages/beak_storage_ftp`, and `packages/beak_image`.

## Config resolves to a driver

Storage selection is pure data. `BeakStorageConfig` is a sealed family (`memory`, `local`, `s3`, `ftp`), each carrying its driver's settings and a `driverId`. Configs that hold secrets redact them in `toString`.

```dart title="packages/beak_core/lib/src/storage/beak_storage_config.dart"
@immutable
sealed class BeakStorageConfig {
  const BeakStorageConfig();

  /// Identifier of the driver this config is consumed by
  /// (`'memory'`, `'local'`, `'s3'`, `'ftp'`).
  String get driverId;
}
```

A `BeakStorageRegistry` maps each `driverId` to a factory. Only the web-safe `memory` driver is pre-registered; everything else is added at app init, and `resolve` builds the driver a config selects:

```dart title="packages/beak_core/lib/src/storage/beak_storage_registry.dart"
BeakStorageRegistry() {
  register('memory', BeakMemoryStorageDriver.fromConfig);
}

// ...

BeakStorageDriver resolve(BeakStorageConfig config) {
  final BeakStorageDriverFactory? factory =
      _factoriesByDriverId[config.driverId];
  if (factory == null) {
    throw BeakConfigurationException(
      'No storage driver is registered for "${config.driverId}". '
      'Registered drivers: ${driverIds.join(', ')}.',
    );
  }
  return factory(config);
}
```

The backend does the wiring once at startup. `createDefaultStorageRegistry` adds `local` (it needs `dart:io`) on top of core's `memory`, and `resolveStorage` turns the configured config into a driver:

```dart title="packages/beak_backend/lib/src/server/storage_wiring.dart"
BeakStorageRegistry createDefaultStorageRegistry() {
  final registry = BeakStorageRegistry();
  registry.register('local', BeakLocalDiskStorageDriver.fromConfig);
  return registry;
}
```

Driver packages are deliberately not wired in here. Depending on `beak_storage_s3` from `beak_backend` would put `minio` in the dependency graph of every Beak backend, uploads or not. Your app adds the driver it uses at init instead, with one line: `registerS3Storage(registry)`. The config stays plain data from `beak_core`, so only that one line names the driver package.

## The driver interface

Every driver satisfies one interface: put a file, read it, delete it, mint a URL, check existence. Keys are relative, `/`-separated paths.

```dart title="packages/beak_core/lib/src/storage/beak_storage_driver.dart"
abstract interface class BeakStorageDriver {
  String get id;

  Future<BeakStoredFile> put(BeakUpload upload, {required String path});

  Future<Uint8List> get(String key);

  Future<void> delete(String key);

  Future<Uri> url(String key, {Duration? expiresIn});

  Future<bool> exists(String key);
}
```

`url` builds an address without probing storage, and `exists` reports a boolean rather than throwing, so callers can ask cheaply. The other methods throw `BeakStorageException` for malformed keys or missing files.

## Drivers sit behind a thin transport seam

The S3 and FTP drivers do not talk to the network directly. Each one delegates raw I/O to a narrow seam interface, so the driver's own logic (key building, URL shaping, error mapping) is unit-testable against a fake with no server in sight.

For S3 the seam is `S3ObjectClient`, five raw object operations:

```dart title="packages/beak_storage_s3/lib/src/s3_object_client.dart"
abstract interface class S3ObjectClient {
  Future<void> putObject({
    required String bucket,
    required String key,
    required Uint8List bytes,
    required String contentType,
  });
  Future<Uint8List?> getObject({required String bucket, required String key});
  Future<void> removeObject({required String bucket, required String key});
  Future<bool> objectExists({required String bucket, required String key});
  Future<Uri> presignedGetUrl({
    required String bucket,
    required String key,
    required Duration expiresIn,
  });
}
```

The driver builds itself from config and takes the production client by default, but accepts an injected one for tests:

```dart title="packages/beak_storage_s3/lib/src/s3_storage_driver.dart"
S3StorageDriver(BeakS3Config config, {S3ObjectClient? client})
  : _config = config,
    _client = client ?? MinioS3ObjectClient(config);

factory S3StorageDriver.fromConfig(BeakStorageConfig config) =>
    switch (config) {
      BeakS3Config() => S3StorageDriver(config),
      _ => throw BeakConfigurationException(
        'S3StorageDriver requires a BeakS3Config, '
        'got ${config.runtimeType}.',
      ),
    };
```

Every operation runs inside a `_guard` that rethrows Beak's own exceptions untouched and wraps any client or transport error in a `BeakStorageException`, so no raw S3 or socket error ever crosses the driver boundary:

```dart title="packages/beak_storage_s3/lib/src/s3_storage_driver.dart"
Future<T> _guard<T>(
  String operationName,
  String key,
  Future<T> Function() operation,
) async {
  try {
    return await operation();
  } on BeakException {
    rethrow;
  } on Object catch (error) {
    throw BeakStorageException('S3 $operationName failed for "$key": $error');
  }
}
```

The FTP driver mirrors the pattern: an `FtpTransport` seam (a minimal RFC 959 socket client and an in-process test server), an `FtpProtocolException` carrying the reply code, and a `_guard` that turns a `550` reply into a not-found `BeakStorageException`. FTP has no expiring links, so its `url` ignores `expiresIn` and serves from the configured public base. Writing a driver is the same exercise both times: implement five methods, hide the wire behind a seam, map every failure to `BeakStorageException`.

## Keys are validated, and minted server-side

Storage keys are the security surface, so `BeakStorageKeys` is strict about them. `validate` rejects empty keys, backslashes, absolute paths, and any `.` or `..` segment, which closes off path traversal:

```dart title="packages/beak_core/lib/src/storage/beak_storage_key.dart"
static void validate(String key) {
  if (key.isEmpty) {
    throw const BeakStorageException('Storage keys must not be empty.');
  }
  if (key.contains(r'\')) {
    throw BeakStorageException(
      'Storage key "$key" must use "/" separators, not backslashes.',
    );
  }
  if (key.startsWith('/')) {
    throw BeakStorageException(
      'Storage key "$key" must be relative, not absolute.',
    );
  }
  for (final String segment in key.split('/')) {
    if (segment.isEmpty || segment == '.' || segment == '..') {
      throw BeakStorageException(
        'Storage key "$key" contains the invalid segment "$segment".',
      );
    }
  }
}
```

`join` builds a validated `path/filename` key, and `appendToBaseUrl` is the one way every driver turns a base URL plus a key into a public URL. Equally important, the upload service never trusts a client filename for a key: it mints a fresh uuid-based name and derives the extension from the validated MIME type. A client cannot choose where its bytes land.

## The upload pipeline: validate, transform, store

`UploadService` is the logic layer behind the upload endpoints. It resolves the target column, enforces the column's file rules, runs the image transform pipeline, and stores every result through the configured driver. Handlers stay parse-thin; the service throws typed exceptions only.

Two shared pieces do the heavy lifting. `BeakUploadValidator` is the same validator the client runs before it uploads, so the browser and the server reject a too-large or wrong-type file with byte-identical messages. It is pure logic: the caller decodes image dimensions and passes them in, keeping the validator free of any image codec.

```dart title="packages/beak_core/lib/src/storage/beak_upload_validator.dart"
BeakResult<BeakUpload> validate(
  BeakUpload upload, {
  int? maxSizeInBytes,
  List<BeakFileType> allowedTypes = const [],
  BeakDimensions? maxDimensions,
  double? aspectRatio,
  BeakDimensions? actualDimensions,
}) {
```

Violations aggregate into a `BeakValidationException` keyed by aspect (`size`, `type`, `dimensions`, `aspectRatio`), so a form can surface each problem next to its cause.

For an image column, the service decodes to get real pixel dimensions, validates against them, runs the column's transform pipeline when it has one, and stores the primary image plus every thumbnail variant:

```dart title="packages/beak_backend/lib/src/uploads/upload_service.dart"
final decoded = await transformRunner.run(upload.bytes, const []);
_validator
    .validate(
      upload,
      maxSizeInBytes: column.maxSizeInBytes,
      allowedTypes: column.allowedTypes,
      maxDimensions: column.maxDimensions,
      aspectRatio: column.aspectRatio,
      actualDimensions: decoded.dimensions,
    )
    .valueOrThrow;
final transformed = column.transforms.isEmpty
    ? decoded
    : await transformRunner.run(upload.bytes, column.transforms);
```

An empty pipeline is a decoding pass-through: it yields the source bytes plus decoded dimensions, or a validation failure for bytes that are not a decodable raster image.

## Transform spec and runner are split on purpose

The transform pipeline is a sealed, serializable spec, and its execution is a separate interface. `BeakImageTransform` describes steps (resize, re-encode, thumbnail) with named factories, and the whole pipeline can travel over the wire:

```dart title="packages/beak_core/lib/src/storage/transforms/beak_image_transform.dart"
const factory BeakImageTransform.resize({
  int? widthInPixels,
  int? heightInPixels,
  BeakImageFit fit,
}) = BeakResizeTransform;

const factory BeakImageTransform.format({
  required BeakImageFormat format,
  int quality,
}) = BeakFormatTransform;

const factory BeakImageTransform.webp({int quality}) =
    BeakFormatTransform.webp;

const factory BeakImageTransform.thumbnail({
  required BeakDimensions size,
  String name,
}) = BeakThumbnailTransform;
```

But `beak_core` deliberately ships no pixel codec. It defines only the runner interface:

```dart title="packages/beak_core/lib/src/storage/transforms/beak_transform_runner.dart"
abstract interface class BeakTransformRunner {
  Future<BeakTransformedImage> run(
    Uint8List source,
    List<BeakImageTransform> pipeline,
  );
}
```

The concrete runner lives in `beak_image`, where `ImageTransformRunner` executes pipelines with `package:image`. It switches over the sealed steps in declaration order, cover-crops thumbnails to their exact size, and rejects a duplicate variant name. Keeping the codec in a leaf package means `beak_core` stays pure Dart with no heavy image dependency, and a different backend could supply a different runner without changing the spec.

## Why this shape

- **Config is data, drivers are plugins.** A sealed config plus a registry means an app selects storage without importing a driver package, and a new driver registers a factory instead of editing core.
- **Seams make drivers testable.** Because each driver talks to a narrow transport interface, its logic is proven against a fake, and its `_guard` guarantees only `BeakStorageException` escapes.
- **One validator, two runtimes.** The client and the server share `BeakUploadValidator`, so what the browser accepts is exactly what the server accepts.
- **Keys are never client-chosen.** Validation rejects traversal, and the service mints keys, so uploads cannot escape their storage path.

## Continue reading

- [Files and storage columns](../models/files-and-storage-columns.md) declaring image and file columns with rules and transforms.
- [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md) configuring storage on the server.
- [Custom storage drivers](../extending/custom-storage-drivers.md) writing a driver behind its own transport seam.
- [Security](../shipping/security.md) the upload and key-validation surface in context.
