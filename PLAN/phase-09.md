# Phase 09 — beak_backend: file upload endpoints + storage wiring

## Objective
Add upload endpoints that enforce a column's Filament-style file rules, run the image
transform pipeline, store via the configured driver, and return a typed `BeakStoredFile`.
Wire the storage registry (memory/local/S3/FTP) and the image runner into the server.

## Prerequisites
- Phases 06 (drivers + image runner) and 08 (CRUD) `✅ DONE`. MinIO available.

## Files created (in `packages/beak_backend/lib/src/`)
- `uploads/upload_router.dart`, `uploads/upload_handler.dart`
- `uploads/upload_service.dart`
- `server/storage_wiring.dart` (resolves `BeakStorageConfig` → driver via registry)
- barrel updates; `beak_backend` gains dev/runtime deps on `beak_storage_s3`,
  `beak_storage_ftp`, `beak_image` (registered, not hard-wired).

## REST surface
```
POST /api/{table}/{columnKey}/upload    multipart/form-data (file field 'file')
     -> 201 { key, url, sizeInBytes, mimeType, width?, height?, variants? }   (BeakStoredFile)
DELETE /api/{table}/{columnKey}/upload   body: { key }   -> 204
```

## Service (contract)
```dart
final class UploadService {
  UploadService({required this.registry, required this.storage, required this.transformRunner});
  final BeakModelRegistry registry;
  final BeakStorageDriver storage;
  final BeakTransformRunner transformRunner;

  Future<BeakStoredFile> handle({
    required String table,
    required String columnKey,
    required BeakUpload upload,
  });
  Future<void> remove(String table, String columnKey, String key);
}
```
Flow inside `handle`:
1. Resolve the column from the registry; assert it is a `BeakImageColumn` or
   `BeakFileColumn` (else `BeakConfigurationException` → 400).
2. If image: decode dimensions (via the image runner/util) and run
   `BeakUploadValidator.validate(...)` with the column's `maxSizeInBytes`, `allowedTypes`,
   `maxDimensions`, `aspectRatio`, `actualDimensions`. If file: validate size + types.
   On failure → `BeakValidationException` (→ 422 with field errors).
3. If image with `transforms`: run the pipeline → main encoded image + named thumbnails.
4. `storage.put(...)` the main file at the column's `storagePath` (unique key, e.g.
   `storagePath/{uuid}.{ext}`), and each thumbnail variant; assemble `BeakStoredFile`
   with `variants`.
5. Return it. The returned `key`/`url` is what the client stores in the record's column
   value on the subsequent create/update.

## Storage wiring (contract)
```dart
BeakStorageDriver resolveStorage(BeakStorageConfig config, BeakStorageRegistry registry);
// registry has memory+local (core) + s3+ftp (registered by their packages at startup).
```
The app selects a `BeakStorageConfig` at init (from env in the reference server); the
server resolves the driver once and injects it into `UploadService`.

## Tests to write FIRST
- **Unit** (`InMemoryAdapter` + `BeakMemoryStorageDriver` + a fake/real image runner):
  - `upload_service_test.dart` — happy path returns `BeakStoredFile` with correct
    mime/size/dims; oversize → 422 with the size rule message; disallowed type → 422;
    non-image/file column → 400; transforms produce the expected named variants (stored
    keys exist in the memory driver).
  - `upload_handler_test.dart` — multipart parse via Shelf; success 201 body shape;
    missing file field → 400; delete → 204.
- **Integration** (tagged, MinIO up):
  - `upload_s3_integration_test.dart` — POST a real small PNG to an image column backed by
    `S3StorageDriver`; assert the returned public/presigned url serves the bytes; a
    thumbnail variant is retrievable; DELETE removes it.

## Implementation notes / constraints
- Multipart handling with `shelf_multipart` (pin it). Stream the file into a
  `BeakUpload` (bounded — enforce max size early to avoid buffering huge bodies; reject
  over the column limit before full read where possible).
- Keys are unique and namespaced by `storagePath`; never trust the client filename for the
  key (sanitize; derive extension from validated MIME).
- All errors mapped via middleware; service throws typed exceptions only.

## Definition of Done (gate)
- [ ] analyze 0 · unit + **S3 integration** tests green · coverage ≥ 90% · format clean.
- [ ] Rule enforcement (size/type/dimensions) proven with typed 422 bodies.
- [ ] Transform pipeline produces and stores named variants (proven end-to-end on MinIO).
- [ ] STATE.md row 09 → `✅ DONE` + SHA.

## Commit
`feat(beak_backend): add validated, transform-aware file upload endpoints`
