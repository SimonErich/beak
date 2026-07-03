import 'dart:typed_data';

import 'beak_stored_file.dart';
import 'beak_upload.dart';

/// The pluggable file-storage seam: `beak_core` ships the `memory` and
/// `local` implementations, driver packages (S3, FTP, ...) add their own and
/// register them with a `BeakStorageRegistry`.
///
/// Keys are relative, `/`-separated paths (see `BeakStorageKeys`); every
/// method throws a `BeakStorageException` for malformed keys, and `get` and
/// `delete` throw one for missing files (`exists` reports `false` and
/// `url` builds addresses without probing storage).
abstract interface class BeakStorageDriver {
  /// Stable driver identifier matching `BeakStorageConfig.driverId`
  /// (`'s3'`, `'ftp'`, `'memory'`, `'local'`).
  String get id;

  /// Stores [upload] under the [path] prefix and returns its description.
  ///
  /// The key is `path/filename`; putting to an existing key overwrites it.
  Future<BeakStoredFile> put(BeakUpload upload, {required String path});

  /// Reads the content stored under [key].
  Future<Uint8List> get(String key);

  /// Deletes the file stored under [key].
  Future<void> delete(String key);

  /// A URL serving [key], valid for [expiresIn] where the backend supports
  /// expiring links (drivers without link expiry ignore it).
  Future<Uri> url(String key, {Duration? expiresIn});

  /// Whether a file is stored under [key].
  Future<bool> exists(String key);
}
