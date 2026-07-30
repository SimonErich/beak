---
title: Writing a storage driver
description: Add a new file-storage backend by implementing BeakStorageDriver behind a transport seam, registering its factory, and testing it against a fake.
---

# Writing a storage driver

After this page you can add a new storage backend (say, Azure Blob or GCS) as its
own package: implement one interface, split the wire protocol behind a testable
seam, register a factory, and cover it with fast unit tests that never open a
socket. The shipped `beak_storage_ftp` and `beak_storage_s3` packages are the
templates, and this page walks the FTP one because it is the smaller of the two.

## The interface you implement

`beak_core` defines the seam. A driver is five methods over string keys:

```dart title="packages/beak_core/lib/src/storage/beak_storage_driver.dart"
abstract interface class BeakStorageDriver {
  /// Stable driver identifier matching `BeakStorageConfig.driverId`
  /// (`'s3'`, `'ftp'`, `'memory'`, `'local'`).
  String get id;

  /// Stores [upload] under the [path] prefix and returns its description.
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

The other half is the config. `BeakStorageConfig` is sealed, so its subtypes live
in `beak_core` as part-files of `beak_storage_config.dart`: `BeakFtpConfig` and
`BeakS3Config` are both there, even though their drivers are separate packages.
Add yours beside them, with its settings and a `driverId`. That split is what
lets an app configure your backend without depending on your package.

Keys are relative, `/`-separated paths. `beak_core` ships `BeakStorageKeys` with
`join`, `validate`, and `appendToBaseUrl` so you never build a key or a public
URL by hand, and so path-traversal (`../evil.png`) is rejected in one place. The
contract every driver honors: a malformed key throws `BeakStorageException`, and
so do `get` and `delete` on a missing file; `exists` returns `false` and `url`
builds an address without touching storage.

## Split logic from transport

Do not talk to the network from the driver. Put the wire protocol behind a thin
seam so the driver's logic (key building, error mapping, URL shaping) stays
unit-testable against a fake. FTP calls that seam an `FtpTransport`:

```dart title="packages/beak_storage_ftp/lib/src/ftp_transport.dart"
--8<-- "packages/beak_storage_ftp/lib/src/ftp_transport.dart:FtpTransport"
```

The S3 package does the same with an `S3ObjectClient`. The production
implementation (`SocketFtpTransport`, `MinioS3ObjectClient`) is the only piece
that opens a connection; everything else runs in memory in tests.

## The driver

The driver takes its config and an *injectable* transport that defaults to the
production one. Tests pass their own; app code never does.

```dart title="packages/beak_storage_ftp/lib/src/ftp_storage_driver.dart"
final class FtpStorageDriver implements BeakStorageDriver {
  /// Creates a driver for [config]; [transport] overrides the wire transport
  /// for tests (default: a [SocketFtpTransport] built from [config]).
  FtpStorageDriver(BeakFtpConfig config, {FtpTransport? transport})
    : _config = config,
      _transport = transport ?? SocketFtpTransport(config);
```

Add a `fromConfig` factory whose signature matches the registry. It narrows the
sealed `BeakStorageConfig` with a `switch` and throws `BeakConfigurationException`
for a foreign config type, so a misconfiguration fails loudly at startup:

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

Each method builds the key with `BeakStorageKeys`, runs the transport call, and
returns a typed `BeakStoredFile`. `put` is the shape of all of them:

```dart title="packages/beak_storage_ftp/lib/src/ftp_storage_driver.dart"
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
```

## Guard every operation

Wrap every transport call so no raw error crosses the driver boundary. Rethrow
Beak's own exceptions untouched, translate the transport's known failures (here,
a `550` reply means "missing file"), and wrap anything else in a
`BeakStorageException`:

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

This is the [typed-exceptions convention](conventions.md#typed-exceptions) at the
storage boundary: the caller only ever sees a `BeakStorageException`, never a
socket error or protocol reply code.

## Register the factory

Expose a `register…Storage` function that wires the factory into a
`BeakStorageRegistry` under the driver id. The registry pre-registers the
web-safe `memory` driver, and `beak_backend`'s `createDefaultStorageRegistry`
adds `local`; your package adds one line:

```dart title="packages/beak_storage_ftp/lib/src/ftp_storage_driver.dart"
--8<-- "packages/beak_storage_ftp/lib/src/ftp_storage_driver.dart:registerFtpStorage"
```

At app init the backend calls your register function once, then `resolve`s
whichever config it was handed:

```dart
final registry = createDefaultStorageRegistry();
registerFtpStorage(registry); // from your package

// Later, build the driver the config selects:
final BeakStorageDriver driver = registry.resolve(
  BeakFtpConfig(
    host: 'ftp.example.com',
    user: 'beak',
    password: password,
    baseDir: '/srv/uploads',
    publicBaseUrl: Uri.parse('https://static.example.com/uploads'),
  ),
);
```

`register` throws if the id is already taken, and `resolve` throws a
`BeakConfigurationException` listing the registered drivers when a config's
`driverId` has no factory, so a missing registration is a clear startup error
rather than a null later on.

## Test against a fake

Because the transport is injectable, the whole driver is testable in memory. The
fake records every call and holds files in a map, with a `failure` knob to force
error paths:

```dart title="packages/beak_storage_ftp/test/ftp_storage_driver_test.dart"
final class FakeFtpTransport implements FtpTransport {
  final Map<String, Uint8List> files = {};
  final List<String> calls = [];

