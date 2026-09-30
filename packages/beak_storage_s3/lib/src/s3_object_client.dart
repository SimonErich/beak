import 'dart:typed_data';

/// The thin seam between [S3StorageDriver] logic and the S3 wire client, so
/// driver behavior is unit-testable against a fake.
///
/// Implementations expose raw S3 object operations and surface their own
/// transport errors; the driver maps them to [BeakStorageException]. The
/// production implementation is [HttpS3ObjectClient]; a test supplies its own
/// in-memory implementation via the `S3StorageDriver` `client` parameter.
///
/// ```dart
/// final class FakeS3ObjectClient implements S3ObjectClient {
///   final Map<String, Uint8List> objects = {};
///   // ... implement putObject/getObject/... against `objects`.
/// }
///
/// final driver = S3StorageDriver(config, client: FakeS3ObjectClient());
/// ```
// --8<-- [start:S3ObjectClient]
abstract interface class S3ObjectClient {
  /// Uploads [bytes] to [bucket] under [key] with [contentType] set.
  Future<void> putObject({
    required String bucket,
    required String key,
    required Uint8List bytes,
    required String contentType,
  });

  /// Downloads the object stored in [bucket] under [key], or `null` when no
  /// such object exists.
  Future<Uint8List?> getObject({required String bucket, required String key});

  /// Deletes the object stored in [bucket] under [key] (a no-op when it does
  /// not exist — S3 deletes are idempotent).
  Future<void> removeObject({required String bucket, required String key});

  /// Whether an object is stored in [bucket] under [key].
  Future<bool> objectExists({required String bucket, required String key});

  /// A presigned GET URL for the object in [bucket] under [key], valid for
  /// [expiresIn].
  Future<Uri> presignedGetUrl({
    required String bucket,
    required String key,
    required Duration expiresIn,
  });
}
// --8<-- [end:S3ObjectClient]
