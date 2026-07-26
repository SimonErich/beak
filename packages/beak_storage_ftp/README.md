# beak_storage_ftp

FTP storage driver for Beak's storage abstraction.

Part of [**Beak**](https://github.com/SimonErich/beak), a low-code,
configuration-driven admin-panel framework for Dart/Flutter. See the
[architecture guide](../../docs/architecture.md) for how the packages fit
together.

## What it is

Plugs an FTP-backed driver into `beak_core`'s storage layer. Server-side Dart,
depending only on `beak_core` and `dart:io`. Call `registerFtpStorage` once at
startup so a `BeakStorageRegistry` resolves any `BeakFtpConfig` to an
`FtpStorageDriver`; the driver validates keys and wraps every transport failure
in a `BeakStorageException`. Because FTP has no expiring links, stored files are
served from a configured public base URL (an HTTP server is expected to front
the FTP directory). `FtpTransport` is the wire seam — production uses
`SocketFtpTransport`, tests substitute a fake.

## Usage

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

Inject a fake transport to unit-test driver behavior without a live server:

```dart
final driver = FtpStorageDriver(config, transport: FakeFtpTransport());
```

## Key types

- `FtpStorageDriver` — the `BeakStorageDriver`; `put`/`get`/`delete`/`url`/
  `exists` over FTP.
- `registerFtpStorage` — registers the driver factory under `'ftp'` on a
  `BeakStorageRegistry`.
- `FtpTransport` — the wire seam the driver speaks through.
- `SocketFtpTransport` — the production `dart:io` RFC 959 client (passive,
  binary mode).
- `FtpProtocolException` — carries the FTP reply code (e.g. `550` for a
  missing file).

## Status

Pre-1.0, part of the Beak monorepo. Consumed by the
[reference admin](../../apps/reference_admin). Contributions welcome — see
[CONTRIBUTING](../../CONTRIBUTING.md) at the repo root.

## License

Apache-2.0 © Marqably GmbH. See [LICENSE](LICENSE).
