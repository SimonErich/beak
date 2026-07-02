# Phase 06 — beak_storage_s3 + beak_storage_ftp (concrete drivers)

## Objective
Implement the two concrete storage drivers behind the Phase 05 abstraction, plus a real
image-transform runner. S3 must be MinIO-compatible and integration-tested against the
Docker MinIO service.

## Prerequisites
- Phase 05 `✅ DONE`. Docker MinIO available (`melos run up`).

## Files created
- `packages/beak_storage_s3/` — `lib/beak_storage_s3.dart`, `lib/src/s3_storage_driver.dart`
- `packages/beak_storage_ftp/` — `lib/beak_storage_ftp.dart`, `lib/src/ftp_storage_driver.dart`
- Image transform runner: put in `beak_storage_s3`? No — shared. Create it in a tiny
  `packages/beak_storage_transform/` OR (simpler) in `beak_core` guarded behind the
  `BeakTransformRunner` interface using the `image` package. **Decision: implement
  `ImageTransformRunner` in a new leaf package `packages/beak_image/`** that depends on
  `beak_core` + `package:image`, so `beak_core` stays dependency-light. Register it with
  the backend in Phase 09.

## Public API to implement (contract)

### S3 driver (uses an S3 client lib, e.g. `minio` or `aws_s3_api`; pick one and pin it)
```dart
final class S3StorageDriver implements BeakStorageDriver {
  S3StorageDriver(BeakS3Config config);
  @override String get id => 's3';
  // put: uploads bytes to bucket at `path/filename`, content-type set; returns
  //   BeakStoredFile with a public or presigned url (per config.publicBaseUrl).
  // url: presigned GET when expiresIn given, else public url.
  // get/delete/exists: straightforward.
}
void registerS3Storage(BeakStorageRegistry registry); // registers factory for 's3'
```

### FTP driver (uses `ftpconnect` or similar; pin it)
```dart
final class FtpStorageDriver implements BeakStorageDriver {
  FtpStorageDriver(BeakFtpConfig config);
  @override String get id => 'ftp';
  // put: connects, ensures baseDir/path, stores bytes; url = publicBaseUrl/key.
  // get/delete/exists via FTP commands.
}
void registerFtpStorage(BeakStorageRegistry registry);
```

### Image transform runner (`beak_image`)
```dart
final class ImageTransformRunner implements BeakTransformRunner {
  const ImageTransformRunner();
  // decode source; apply pipeline in order (resize/format/thumbnail); return encoded
  // main image + any named thumbnails as BeakTransformedImage (bytes + dims per variant).
}
```

## Tests to write FIRST
- **Unit (no services):**
  - `s3_storage_driver_test.dart` — build against a fake/mock S3 client to assert the
    driver forms the right bucket/key/content-type and maps errors to
    `BeakStorageException`. (Abstract the client behind a thin seam you can fake.)
  - `ftp_storage_driver_test.dart` — same approach with a fake FTP transport.
  - `image_transform_runner_test.dart` — feed a tiny generated PNG (create in-test via
    `package:image`); assert resize output dims, format conversion (magic bytes), and
    that a thumbnail variant is produced with the requested size.
- **Integration (tagged `integration`, needs MinIO):**
  - `s3_minio_integration_test.dart` — real `put`→`get`→`exists`→presigned `url`
    (HTTP GET works)→`delete` against `local/beak-uploads`. Guard with a health check;
    skip-with-clear-message only if `BEAK_S3_ENDPOINT` unreachable (but the gate runs
    with services up, so it must actually pass).

## Implementation notes / constraints
- Pin exact package versions in each pubspec; prefer well-maintained pure-Dart clients.
- Map ALL driver/transport errors to `BeakStorageException` with a useful code — never
  leak the client's raw exception across the boundary.
- `usePathStyle: true` for MinIO. Content-type inferred from `BeakUpload.mimeType`.
- Keep drivers stateless per call or pool connections cleanly (close them; the
  `close_sinks`/`cancel_subscriptions` lints are on).

## Definition of Done (gate)
- [ ] analyze 0 · unit tests green · **integration tests green against MinIO** · format clean.
- [ ] Coverage ≥ 85% for both driver packages and `beak_image`.
- [ ] `registerS3Storage`/`registerFtpStorage` register working factories resolvable via
      `BeakStorageRegistry`.
- [ ] STATE.md row 06 → `✅ DONE` + SHA.

## Commit
`feat(storage): add S3 (MinIO) and FTP drivers plus image transform runner`
