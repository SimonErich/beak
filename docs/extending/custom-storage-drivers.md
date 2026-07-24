---
title: Custom storage drivers
description: Implement BeakStorageDriver's five methods, hide the wire behind a thin transport seam, and register the driver so a config selects it.
---

# Custom storage drivers

After this page you can implement `BeakStorageDriver`, keep its wire protocol
behind a testable seam the way the S3 and FTP drivers do, and register it so a
`BeakStorageConfig` picks it at startup. Beak's uploads then land wherever you
say: a bucket, an FTP host, a content API of your own.

Storage in Beak is pluggable for the same reason data is. `beak_core` ships the
`memory` and `local` drivers; driver packages (`beak_storage_s3`,
`beak_storage_ftp`) add the rest and plug in at app init. Nothing is hard-wired.
Your driver joins that set.

## The interface

A driver is five methods over one relative, `/`-separated key. It lives behind
the `BeakStorageDriver` interface in `beak_core`:

```dart title="packages/beak_core/lib/src/storage/beak_storage_driver.dart"
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
```

| Method | Returns | The contract |
| --- | --- | --- |
| `id` | `String` | Matches the `driverId` of the config that selects you. |
| `put` | `BeakStoredFile` | Key is `path/filename`; overwrite an existing key. |
| `get` | `Uint8List` | Throw `BeakStorageException` when the key is absent. |
| `delete` | nothing | Throw `BeakStorageException` when the key is absent. |
| `url` | `Uri` | Build the address without probing storage; honor `expiresIn` only if your backend can. |
| `exists` | `bool` | Report `false` for an absent key, never throw for absence. |

Keys are validated, relative paths. Use `BeakStorageKeys.join`, `.validate`, and
`.appendToBaseUrl` for them, and throw `BeakStorageException` for a malformed key
or a missing file, so no raw protocol error escapes the driver.

## The cleanest reference: the FTP driver

`FtpStorageDriver` is the one to copy. It is small, it validates every key, and
it wraps every transport failure in a `BeakStorageException` so the boundary
stays clean.

```dart title="packages/beak_storage_ftp/lib/src/ftp_storage_driver.dart"
final class FtpStorageDriver implements BeakStorageDriver {
  /// Creates a driver for [config]; [transport] overrides the wire transport
  /// for tests (default: a [SocketFtpTransport] built from [config]).
  FtpStorageDriver(BeakFtpConfig config, {FtpTransport? transport})
    : _config = config,
      _transport = transport ?? SocketFtpTransport(config);

  final BeakFtpConfig _config;
  final FtpTransport _transport;

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

  // delete / url / exists follow the same validate-then-guard shape.
}
```

The `_guard` helper is the boundary rule in code: it rethrows Beak's own
exceptions untouched and wraps everything else in a `BeakStorageException`.

```dart title="packages/beak_storage_ftp/lib/src/ftp_storage_driver.dart"
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
```

## The seam pattern

Notice the driver never touches a socket. It talks to an `FtpTransport`, a thin
interface it can be tested against with a fake. That separation is the pattern
worth copying: driver *logic* (key handling, error mapping, URL building) on one
side, the *wire* on the other.

```dart title="packages/beak_storage_ftp/lib/src/ftp_transport.dart"
abstract interface class FtpTransport {
  /// Uploads [bytes] under [key], creating missing parent directories.
  Future<void> store(String key, Uint8List bytes);

  /// Downloads the file stored under [key].
  Future<Uint8List> retrieve(String key);

  /// Deletes the file stored under [key].
  Future<void> remove(String key);

  /// Whether a file is stored under [key].
  Future<bool> exists(String key);
}
```

The production implementation, `SocketFtpTransport`, speaks RFC 959 over
`dart:io`. A test supplies its own in-memory `FtpTransport` through the driver's
`transport` parameter, so you exercise the driver's logic without a server. The
S3 driver mirrors this exactly: `S3StorageDriver` logic behind an
`S3ObjectClient` seam, with `MinioS3ObjectClient` in production and a fake
`S3ObjectClient` in tests.

!!! tip "Why the seam earns its keep"
    The driver holds the interesting behavior: which reply means "missing", how
    a key becomes a URL, where the `BeakStorageException` boundary sits. Put a
    real socket in that code and you can only test it against a live server. Put
    it behind an interface and the whole driver is unit-testable against a map.

## Registering the driver

A driver resolves from config through a `BeakStorageRegistry`, which maps a
`driverId` to a factory. The convention is a `register<Name>Storage` function,
one line, that a driver package exposes:

```dart title="packages/beak_storage_ftp/lib/src/ftp_storage_driver.dart"
void registerFtpStorage(BeakStorageRegistry registry) {
  registry.register('ftp', FtpStorageDriver.fromConfig);
}
```

`FtpStorageDriver.fromConfig` is the factory. It narrows the sealed
`BeakStorageConfig` with pattern matching and throws
`BeakConfigurationException` for a foreign config type, so the id and the config
type stay in lockstep:

```dart title="packages/beak_storage_ftp/lib/src/ftp_storage_driver.dart"
factory FtpStorageDriver.fromConfig(BeakStorageConfig config) =>
    switch (config) {
      BeakFtpConfig() => FtpStorageDriver(config),
      _ => throw BeakConfigurationException(
        'FtpStorageDriver requires a BeakFtpConfig, '
        'got ${config.runtimeType}.',
      ),
    };
```

The registry pre-registers `memory` and `local`; the server adds `s3` and `ftp`
through `createDefaultStorageRegistry`. Register yours the same way, then
`resolve` a config to a driver:

```dart title="packages/beak_core/lib/src/storage/beak_storage_registry.dart"
final registry = BeakStorageRegistry()
  ..register('s3', BeakS3StorageDriver.fromConfig); // from beak_storage_s3

// Later, build the driver the config selects:
final BeakStorageDriver driver = registry.resolve(
  BeakS3Config(
    endpoint: Uri.parse('https://s3.eu-central-1.amazonaws.com'),
    bucket: 'uploads',
    accessKey: accessKey,
    secretKey: secretKey,
    region: 'eu-central-1',
  ),
);
```

## Where your config lives

`BeakStorageConfig` is a **sealed** family in `beak_core`, so a config carries a
`driverId` and the settings your driver needs, and every factory can match it
exhaustively. A genuinely new backend therefore comes in two parts: a
`BeakStorageConfig` subtype in `beak_core` (its settings and `driverId`) and a
driver package that implements `BeakStorageDriver` and exposes a
`register<Name>Storage` function, exactly as `beak_storage_ftp` and
`beak_storage_s3` are laid out. The contributing guide walks that split in
detail.

Once registered, the server resolves your driver at startup and hands it to the
upload service. Nothing else changes: file columns, validation, and the upload
route already speak `BeakStorageDriver`.

```dart title="packages/beak_backend/lib/src/server/storage_wiring.dart"
final storage = resolveStorage(
  BeakS3Config(
    endpoint: Uri.parse('https://s3.example.com'),
    bucket: 'uploads',
    accessKey: accessKey,
    secretKey: secretKey,
    region: 'us-east-1',
  ),
);
final server = BeakServer(
  config: config,
  registry: registry,
  dataSource: dataSource,
  storage: storage,
);
```

## Continue reading

- [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md) the validate-transform-store pipeline your driver's `put` sits at the end of.
- [Files and storage columns](../models/files-and-storage-columns.md) the image and file columns that produce the uploads.
- [Writing a storage driver](../contributing/writing-a-storage-driver.md) the config-plus-package split for contributing a driver upstream.
- [Custom data sources](custom-data-sources.md) the same pluggable pattern for records instead of files.
