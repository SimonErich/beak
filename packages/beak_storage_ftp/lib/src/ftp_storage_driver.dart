import 'dart:typed_data';

import 'package:beak_core/beak_core.dart';

import 'ftp_transport.dart';

/// Stores files on an FTP server configured by a [BeakFtpConfig], serving
/// them from the configured public base URL (an HTTP server is expected to
/// front the FTP directory — FTP itself has no expiring links, so [url]
/// ignores its `expiresIn`).
///
/// Every method validates the key and wraps any transport failure in a
/// [BeakStorageException] so no raw socket or [FtpProtocolException] escapes.
/// Prefer [registerFtpStorage] + a `BeakStorageRegistry` to build one from
/// config; construct directly only when injecting a test [FtpTransport]:
///
/// ```dart
/// final driver = FtpStorageDriver(BeakFtpConfig(
///   host: 'ftp.example.com',
///   user: 'uploads',
///   password: '...',
///   baseDir: '/var/www/uploads',
///   publicBaseUrl: Uri.parse('https://cdn.example.com/uploads'),
/// ));
///
/// final stored = await driver.put(upload, path: 'products/42');
/// final publicUrl = await driver.url(stored.key);
/// ```
final class FtpStorageDriver implements BeakStorageDriver {
  /// Creates a driver for [config]; [transport] overrides the wire transport
  /// for tests (default: a [SocketFtpTransport] built from [config]).
  FtpStorageDriver(BeakFtpConfig config, {FtpTransport? transport})
    : _config = config,
      _transport = transport ?? SocketFtpTransport(config);

  // --8<-- [start:ftpDriverFromConfig]
  /// Creates the driver from its [BeakFtpConfig].
  ///
  /// Throws a [BeakConfigurationException] for any other config type; the
  /// signature matches [BeakStorageRegistry.register] on purpose, which is how
  /// [registerFtpStorage] wires this factory in.
  factory FtpStorageDriver.fromConfig(BeakStorageConfig config) =>
      switch (config) {
        BeakFtpConfig() => FtpStorageDriver(config),
        _ => throw BeakConfigurationException(
          'FtpStorageDriver requires a BeakFtpConfig, '
          'got ${config.runtimeType}.',
        ),
      };
  // --8<-- [end:ftpDriverFromConfig]

  final BeakFtpConfig _config;
  final FtpTransport _transport;

  // --8<-- [start:ftpDriverPut]
  @override
  String get id => 'ftp';

  @override
  Future<BeakStoredFile> put(BeakUpload upload, {required String path}) async {
    final String key = BeakStorageKeys.join(
      path: path,
      filename: upload.filename,
    );
    await _guard('store', key, () => _transport.store(key, upload.bytes));
    return BeakStoredFile(
      key: key,
      url: _urlFor(key),
      sizeInBytes: upload.sizeInBytes,
      mimeType: upload.mimeType,
    );
  }
  // --8<-- [end:ftpDriverPut]

  /// Downloads the bytes stored under [key].
  ///
  /// Throws a [BeakStorageException] when [key] is invalid or the server
  /// reports no such file (a `550` reply).
  @override
  Future<Uint8List> get(String key) async {
    BeakStorageKeys.validate(key);
    return _guard(
      'retrieve',
      key,
      () => _transport.retrieve(key),
      missingFileReplies: true,
    );
  }

  /// Deletes the file stored under [key].
  ///
  /// Throws a [BeakStorageException] when [key] is invalid or the server
  /// reports no such file (a `550` reply).
  @override
  Future<void> delete(String key) async {
    BeakStorageKeys.validate(key);
    await _guard(
      'remove',
      key,
      () => _transport.remove(key),
      missingFileReplies: true,
    );
  }

  /// FTP URLs cannot expire; [expiresIn] is ignored.
  @override
  Future<Uri> url(String key, {Duration? expiresIn}) async {
    BeakStorageKeys.validate(key);
    return _urlFor(key);
  }

  @override
  Future<bool> exists(String key) async {
    BeakStorageKeys.validate(key);
    return _guard('exists', key, () => _transport.exists(key));
  }

  /// Runs [operation], rethrowing Beak's own exceptions untouched and
  /// wrapping every transport error in a [BeakStorageException] so no raw
  /// transport exception crosses the driver boundary. With
  /// [missingFileReplies], a `550` reply means the file does not exist —
  /// only set for operations on files that should already be stored.
  // --8<-- [start:ftpDriverGuard]
  Future<T> _guard<T>(
    String operationName,
    String key,
    Future<T> Function() operation, {
    bool missingFileReplies = false,
  }) async {
    try {
      return await operation();
    } on BeakException {
      rethrow;
    } on FtpProtocolException catch (error) {
      if (missingFileReplies && error.replyCode == 550) {
        throw BeakStorageException('No file is stored under "$key".');
      }
      throw BeakStorageException(
        'FTP $operationName failed for "$key" '
        '(reply ${error.replyCode}): ${error.message}',
      );
    } on Object catch (error) {
      throw BeakStorageException(
        'FTP $operationName failed for "$key": $error',
      );
    }
  }
  // --8<-- [end:ftpDriverGuard]

  Uri _urlFor(String key) =>
      BeakStorageKeys.appendToBaseUrl(_config.publicBaseUrl, key);
}

/// Registers the FTP driver factory under `'ftp'` so [BeakStorageRegistry]
/// resolves [BeakFtpConfig]s to an [FtpStorageDriver].
///
/// Call once during startup, before resolving any storage config:
///
/// ```dart
/// final registry = BeakStorageRegistry();
/// registerFtpStorage(registry);
/// final driver = registry.resolve(ftpConfig); // -> FtpStorageDriver
/// ```
// --8<-- [start:registerFtpStorage]
void registerFtpStorage(BeakStorageRegistry registry) {
  registry.register('ftp', FtpStorageDriver.fromConfig);
}

// --8<-- [end:registerFtpStorage]
