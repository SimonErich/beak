import 'dart:typed_data';

import '../../common/beak_exception.dart';
import '../beak_storage_config.dart';
import '../beak_storage_driver.dart';
import '../beak_storage_key.dart';
import '../beak_stored_file.dart';
import '../beak_upload.dart';

/// Keeps files in an in-process map — the driver for unit tests and
/// prototypes. URLs use the synthetic `memory:///key` scheme and, like the
/// stored bytes, vanish with the process.
final class BeakMemoryStorageDriver implements BeakStorageDriver {
  /// Creates an empty in-memory store.
  BeakMemoryStorageDriver();

  /// Creates the driver from its [BeakMemoryStorageConfig].
  ///
  /// Throws a [BeakConfigurationException] for any other config type; the
  /// signature is registry-compatible on purpose.
  factory BeakMemoryStorageDriver.fromConfig(BeakStorageConfig config) =>
      switch (config) {
        BeakMemoryStorageConfig() => BeakMemoryStorageDriver(),
        _ => throw BeakConfigurationException(
          'BeakMemoryStorageDriver requires a BeakMemoryStorageConfig, '
          'got ${config.runtimeType}.',
        ),
      };

  final Map<String, Uint8List> _contents = {};

  // --8<-- [start:memoryDriverMembers]
  @override
  String get id => 'memory';

  @override
  Future<BeakStoredFile> put(BeakUpload upload, {required String path}) async {
    final String key = BeakStorageKeys.join(
      path: path,
      filename: upload.filename,
    );
    _contents[key] = Uint8List.fromList(upload.bytes);
    return BeakStoredFile(
      key: key,
      url: _urlFor(key),
      sizeInBytes: upload.sizeInBytes,
      mimeType: upload.mimeType,
    );
  }

  @override
  Future<Uint8List> get(String key) async {
    BeakStorageKeys.validate(key);
    final Uint8List? bytes = _contents[key];
    if (bytes == null) {
      throw BeakStorageException('No file is stored under "$key".');
    }
    return Uint8List.fromList(bytes);
  }

  @override
  Future<void> delete(String key) async {
    BeakStorageKeys.validate(key);
    if (_contents.remove(key) == null) {
      throw BeakStorageException('No file is stored under "$key".');
    }
  }

  /// Memory URIs do not expire; [expiresIn] is ignored.
  @override
  Future<Uri> url(String key, {Duration? expiresIn}) async {
    BeakStorageKeys.validate(key);
    return _urlFor(key);
  }

  @override
  Future<bool> exists(String key) async {
    BeakStorageKeys.validate(key);
    return _contents.containsKey(key);
  }
  // --8<-- [end:memoryDriverMembers]

  Uri _urlFor(String key) => Uri(scheme: 'memory', host: '', path: '/$key');
}
