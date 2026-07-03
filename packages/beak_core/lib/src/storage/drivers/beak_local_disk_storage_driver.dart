import 'dart:io';
import 'dart:typed_data';

import '../../common/beak_exception.dart';
import '../beak_storage_config.dart';
import '../beak_storage_driver.dart';
import '../beak_storage_key.dart';
import '../beak_stored_file.dart';
import '../beak_upload.dart';

/// Stores files on the local filesystem under a root directory — the driver
/// for development and single-host deployments. URLs are built by appending
/// the key to the configured public base URL, under which the app serves the
/// root directory.
final class BeakLocalDiskStorageDriver implements BeakStorageDriver {
  /// Creates a driver writing under [rootDir] and serving from
  /// [publicBaseUrl].
  BeakLocalDiskStorageDriver({
    required String rootDir,
    required this.publicBaseUrl,
  }) : _rootDir = rootDir.replaceAll(RegExp(r'/+$'), '');

  /// Creates the driver from its [BeakLocalDiskStorageConfig].
  ///
  /// Throws a [BeakConfigurationException] for any other config type; the
  /// signature is registry-compatible on purpose.
  factory BeakLocalDiskStorageDriver.fromConfig(BeakStorageConfig config) =>
      switch (config) {
        BeakLocalDiskStorageConfig(:final rootDir, :final publicBaseUrl) =>
          BeakLocalDiskStorageDriver(
            rootDir: rootDir,
            publicBaseUrl: publicBaseUrl,
          ),
        _ => throw BeakConfigurationException(
          'BeakLocalDiskStorageDriver requires a BeakLocalDiskStorageConfig, '
          'got ${config.runtimeType}.',
        ),
      };

  final String _rootDir;

  /// Base URL stored files are publicly served from.
  final Uri publicBaseUrl;

  @override
  String get id => 'local';

  @override
  Future<BeakStoredFile> put(BeakUpload upload, {required String path}) async {
    final String key = BeakStorageKeys.join(
      path: path,
      filename: upload.filename,
    );
    final File file = _fileFor(key);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(upload.bytes, flush: true);
    return BeakStoredFile(
      key: key,
      url: _urlFor(key),
      sizeInBytes: upload.sizeInBytes,
      mimeType: upload.mimeType,
    );
  }

  @override
  Future<Uint8List> get(String key) async {
    final File file = _fileFor(key);
    if (!await file.exists()) {
      throw BeakStorageException('No file is stored under "$key".');
    }
    return file.readAsBytes();
  }

  @override
  Future<void> delete(String key) async {
    final File file = _fileFor(key);
    if (!await file.exists()) {
      throw BeakStorageException('No file is stored under "$key".');
    }
    await file.delete();
  }

  /// Local URLs do not expire; [expiresIn] is ignored.
  @override
  Future<Uri> url(String key, {Duration? expiresIn}) async {
    BeakStorageKeys.validate(key);
    return _urlFor(key);
  }

  @override
  Future<bool> exists(String key) => _fileFor(key).exists();

  File _fileFor(String key) {
    BeakStorageKeys.validate(key);
    return File('$_rootDir/$key');
  }

  Uri _urlFor(String key) =>
      BeakStorageKeys.appendToBaseUrl(publicBaseUrl, key);
}
