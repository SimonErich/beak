# beak_storage_s3

The storage driver that keeps Beak's uploads in an S3 bucket: AWS S3, MinIO or
anything else that speaks the S3 API. Without it, uploads go to a folder next to
the server, which is fine on a laptop and wrong behind a load balancer.

Part of [Beak](https://github.com/SimonErich/beak), a configuration-driven
admin-panel framework for Dart and Flutter. Pure Dart, server side only.

## Use it in an app

Three steps: depend on the package, register the driver, pick it with
environment variables.

**1. Depend on it.** `beak_backend` depends on no driver package on purpose, so
the `minio` client is not in the dependency graph of every Beak server. Add this
one next to `beak`:

```yaml
dependencies:
  beak_storage_s3:
    git:
      url: https://github.com/SimonErich/beak.git
      ref: v0.9.0
      path: packages/beak_storage_s3

dependency_overrides:
  xml: ^7.0.1
```

The override is needed today, see [Limits](#limits). Until the `v0.9.0` tag
exists, use `path:` to a checkout or another `ref:`.

**2. Register the driver** in `lib/server.dart`. `beak prepare` finds
`beakStorageRegistry()` and hands it to the generated server host; the file
needs no `beakServer` function for this. This block is illustrative, and every
name in it is real:

```dart title="lib/server.dart"
import 'package:beak/server.dart';
import 'package:beak_storage_s3/beak_storage_s3.dart';

/// The storage drivers this app can resolve.
BeakStorageRegistry beakStorageRegistry() {
  final registry = createDefaultStorageRegistry();
  registerS3Storage(registry);
  return registry;
}
```

`registerS3Storage` is one line:

```dart title="packages/beak_storage_s3/lib/src/s3_storage_driver.dart"
void registerS3Storage(BeakStorageRegistry registry) {
  registry.register('s3', S3StorageDriver.fromConfig);
}
```

**3. Select it** in `.env` or the process environment. `BEAK_STORAGE_DRIVER=s3`
requires the endpoint, bucket, access key, secret key and region, and a missing
one fails at boot with its name. `BEAK_S3_USE_PATH_STYLE` is optional and
defaults to virtual-host addressing:

```bash
BEAK_STORAGE_DRIVER=s3
BEAK_S3_ENDPOINT=http://localhost:29000
BEAK_S3_BUCKET=beak-uploads
BEAK_S3_ACCESS_KEY=beak
BEAK_S3_SECRET_KEY=beaksecret
BEAK_S3_REGION=us-east-1
BEAK_S3_USE_PATH_STYLE=true
```

Those are the values of `.env.example` in the Beak repository, which match the
MinIO in its `docker-compose.yml` (`melos run up`). Selecting `s3` without step 2
fails at boot and names the registered drivers:

```console
$ dart run bin/serve.dart
BeakConfigurationException(configuration): No storage driver is registered for "s3". Registered drivers: memory, local.
```

## Use it on its own

Every image and file column uploads through a `BeakStorageDriver`, and nothing
stops a script from using one directly:

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
  usePathStyle: true, // MinIO needs path-style addressing
));

final stored = await driver.put(upload, path: 'products');
final signed = await driver.url(stored.key, expiresIn: const Duration(hours: 1));
```

`BeakS3Config`, `BeakStorageRegistry`, `BeakUpload`, `BeakStoredFile` and
`BeakStorageException` come from `beak_core`.

## What the driver does

| Call | Behavior |
| --- | --- |
| `put(upload, path:)` | Stores the bytes under `path/filename` with the upload's content type and returns a `BeakStoredFile` (key, URL, size, MIME type). |
| `get(key)` | Returns the bytes. A missing object is a `BeakStorageException`. |
| `delete(key)` | Checks the object exists, then removes it. Deleting an absent file is an error, unlike S3's own idempotent delete. |
| `url(key)` | The public URL: `BeakS3Config.publicBaseUrl` when set (a CDN, say), else `endpoint/bucket/key` with `usePathStyle`, else `bucket.host/key`. |
| `url(key, expiresIn:)` | A presigned GET URL that expires. |
| `exists(key)` | Whether an object is stored under the key. |

Every key is validated, and every client or transport failure is wrapped in a
`BeakStorageException` (`S3 put failed for "products/a.png": ...`), so no raw S3
error crosses the driver.

## Test against a fake

`S3ObjectClient` is the wire seam: five methods (`putObject`, `getObject`,
`removeObject`, `objectExists`, `presignedGetUrl`). Production uses
`MinioS3ObjectClient`, tests substitute their own:

```dart
final driver = S3StorageDriver(config, client: FakeS3ObjectClient());
```

The suite in this package does that, and adds a live MinIO suite tagged `e2e`
(`melos run up`, then `melos run test-e2e`).

## Limits

- **`xml` version clash.** `minio 3.5.8` requires `xml ^6.4.2`, and `beak`
  reaches `image 4.9.1` (through `beak_image`), which requires `xml ^7.0.1`. A
  project that depends on both fails to resolve without the
  `dependency_overrides: xml: ^7.0.1` above. `beak_backend` carries the same
  override for its own MinIO suite, which runs the driver against xml 7 and
  passes.
- **Uploads never get a signed URL.** Beak's upload routes call `url(key)`
  without `expiresIn`, so a private bucket is not readable through them. Make
  the bucket readable, or set `BeakS3Config.publicBaseUrl` to something that
  serves it.
- **`publicBaseUrl` has no environment variable.** `BEAK_STORAGE_DRIVER=s3` reads
  the variables above and nothing else. A CDN in front of the bucket means
  building the `BeakS3Config` yourself.
- **Storage failures show the client's error.** A `BeakStorageException` answers
  `500` with its message as written, and this driver's message ends with the
  client's own error text, which can name the endpoint or the bucket.

## Continue reading

- [Files and storage columns](https://simonerich.github.io/beak/models/files-and-storage-columns/): the columns that upload through a driver.
- [Custom storage drivers](https://simonerich.github.io/beak/extending/custom-storage-drivers/): registering a shipped driver and writing your own.
- [Environment and config](https://simonerich.github.io/beak/shipping/environment-and-config/): every variable, including `BEAK_STORAGE_DRIVER`.
- [Storage internals](https://simonerich.github.io/beak/architecture/storage-internals/): how the registry resolves a config.

## Status

Pre-1.0 and versioned in lockstep with the other `beak_*` packages (0.9.0). Not on pub.dev yet: depend on it from git with `ref: v0.9.0` once that tag exists, or from a checkout with `path:`. What changed: the [root changelog](https://github.com/SimonErich/beak/blob/main/CHANGELOG.md). Contributing: [CONTRIBUTING.md](https://github.com/SimonErich/beak/blob/main/CONTRIBUTING.md).

## License

Apache-2.0 © Marqably GmbH. See [LICENSE](https://github.com/SimonErich/beak/blob/main/LICENSE).
