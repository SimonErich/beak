---
title: Custom storage drivers
description: Implement BeakStorageDriver, keep its wire behind a testable seam like the S3 and FTP drivers, and make your server use it.
type: guide
audience: [expert, contributor]
status: stable
---

# Custom storage drivers

After this page you can implement `BeakStorageDriver`, keep its wire protocol behind a seam you can test without a server, and make your Beak server store uploads through it.

Storage is pluggable for the same reason data is. `memory` and `local` ship in the box, `beak_storage_s3` and `beak_storage_ftp` are separate packages, and file columns only ever talk to the `BeakStorageDriver` interface. Your driver is one more implementation of it.

One limit shapes the rest of the page. The `BEAK_STORAGE_DRIVER` switch knows only the drivers that ship with Beak, because `BeakStorageConfig` is a sealed class that lives in `beak_core`. A driver of your own is therefore selected in code, with no environment variable. A driver contributed to Beak gets the environment switch too. [Register the driver](#register-the-driver) has both routes.

## At a glance

A driver is an id and five methods over one relative, `/`-separated key:

```dart title="packages/beak_core/lib/src/storage/beak_storage_driver.dart"
--8<-- "packages/beak_core/lib/src/storage/beak_storage_driver.dart:BeakStorageDriver"
```

| Member | Returns | The contract |
| --- | --- | --- |
| `id` | `String` | Matches the `driverId` of the config that selects the driver. |
| `put` | `BeakStoredFile` | The key is `path/filename`. Overwrite an existing key. |
| `get` | `Uint8List` | Throw `BeakStorageException` when the key is absent. |
| `delete` | nothing | Throw `BeakStorageException` when the key is absent. |
| `url` | `Uri` | Build the address without probing storage. Honour `expiresIn` only if the backend can. |
| `exists` | `bool` | Return `false` for an absent key. Never throw for absence. |

| Your goal | Route | Where |
| --- | --- | --- |
| Use a driver of your own in your app | Construct it in `beakServer` and pass it as `storage:` | `lib/server.dart` |
| Use a shipped driver package (S3, FTP) | Register it in `beakStorageRegistry()`, select it with `BEAK_STORAGE_DRIVER` | `lib/server.dart` and the environment |
| Add a driver to Beak itself | A config class, an environment case and a `beak_storage_<name>` package | `beak_core`, `beak_backend`, a new package |

## What the server calls

The upload service is the only caller. It validates the upload, runs image transforms, mints the filename itself, and then talks to your driver:

| Moment | Calls |
| --- | --- |
| A file or image is uploaded | `put(upload, path: column.storagePath)`, once for the file and once per image variant. |
| A variant write fails | `delete(key)` for every key already written, errors swallowed. |
| A client asks for a stored file's URL, or removes it | `exists(key)`, and only if that is `true`, `url(key)` or `delete(key)`. |

Three consequences follow. The filename `put` receives is minted by Beak (a generated id plus an extension), not the client's name. `delete` and `url` are never called for an absent key by the upload service, though the interface still says what to do. And nothing in the generated API calls `get` today: it is on the interface for your own code and for tests.

Keys are validated, relative paths. Use `BeakStorageKeys.join` (which validates), `BeakStorageKeys.validate` and `BeakStorageKeys.appendToBaseUrl`, and throw `BeakStorageException` for a malformed key or a missing file, so no raw protocol error escapes.

## The smallest driver

`BeakMemoryStorageDriver` is the whole interface over a map, and the shortest driver to read:

```dart title="packages/beak_core/lib/src/storage/drivers/beak_memory_storage_driver.dart"
--8<-- "packages/beak_core/lib/src/storage/drivers/beak_memory_storage_driver.dart:memoryDriverMembers"
```

Note where validation happens. `put` validates through `BeakStorageKeys.join`. Every other method calls `BeakStorageKeys.validate(key)` first.

## Keep the wire behind a seam

A driver that speaks a protocol should not open a socket inside its methods. `FtpStorageDriver` talks to an `FtpTransport`, four methods a fake can implement, and holds only the logic that is worth testing: key handling, error mapping, URL building.

```dart title="packages/beak_storage_ftp/lib/src/ftp_transport.dart"
--8<-- "packages/beak_storage_ftp/lib/src/ftp_transport.dart:FtpTransport"
```

The production `SocketFtpTransport` speaks RFC 959 over `dart:io`. A test injects its own through the driver's `transport` parameter. `beak_storage_s3` does the same: `S3StorageDriver` over an `S3ObjectClient`, with `MinioS3ObjectClient` in production.

```dart title="packages/beak_storage_ftp/lib/src/ftp_storage_driver.dart"
--8<-- "packages/beak_storage_ftp/lib/src/ftp_storage_driver.dart:ftpDriverPut"
```

The `_guard` helper is the boundary rule in code. It rethrows Beak's own exceptions untouched and wraps everything else in a `BeakStorageException`. A `550` reply means "missing" only for operations on files that should already exist, so a permission failure on `put` never claims the file is absent:

```dart title="packages/beak_storage_ftp/lib/src/ftp_storage_driver.dart"
--8<-- "packages/beak_storage_ftp/lib/src/ftp_storage_driver.dart:ftpDriverGuard"
```

The wire's semantics rarely match the interface's. S3 deletes are idempotent, so `S3StorageDriver.delete` asks `objectExists` first and throws when nothing is there. Read your protocol's edge cases against the table above before you call it done.

## Register the driver

=== "Your own driver, in your app"

    `BeakServerDefaults.build()` has no `storage:` parameter, so a driver that is not in the registry is passed by constructing the server in `lib/server.dart` (`beak eject server` writes the starter):

    ```dart title="lib/server.dart"
    import 'package:beak/server.dart';

    BeakServer beakServer(BeakServerDefaults defaults) => BeakServer(
      config: defaults.config,
      registry: defaults.registry,
      dataSource: defaults.dataSource,
      storage: MyStorageDriver(),
      now: defaults.now,
    );
    ```

    `MyStorageDriver` is your class implementing `BeakStorageDriver`. The block is illustrative (it is not a repository file) and compiles against a fresh `beak create` project. Every upload column now stores through it, whatever `BEAK_STORAGE_DRIVER` says. Every argument `build()` takes (`policy`, `authSessions`, `middleware`, `routes`, `outbox` and the rest) is also a `BeakServer` argument, so pass the ones your project uses the same way.

=== "A shipped driver package"

    `beak_backend` depends on no driver package, on purpose: pulling `beak_storage_s3` in would put `minio` in the dependency graph of every backend, uploading or not. So a project declares the packages it uses, in one function. Add the dependency to `pubspec.yaml`, then declare `beakStorageRegistry` in `lib/server.dart`. The file does not need a `beakServer` function for this:

    ```dart title="lib/server.dart"
    import 'package:beak/server.dart';
    import 'package:beak_storage_ftp/beak_storage_ftp.dart';

    /// The storage drivers this app can resolve.
    BeakStorageRegistry beakStorageRegistry() {
      final registry = createDefaultStorageRegistry();
      registerFtpStorage(registry);
      return registry;
    }
    ```

    `beak prepare` finds the function and hands it to the generated host (`storageRegistry: server.beakStorageRegistry`). This file compiles against a fresh `beak create` project with `beak_storage_ftp` added to `pubspec.yaml`. To see which driver the environment selects, resolve it the way `serve()` does, from a throwaway file of your own:

    ```dart title="bin/probe.dart"
    import 'package:my_app/beak/server.g.dart';

    void main() => print(beakHost().resolveStorageDriver()?.id);
    ```

    ```console
    $ BEAK_STORAGE_DRIVER=ftp BEAK_FTP_HOST=ftp.example.com BEAK_FTP_USER=beak \
        BEAK_FTP_PASSWORD=secret BEAK_FTP_BASE_DIR=/srv/uploads \
        BEAK_FTP_PUBLIC_BASE_URL=https://cdn.example.com/uploads \
        dart run bin/probe.dart
    ftp
    ```

`createDefaultStorageRegistry()` gives you `memory` and `local`. Each `register<Name>Storage` call adds one more, and registering an id twice throws.

### Select it with the environment

`BEAK_STORAGE_DRIVER` names the driver and each driver reads its own variables:

| `BEAK_STORAGE_DRIVER` | Also reads |
| --- | --- |
| unset or empty | nothing: uploads fall back to local disk under `storage/uploads`, served at `/uploads` |
| `none` | nothing: uploads are disabled |
| `memory` | nothing |
| `local` | `BEAK_LOCAL_ROOT_DIR`, `BEAK_LOCAL_PUBLIC_BASE_URL` |
| `s3` | `BEAK_S3_ENDPOINT`, `BEAK_S3_BUCKET`, `BEAK_S3_ACCESS_KEY`, `BEAK_S3_SECRET_KEY`, `BEAK_S3_REGION`, optional `BEAK_S3_USE_PATH_STYLE` |
| `ftp` | `BEAK_FTP_HOST`, `BEAK_FTP_USER`, `BEAK_FTP_PASSWORD`, `BEAK_FTP_BASE_DIR`, `BEAK_FTP_PUBLIC_BASE_URL`, optional `BEAK_FTP_PORT` |

```dart title="packages/beak_backend/lib/src/server/beak_storage_settings.dart"
--8<-- "packages/beak_backend/lib/src/server/beak_storage_settings.dart:supportedDrivers"
```

Both misconfigurations fail at boot, naming the problem, and not at the first upload:

```console
No storage driver is registered for "s3". Registered drivers: memory, local, ftp.
Unsupported BEAK_STORAGE_DRIVER "gcs" — use one of s3, ftp, memory, local, none.
```

!!! danger "Storage credentials are secrets"
    `BEAK_S3_SECRET_KEY` and `BEAK_FTP_PASSWORD` belong in the environment, not in a commit. Beak reads the real process environment first and an optional git-ignored `.env` second. See [Environment and config](../shipping/environment-and-config.md).

## Contribute a driver to Beak

A new backend that ships with Beak comes in three parts, laid out exactly as FTP and S3 are:

1. **A config class in `beak_core`.** `BeakStorageConfig` is sealed, so its subtypes live next to it as part files, even for drivers whose code ships elsewhere. The config carries a `driverId`, the settings, and redacts secrets in `toString`.

    ```dart title="packages/beak_core/lib/src/storage/drivers/beak_ftp_config.dart"
    --8<-- "packages/beak_core/lib/src/storage/drivers/beak_ftp_config.dart:BeakFtpConfig"
    ```

2. **An environment case in `beak_backend`.** `BeakStorageSettings.fromEnv` builds the config from variables and `supportedDrivers` lists the id. A driver without a case here cannot be selected by environment.
3. **A package `beak_storage_<name>`** depending on `beak_core` and whatever client library the wire needs, with the driver, its transport seam, and a one-line registration function. The factory narrows the sealed config by pattern matching and throws `BeakConfigurationException` for a foreign one, so the id and the config type stay in lockstep:

    ```dart title="packages/beak_storage_ftp/lib/src/ftp_storage_driver.dart"
    --8<-- "packages/beak_storage_ftp/lib/src/ftp_storage_driver.dart:ftpDriverFromConfig"
    ```

    ```dart title="packages/beak_storage_ftp/lib/src/ftp_storage_driver.dart"
    --8<-- "packages/beak_storage_ftp/lib/src/ftp_storage_driver.dart:registerFtpStorage"
    ```

Then document the variables in [Configuration and environment](../reference/configuration.md) and list the package in [Packages](../reference/packages.md).

## Rules and limits

| Rule | Enforced where | What it means |
| --- | --- | --- |
| `BeakStorageConfig` is sealed | Compiler | An app cannot add a config subtype, so a driver of your own has no config class and is passed as an instance. |
| Environment selection covers five ids | Server boot | `s3`, `ftp`, `memory`, `local`, `none`. Any other value throws `Unsupported BEAK_STORAGE_DRIVER`. |
| A selected driver must be registered | Server boot | A missing `registerS3Storage` fails at boot by name, listing the registered ids. |
| Unset means local disk | Server boot | Uploads work on a fresh project. `none` turns the endpoints off. |
| Driver ids are unique | Registry | `register` throws `A storage driver factory for "<id>" is already registered.` |
| Only Beak types cross the boundary | You | Throw `BeakStorageException`, never a socket, `minio` or FTP error. The generated API turns the sealed `BeakException` family into HTTP responses and nothing else. |
| The server never calls `get` | Server | Implement it anyway. Your own code and tests will. |
| Requests overlap | You | Shelf serves requests concurrently, so keep no per-request state on the driver. `SocketFtpTransport` opens one connection per operation and pools nothing. |

## Verify it

Beak has no shared storage-driver contract suite (the data-source one is `runBeakDataSourceContract`). Test a driver the way the FTP driver is tested: inject a fake transport and assert what reaches it, what comes back, and which exception a failure becomes.

```dart title="packages/beak_storage_ftp/test/ftp_storage_driver_test.dart"
--8<-- "packages/beak_storage_ftp/test/ftp_storage_driver_test.dart:FakeFtpTransport"
```

```dart title="packages/beak_storage_ftp/test/ftp_storage_driver_test.dart"
--8<-- "packages/beak_storage_ftp/test/ftp_storage_driver_test.dart:ftpDriverGetTests"
```

Cover at least these cases for a new driver: a malformed key is rejected before the transport is touched, a missing key becomes `BeakStorageException` on `get` and `delete`, `exists` returns `false` and does not throw, an unrelated transport failure does not claim the file is missing, and `fromConfig` rejects another driver's config.

```console
$ cd packages/beak_storage_ftp
$ dart test test/ftp_storage_driver_test.dart
00:00 +16: registerFtpStorage the factory rejects foreign configs
00:00 +17: All tests passed!
```

Then boot the real host with the environment set and check `resolveStorageDriver()`, as the probe above does. A driver that passes its unit tests and was never registered fails there.

## Reference

| Symbol | Library | Role |
| --- | --- | --- |
| `BeakStorageDriver` | `package:beak/beak.dart` | The interface. |
| `BeakStorageConfig`, `BeakS3Config`, `BeakFtpConfig`, `BeakLocalDiskStorageConfig`, `BeakMemoryStorageConfig` | `package:beak/beak.dart` | The sealed configs. |
| `BeakStorageRegistry` | `package:beak/beak.dart` | `register(id, factory)`, `resolve(config)`, `driverIds`. |
| `BeakStorageKeys` | `package:beak/beak.dart` | `join`, `validate`, `appendToBaseUrl`. |
| `BeakUpload`, `BeakStoredFile` | `package:beak/beak.dart` | What goes in and what comes back. |
| `createDefaultStorageRegistry()`, `resolveStorage`, `BeakStorageSettings` | `package:beak/server.dart` | Server-side wiring. |
| `registerFtpStorage`, `registerS3Storage` | `beak_storage_ftp`, `beak_storage_s3` | Driver registration. |

Sources: `packages/beak_core/lib/src/storage/`, `packages/beak_backend/lib/src/server/storage_wiring.dart`, `packages/beak_backend/lib/src/server/beak_storage_settings.dart`, `packages/beak_storage_ftp/lib/src/`, `packages/beak_storage_s3/lib/src/`.

## Continue reading

- [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md) the validate, transform and store pipeline your `put` sits at the end of.
- [Files and storage columns](../models/files-and-storage-columns.md) the `@Image` and `@FileField` annotations that produce uploads.
- [Storage internals](../architecture/storage-internals.md) how the registry, configs and drivers fit together.
- [Custom data sources](custom-data-sources.md) the same pluggable pattern for records instead of files.
