# Phase 05 — beak_core: storage abstraction + file rules + transforms

## Objective
Define the pluggable, credential-configurable file-storage abstraction and the
Filament-style file/image rules and transform pipeline — all in `beak_core`, with an
in-memory and a local-disk driver for tests/dev. Concrete cloud drivers come in Phase 06.

## Prerequisites
- Phase 04 `✅ DONE`.
- The pure value objects `BeakFileType`, `BeakDimensions`, `BeakImageTransform` were
  stubbed for the image column in Phase 02; finalize and build the driver layer here.

## Files created (in `packages/beak_core/lib/src/storage/`)
- `beak_storage_driver.dart` (interface)
- `beak_storage_config.dart` + `drivers/*_config.dart`
- `beak_upload.dart`, `beak_stored_file.dart`
- `file_rules/beak_file_type.dart`, `beak_dimensions.dart`
- `transforms/beak_image_transform.dart`, `transforms/beak_transform_runner.dart` (abstract)
- `drivers/beak_memory_storage_driver.dart`, `drivers/beak_local_disk_storage_driver.dart`
- `beak_upload_validator.dart`
- barrel updates

## Public API to implement (contract)

### The driver interface (implemented by S3/FTP/etc.)
```dart
abstract interface class BeakStorageDriver {
  String get id;                                   // 's3', 'ftp', 'memory', 'local'
  Future<BeakStoredFile> put(BeakUpload upload, {required String path});
  Future<Uint8List> get(String key);
  Future<void> delete(String key);
  Future<Uri> url(String key, {Duration? expiresIn});
  Future<bool> exists(String key);
}
```
```dart
final class BeakUpload {                            // typed, not a raw byte blob soup
  const BeakUpload({required this.filename, required this.mimeType, required this.bytes});
  final String filename; final String mimeType; final Uint8List bytes;
  int get sizeInBytes => bytes.length;
}
final class BeakStoredFile {
  const BeakStoredFile({required this.key, required this.url, required this.sizeInBytes,
      required this.mimeType, this.width, this.height, this.variants = const {}});
  final String key; final Uri url; final int sizeInBytes; final String mimeType;
  final int? width; final int? height;
  final Map<String, BeakStoredFileVariant> variants; // e.g. 'thumbnail' -> {key,url,w,h}
}
```

### Config + credentials (selected at app init)
```dart
sealed class BeakStorageConfig { const BeakStorageConfig(); String get driverId; }
// BeakMemoryStorageConfig, BeakLocalDiskStorageConfig(rootDir, publicBaseUrl)
// BeakS3Config(endpoint, bucket, accessKey, secretKey, region, usePathStyle, publicBaseUrl?)  [Phase 06 driver reads this]
// BeakFtpConfig(host, port, user, password, baseDir, publicBaseUrl)                            [Phase 06 driver reads this]
```
Define the S3/FTP config classes here (pure data) so `beak_core` owns the config surface;
the drivers that consume them live in `beak_storage_s3`/`beak_storage_ftp`.
Add a `BeakStorageRegistry` mapping `driverId` → a `BeakStorageDriver` factory, so the
backend resolves the configured driver by id. Core registers `memory` + `local`; Phase 06
packages register `s3`/`ftp`.

### File rules + transforms (Filament-style, live on columns, enforced on upload)
```dart
enum BeakFileType { jpg, png, webp, gif, svg, pdf, csv, mp4, /* ... */ ;
  String get mime; List<String> get extensions; }
final class BeakDimensions { const BeakDimensions(this.width, this.height); ... }
sealed class BeakImageTransform {
  const BeakImageTransform();
}
// BeakResizeTransform(width?, height?, fit)  BeakFormatTransform(BeakImageFormat, quality)
// BeakThumbnailTransform(BeakDimensions, {name})
enum BeakImageFit { cover, contain, fill }
enum BeakImageFormat { jpg, png, webp }
```
```dart
abstract interface class BeakTransformRunner {           // impl in Phase 06 (image pkg)
  Future<BeakTransformedImage> run(Uint8List source, List<BeakImageTransform> pipeline);
}
```
```dart
final class BeakUploadValidator {                         // pure, no I/O
  const BeakUploadValidator();
  /// Validates an upload against a column's rules; returns typed field errors or ok.
  BeakResult<BeakUpload> validate(BeakUpload upload, {
    int? maxSizeInBytes,
    List<BeakFileType> allowedTypes = const [],
    BeakDimensions? maxDimensions,     // requires decoded dims; pass them in
    double? aspectRatio,
    BeakDimensions? actualDimensions,  // provided by the caller after decode
  });
}
```

### Drivers to implement now (in core, no external services)
- `BeakMemoryStorageDriver` — stores bytes in a `Map`, `url` returns a `memory://` URI.
- `BeakLocalDiskStorageDriver` — writes under a root dir, `url` = `publicBaseUrl/key`.
  Uses `dart:io`; keep it in `beak_core` (core is server-side-friendly pure Dart — no
  Flutter, but `dart:io` is fine).

## Tests to write FIRST
- `beak_upload_validator_test.dart` — size over/under limit; disallowed vs allowed MIME/
  extension; max dimensions; aspect ratio tolerance; returns typed `BeakValidationException`
  field errors (no dynamic).
- `beak_memory_driver_test.dart` / `beak_local_disk_driver_test.dart` — put→get→exists→
  url→delete round-trip; delete of missing key throws `BeakStorageException`;
  local-disk writes to a temp dir and cleans up.
- `beak_storage_registry_test.dart` — resolve by id; unknown id throws config exception.
- `beak_image_transform_test.dart` — transform value objects serialize/compare; pipeline
  is ordered; exhaustive `switch` over transforms compiles + tested.
- `beak_file_type_test.dart` — mime/extension mappings exhaustive.

## Implementation notes / constraints
- `beak_core` may use `dart:io`/`dart:typed_data` (server-side pure Dart). It must NOT
  import Flutter.
- Actual pixel transforms are NOT done here (no image lib in core) — `BeakTransformRunner`
  is an interface implemented in Phase 06. The validator takes already-decoded dimensions
  so it stays pure and testable.
- Keep credentials out of logs; `toString()` on config classes must redact secrets (test
  that `BeakS3Config.toString()` does not contain the secret key).

## Definition of Done (gate)
- [ ] analyze 0 · tests green · `beak_core` coverage 100% · format clean.
- [ ] Secret-redaction test passes.
- [ ] Exhaustive `switch` over transforms + storage configs tested.
- [ ] STATE.md row 05 → `✅ DONE` + SHA.

## Commit
`feat(beak_core): add pluggable storage abstraction, file rules and transform pipeline`
