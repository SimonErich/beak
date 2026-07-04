import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';
import 'package:minio/minio.dart';

/// The thin seam between [S3StorageDriver] logic and the S3 wire client, so
/// driver behavior is unit-testable against a fake.
///
/// Implementations expose raw S3 object operations and surface their own
/// transport errors; the driver maps them to [BeakStorageException]. The
/// production implementation is [MinioS3ObjectClient]; a test supplies its own
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

/// The production [S3ObjectClient], speaking the S3 API (AWS, MinIO, ...)
/// via `package:minio`.
///
/// [S3StorageDriver] constructs one of these from its [BeakS3Config] when no
/// test client is injected, so application code rarely instantiates it
/// directly.
///
/// ```dart
/// final client = MinioS3ObjectClient(BeakS3Config(
///   endpoint: Uri.parse('http://localhost:29000'),
///   bucket: 'uploads',
///   accessKey: 'minioadmin',
///   secretKey: 'minioadmin',
///   region: 'us-east-1',
///   usePathStyle: true,
/// ));
/// ```
final class MinioS3ObjectClient implements S3ObjectClient {
  /// Creates a client for the endpoint and credentials in [config].
  ///
  /// The endpoint's scheme selects TLS (`https` → SSL), its host and optional
  /// port address the server, and [BeakS3Config.usePathStyle] chooses
  /// path-style vs. virtual-host bucket addressing (MinIO needs path-style).
  MinioS3ObjectClient(BeakS3Config config)
    : _minio = Minio(
        endPoint: config.endpoint.host,
        port: config.endpoint.hasPort ? config.endpoint.port : null,
        useSSL: config.endpoint.scheme == 'https',
        accessKey: config.accessKey,
        secretKey: config.secretKey,
        region: config.region,
        pathStyle: config.usePathStyle,
      );

  final Minio _minio;

  @override
  Future<void> putObject({
    required String bucket,
    required String key,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await _minio.putObject(
      bucket,
      key,
      Stream.value(bytes),
      size: bytes.length,
      metadata: {'content-type': contentType},
    );
  }

  @override
  Future<Uint8List?> getObject({
    required String bucket,
    required String key,
  }) async {
    final Stream<List<int>> stream;
    try {
      stream = await _minio.getObject(bucket, key);
    } on MinioS3Error catch (error) {
      if (_isMissingObject(error)) {
        return null;
      }
      rethrow;
    }
    final BytesBuilder builder = BytesBuilder(copy: false);
    await stream.forEach(builder.add);
    return builder.takeBytes();
  }

  @override
  Future<void> removeObject({required String bucket, required String key}) =>
      _minio.removeObject(bucket, key);

  @override
  Future<bool> objectExists({
    required String bucket,
    required String key,
  }) async {
    try {
      await _minio.statObject(bucket, key);
      return true;
    } on MinioS3Error catch (error) {
      if (_isMissingObject(error)) {
        return false;
      }
      rethrow;
    }
  }

  @override
  Future<Uri> presignedGetUrl({
    required String bucket,
    required String key,
    required Duration expiresIn,
  }) async {
    final String url = await _minio.presignedGetObject(
      bucket,
      key,
      expires: expiresIn.inSeconds,
    );
    return Uri.parse(url);
  }

  static bool _isMissingObject(MinioS3Error error) =>
      error.response?.statusCode == 404;
}
