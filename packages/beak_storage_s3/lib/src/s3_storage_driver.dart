import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';

import 's3_object_client.dart';

/// Stores files in an S3-compatible bucket (AWS S3, MinIO, ...) configured
/// by a [BeakS3Config] — Beak's production storage driver.
///
/// Public URLs prefer the configured `publicBaseUrl` (e.g. a CDN); without
/// one they address the bucket directly, path-style
/// (`endpoint/bucket/key`, as MinIO requires) or virtual-host style
/// (`bucket.endpoint/key`) per `usePathStyle`.
final class S3StorageDriver implements BeakStorageDriver {
  /// Creates a driver for [config]; [client] overrides the wire client for
  /// tests.
  S3StorageDriver(BeakS3Config config, {S3ObjectClient? client})
    : _config = config,
      _client = client ?? MinioS3ObjectClient(config);

  /// Creates the driver from its [BeakS3Config].
  ///
  /// Throws a [BeakConfigurationException] for any other config type; the
  /// signature is registry-compatible on purpose.
  factory S3StorageDriver.fromConfig(BeakStorageConfig config) =>
      switch (config) {
        BeakS3Config() => S3StorageDriver(config),
        _ => throw BeakConfigurationException(
          'S3StorageDriver requires a BeakS3Config, '
          'got ${config.runtimeType}.',
        ),
      };

  final BeakS3Config _config;
  final S3ObjectClient _client;

  @override
  String get id => 's3';

  @override
  Future<BeakStoredFile> put(BeakUpload upload, {required String path}) async {
    final String key = BeakStorageKeys.join(
      path: path,
      filename: upload.filename,
    );
    await _guard('put', key, () {
      return _client.putObject(
        bucket: _config.bucket,
        key: key,
        bytes: upload.bytes,
        contentType: upload.mimeType,
      );
    });
    return BeakStoredFile(
      key: key,
      url: _publicUrlFor(key),
      sizeInBytes: upload.sizeInBytes,
      mimeType: upload.mimeType,
    );
  }

  @override
  Future<Uint8List> get(String key) async {
    BeakStorageKeys.validate(key);
    final Uint8List? bytes = await _guard('get', key, () {
      return _client.getObject(bucket: _config.bucket, key: key);
    });
    if (bytes == null) {
      throw BeakStorageException('No file is stored under "$key".');
    }
    return bytes;
  }

  @override
  Future<void> delete(String key) async {
    BeakStorageKeys.validate(key);
    await _guard('delete', key, () async {
      final bool present = await _client.objectExists(
        bucket: _config.bucket,
        key: key,
      );
      if (!present) {
        throw BeakStorageException('No file is stored under "$key".');
      }
      await _client.removeObject(bucket: _config.bucket, key: key);
    });
  }

  /// A presigned GET URL when [expiresIn] is given, else the public URL.
  @override
  Future<Uri> url(String key, {Duration? expiresIn}) async {
    BeakStorageKeys.validate(key);
    if (expiresIn == null) {
      return _publicUrlFor(key);
    }
    return _guard('presign', key, () {
      return _client.presignedGetUrl(
        bucket: _config.bucket,
        key: key,
        expiresIn: expiresIn,
      );
    });
  }

  @override
  Future<bool> exists(String key) async {
    BeakStorageKeys.validate(key);
    return _guard('exists', key, () {
      return _client.objectExists(bucket: _config.bucket, key: key);
    });
  }

  /// Runs [operation], rethrowing Beak's own exceptions untouched and
  /// wrapping every client/transport error in a [BeakStorageException] so no
  /// raw client exception crosses the driver boundary.
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

  Uri _publicUrlFor(String key) {
    final Uri? publicBaseUrl = _config.publicBaseUrl;
    if (publicBaseUrl != null) {
      return BeakStorageKeys.appendToBaseUrl(publicBaseUrl, key);
    }
    if (_config.usePathStyle) {
      return BeakStorageKeys.appendToBaseUrl(
        _config.endpoint,
        '${_config.bucket}/$key',
      );
    }
    final Uri endpoint = _config.endpoint;
    return BeakStorageKeys.appendToBaseUrl(
      endpoint.replace(host: '${_config.bucket}.${endpoint.host}'),
      key,
    );
  }
}

/// Registers the S3 driver factory under `'s3'` so [BeakStorageRegistry]
/// resolves [BeakS3Config]s to an [S3StorageDriver].
void registerS3Storage(BeakStorageRegistry registry) {
  registry.register('s3', S3StorageDriver.fromConfig);
}
