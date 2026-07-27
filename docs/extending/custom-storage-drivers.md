---
title: Custom storage drivers
description: Implement BeakStorageDriver's six members, hide the wire behind a thin transport seam, and register the driver so an environment variable selects it.
---

# Custom storage drivers

After this page you can implement `BeakStorageDriver`, keep its wire protocol
behind a testable seam the way the S3 and FTP drivers do, and register it in
`lib/server.dart` so a `BeakStorageConfig` picks it at startup. Beak's uploads
then land wherever you say: a bucket, an FTP host, a content API of your own.

Storage in Beak is pluggable for the same reason data is. `memory` and `local`
ship in the box; driver packages (`beak_storage_s3`, `beak_storage_ftp`) add the
rest and plug in at app init. Nothing is hard-wired. Your driver joins that set.

## The interface

A driver is an id and five methods over one relative, `/`-separated key:

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

| Member | Returns | The contract |
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
  // ...the `fromConfig` factory the registry calls...
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

  // ...delete, url and exists, the same validate-then-guard shape...
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

## The factory

A driver resolves from config through a `BeakStorageRegistry`, which maps a
`driverId` to a factory. The factory narrows the sealed `BeakStorageConfig` with
pattern matching and throws `BeakConfigurationException` for a foreign config
type, so the id and the config type stay in lockstep:

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

The convention is a `register<Name>Storage` function, one line, that a driver
package exposes:

```dart title="packages/beak_storage_ftp/lib/src/ftp_storage_driver.dart"
void registerFtpStorage(BeakStorageRegistry registry) {
  registry.register('ftp', FtpStorageDriver.fromConfig);
}
```

## Registering the driver

Beak's server depends on no driver package, on purpose: pulling
`beak_storage_s3` in from the framework would put `minio` in the dependency
graph of every backend, uploading or not. So a project declares the drivers it
wants, in one place.

Add a `beakStorageRegistry` function to `lib/server.dart` (`beak eject server`
writes the starter). `beak prepare` notices it and hands it to the generated
host:

```dart title="examples/embedded/lib/server.dart"
/// The storage drivers this app can resolve.
///
/// `beak_backend` depends on no driver package on purpose, so an app that
/// uploads to S3 declares `beak_storage_s3` and registers it here. Set
/// `BEAK_STORAGE_DRIVER=s3` and the rest of the `BEAK_S3_*` variables, and
/// every upload column stores there instead of on local disk.
BeakStorageRegistry beakStorageRegistry() {
  final registry = createDefaultStorageRegistry();
  registerS3Storage(registry);
  return registry;
}
```

`createDefaultStorageRegistry()` gives you `memory` and `local`; each
`register<Name>Storage` call adds one more. Register yours the same way, either
through your package's own function or with a bare
`registry.register(id, factory)` for the config id it serves.

### Selecting it at runtime

Which registered driver is actually used comes from the environment.
`BEAK_STORAGE_DRIVER` names it, and each driver reads its own variables:

| `BEAK_STORAGE_DRIVER` | Also reads |
| --- | --- |
| unset or empty | nothing (uploads fall back to local disk under `storage/uploads`, served at `/uploads`) |
| `none` | nothing (uploads are disabled outright) |
| `memory` | nothing |
| `local` | `BEAK_LOCAL_ROOT_DIR`, `BEAK_LOCAL_PUBLIC_BASE_URL` |
| `s3` | `BEAK_S3_ENDPOINT`, `BEAK_S3_BUCKET`, `BEAK_S3_ACCESS_KEY`, `BEAK_S3_SECRET_KEY`, `BEAK_S3_REGION`, optional `BEAK_S3_USE_PATH_STYLE` |
| `ftp` | `BEAK_FTP_HOST`, `BEAK_FTP_USER`, `BEAK_FTP_PASSWORD`, `BEAK_FTP_BASE_DIR`, `BEAK_FTP_PUBLIC_BASE_URL`, optional `BEAK_FTP_PORT` |

A driver selected but never registered fails at boot with a
`BeakConfigurationException` naming it, rather than at the first upload. A
driver whose settings are not purely environment variables is still usable:
register it, build its config yourself, and pass the resolved driver to the
server.

!!! danger "Storage credentials are secrets"
    `BEAK_S3_SECRET_KEY` and `BEAK_FTP_PASSWORD` belong in the environment, not
    in a commit. Beak reads the real process environment first and an optional
    git-ignored `.env` second, so a deployment can set them without a file. See
    [Environment and config](../deployment/environment-and-config.md).

## Where your config lives

`BeakStorageConfig` is a **sealed** family, so a config carries a `driverId` and
the settings its driver needs, and every factory can match it exhaustively.
Sealed also means the subtypes live in `beak_core`, next to the base class: even
`BeakFtpConfig` and `BeakS3Config` sit there, as part-files of
`beak_storage_config.dart`, while their drivers ship in their own packages. That
is what lets an app select S3 without importing `beak_storage_s3`.

So a genuinely new backend comes in two parts, and the config half belongs
upstream: a `BeakStorageConfig` subtype (its settings and `driverId`) in
`beak_core`, and a driver package implementing `BeakStorageDriver` and exposing a
`register<Name>Storage` function, exactly as `beak_storage_ftp` and
`beak_storage_s3` are laid out. The [contributing
guide](../contributing/writing-a-storage-driver.md) walks that split in detail.

Once registered, the server resolves your driver at startup and hands it to the
upload service. Nothing else changes: file columns, validation, and the upload
route already speak `BeakStorageDriver`.

## Continue reading

- [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md) the validate-transform-store pipeline your driver's `put` sits at the end of.
- [Files and storage columns](../models/files-and-storage-columns.md) the `@Image` and `@FileField` annotations that produce the uploads.
- [Writing a storage driver](../contributing/writing-a-storage-driver.md) the config-plus-package split for contributing a driver upstream.
- [Custom data sources](custom-data-sources.md) the same pluggable pattern for records instead of files.
