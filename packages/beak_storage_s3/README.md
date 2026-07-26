# beak_storage_s3

S3/MinIO storage driver for Beak's storage abstraction.

Part of [**Beak**](https://github.com/SimonErich/beak), a low-code,
configuration-driven admin-panel framework for Dart/Flutter. See the
[architecture guide](../../docs/architecture.md) for how the packages fit
together.

## What it is

A pluggable storage driver that plugs an S3-compatible backend (AWS S3, MinIO,
...) into `beak_core`'s source-agnostic storage layer. Pure server-side Dart;
it depends on `beak_core` and `package:minio` for the wire protocol, and
nothing is hard-wired into core. Register it once with [registerS3Storage] and
a `BeakStorageRegistry` resolves any `BeakS3Config` to an [S3StorageDriver],
which implements `beak_core`'s `BeakStorageDriver` (`put`/`get`/`delete`/`url`/
`exists`).

## Usage

```dart
import 'package:beak_core/beak_core.dart';
import 'package:beak_storage_s3/beak_storage_s3.dart';

final registry = BeakStorageRegistry();
registerS3Storage(registry);

final driver = registry.resolve(BeakS3Config(
  endpoint: Uri.parse('http://localhost:29000'),
  bucket: 'uploads',
  accessKey: 'minioadmin',
  secretKey: 'minioadmin',
  region: 'us-east-1',
  usePathStyle: true, // MinIO requires path-style addressing
));

final stored = await driver.put(upload, path: 'products');
final signed = await driver.url(stored.key, expiresIn: Duration(hours: 1));
```

Inject a fake [S3ObjectClient] to unit-test driver behavior without a live
bucket:

```dart
final driver = S3StorageDriver(config, client: FakeS3ObjectClient());
```

## Key types

- `S3StorageDriver` — the `BeakStorageDriver` that stores files in an S3 bucket.
- `registerS3Storage` — registers the driver factory under `'s3'` in a registry.
- `S3ObjectClient` — the wire seam the driver speaks through; swap for a fake.
- `MinioS3ObjectClient` — the production client, backed by `package:minio`.

`BeakS3Config`, `BeakStorageRegistry`, `BeakStoredFile`, `BeakUpload`, and
`BeakStorageException` come from `beak_core`.

## Status

Pre-1.0, part of the Beak monorepo. Consumed by the
[reference admin](../../apps/reference_admin). Contributions welcome — see
[CONTRIBUTING](../../CONTRIBUTING.md) at the repo root.

## License

Apache-2.0 © Marqably GmbH. See [LICENSE](LICENSE).