  /// When set, every method throws this error instead of executing.
  Object? failure;

  void _record(String call) {
    calls.add(call);
    final Object? error = failure;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> store(String key, Uint8List bytes) async {
    _record('store $key');
    files[key] = bytes;
  }

  @override
  Future<Uint8List> retrieve(String key) async {
    _record('retrieve $key');
    final Uint8List? bytes = files[key];
    if (bytes == null) {
      throw const FtpProtocolException(550, 'File not found');
    }
    return bytes;
  }
  // ...remove and exists, the same shape...
}
```

Wire it in `setUp`, then assert both the happy path and the failure mapping:

```dart title="packages/beak_storage_ftp/test/ftp_storage_driver_test.dart"
setUp(() {
  transport = FakeFtpTransport();
  driver = FtpStorageDriver(config, transport: transport);
});
// ...the groups the tests sit in...
test('stores under path/filename and describes the file', () async {
  final stored = await driver.put(upload, path: 'products');
  expect(transport.calls, ['store products/photo.png']);
  expect(transport.files['products/photo.png'], upload.bytes);
  expect(stored.key, 'products/photo.png');
  expect(stored.sizeInBytes, 3);
  expect(stored.mimeType, 'image/png');
  expect(
    stored.url,
    Uri.parse('https://static.example.com/uploads/products/photo.png'),
  );
});

test(
  'rejects traversal filenames before touching the transport',
  () async {
    final evil = BeakUpload(
      filename: '../evil.png',
      mimeType: 'image/png',
      bytes: Uint8List.fromList([1]),
    );
    await expectLater(
      driver.put(evil, path: 'products'),
      throwsA(isA<BeakStorageException>()),
    );
    expect(transport.calls, isEmpty);
  },
);
```

Cover the registration too, so a config resolves to your driver and the factory
rejects foreign configs:

```dart title="packages/beak_storage_ftp/test/ftp_storage_driver_test.dart"
test('registers a factory the registry resolves for BeakFtpConfig', () {
  final registry = BeakStorageRegistry();
  registerFtpStorage(registry);
  expect(registry.driverIds, contains('ftp'));
  expect(registry.resolve(config), isA<FtpStorageDriver>());
});
```

Keep the real socket or S3 path in a separate `test/integration/` file, tagged so
it skips when the service is down. The unit suite above needs neither Docker nor
a network.

## Which template to copy

| Package            | Best for                                              |
| ------------------ | ----------------------------------------------------- |
| `beak_storage_ftp` | the cleanest reference: a small transport, no SDK      |
| `beak_storage_s3`  | a production driver over an SDK, with presigned URLs   |

Start from `beak_storage_ftp` for the structure (seam, driver, factory, fake).
Reach for `beak_storage_s3` when your backend has expiring links or a real client
library to wrap. Both are one `lib/src/*_driver.dart`, one `*_transport`/`client`
seam, and one test file, so a new driver is a small, self-contained package.

## Continue reading

- [Files and storage columns](../models/files-and-storage-columns.md) how columns declare storage and rules.
- [Custom storage drivers](../extending/custom-storage-drivers.md) the same seam from an app author's side.
- [Writing tests](writing-tests.md) the fake-over-mock pattern across packages.
- [Conventions](conventions.md) typed exceptions and reuse-first.
