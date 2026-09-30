# beak_storage_ftp

The storage driver that keeps Beak's uploads on an FTP server, for the hosting
plans where FTP is what you get. It is also the worked example of writing a
storage driver: two small files, one seam.

Part of [Beak](https://github.com/SimonErich/beak), a configuration-driven
admin-panel framework for Dart and Flutter. Pure Dart, server side only, and
its only dependency is `beak_core`.

## Use it in an app

Three steps: depend on the package, register the driver, pick it with
environment variables.

**1. Depend on it.** `beak_backend` depends on no driver package, so a server
that uploads to local disk carries none of them:

```yaml
dependencies:
  beak_storage_ftp:
    git:
      url: https://github.com/SimonErich/beak.git
      ref: v0.9.0
      path: packages/beak_storage_ftp
```

Until the `v0.9.0` tag exists, use `path:` to a checkout or another `ref:`.

**2. Register the driver** in `lib/server.dart`. `beak prepare` finds
`beakStorageRegistry()` and hands it to the generated server host; the file
needs no `beakServer` function for this. This block is illustrative, and every
name in it is real:

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

`registerFtpStorage` is one line:

```dart title="packages/beak_storage_ftp/lib/src/ftp_storage_driver.dart"
void registerFtpStorage(BeakStorageRegistry registry) {
  registry.register('ftp', FtpStorageDriver.fromConfig);
}
```

**3. Select it** in `.env` or the process environment. `BEAK_STORAGE_DRIVER=ftp`
requires the first five variables below, and a missing one fails at boot with
its name. Selecting `ftp` without step 2 fails at boot too, and names the
registered drivers (`No storage driver is registered for "ftp". Registered
drivers: memory, local.`).

| Variable | Meaning |
| --- | --- |
| `BEAK_FTP_HOST` | The FTP server. |
| `BEAK_FTP_USER`, `BEAK_FTP_PASSWORD` | The login. |
| `BEAK_FTP_BASE_DIR` | The remote directory uploads live under, such as `/var/www/uploads`. |
| `BEAK_FTP_PUBLIC_BASE_URL` | Where those files are served from over HTTP, such as `https://cdn.example.com/uploads`. |
| `BEAK_FTP_PORT` | Optional. Defaults to `21`; a value that is not an integer also gives `21`. |

## Why there is a public base URL

FTP cannot mint a link that expires, and it does not serve files over HTTP. So
the driver stores through FTP and builds every URL from `publicBaseUrl`: some
web server has to sit in front of the FTP directory and serve it at that address.
`url(key, expiresIn: ...)` accepts the argument and ignores it.

## Use it on its own

```dart
import 'package:beak_core/beak_core.dart';
import 'package:beak_storage_ftp/beak_storage_ftp.dart';

final registry = BeakStorageRegistry();
registerFtpStorage(registry);

final driver = registry.resolve(BeakFtpConfig(
  host: 'ftp.example.com',
  user: 'uploads',
  password: '...',
  baseDir: '/var/www/uploads',
  publicBaseUrl: Uri.parse('https://cdn.example.com/uploads'),
));

final stored = await driver.put(upload, path: 'products');
final publicUrl = await driver.url(stored.key);
```

`BeakFtpConfig`, `BeakStorageRegistry`, `BeakUpload`, `BeakStoredFile` and
`BeakStorageException` come from `beak_core`.

## What the driver does

| Call | Behavior |
| --- | --- |
| `put(upload, path:)` | Creates the base directory and the key's parent directories, then stores the bytes under `path/filename`. Returns a `BeakStoredFile` with the public URL. |
| `get(key)` | Returns the bytes. |
| `delete(key)` | Removes the file. |
| `url(key)` | `publicBaseUrl` plus the key. |
| `exists(key)` | Asks the server for the file's `SIZE`. |

A `550` reply on `get` or `delete` becomes `No file is stored under "<key>"`.
Every other failure, protocol or socket, is a `BeakStorageException` that names
the operation, the key and the reply code, so no raw exception crosses the
driver. Keys are validated before anything touches the network.

## Test against a fake

`FtpTransport` is the wire seam: `store`, `retrieve`, `remove` and `exists`.
`SocketFtpTransport` is the production client, a small RFC 959 implementation over
`dart:io` sockets. Tests substitute their own transport, and a missing key should
throw `FtpProtocolException(550, ...)`:

```dart
final driver = FtpStorageDriver(config, transport: FakeFtpTransport());
```

The suite in this package does that, and also runs `SocketFtpTransport` against
a small in-process FTP server (`test/support/mini_ftp_server.dart`), so it needs
no Docker.

## Limits

- **Plain FTP.** The client opens ordinary sockets. There is no FTPS and no
  SFTP, so the password and the files cross the network unencrypted. Use it on a
  network you trust, or write an SFTP transport behind `FtpTransport`.
- **One connection per operation.** Each call connects, logs in, switches to
  binary mode, does its work and disconnects. That is simple and slow under load;
  there is no pooling.
- **Passive mode with `PASV` only.** There is no `EPSV`. The client connects the
  data socket to the configured host instead of trusting the address in the
  reply, which keeps it working behind NAT.
- **`exists` needs `SIZE`.** A server that answers it with anything but `213` or
  `550` makes `exists` fail.
- **No signed URLs.** See above; the files are as public as the web server in
  front of them.

## Continue reading

- [Custom storage drivers](https://simonerich.github.io/beak/extending/custom-storage-drivers/): registering a shipped driver and writing your own.
- [Files and storage columns](https://simonerich.github.io/beak/models/files-and-storage-columns/): the columns that upload through a driver.
- [Environment and config](https://simonerich.github.io/beak/shipping/environment-and-config/): every variable, including `BEAK_STORAGE_DRIVER`.
- [Storage internals](https://simonerich.github.io/beak/architecture/storage-internals/): how the registry resolves a config.

## Status

Pre-1.0 and versioned in lockstep with the other `beak_*` packages (0.9.0). Not on pub.dev yet: depend on it from git with `ref: v0.9.0` once that tag exists, or from a checkout with `path:`. What changed: the [root changelog](https://github.com/SimonErich/beak/blob/main/CHANGELOG.md). Contributing: [CONTRIBUTING.md](https://github.com/SimonErich/beak/blob/main/CONTRIBUTING.md).

## License

Apache-2.0 © Marqably GmbH. See [LICENSE](https://github.com/SimonErich/beak/blob/main/LICENSE).
