# reference_admin_server

The Shelf server binary of Beak's reference admin, wiring beak_backend over
Postgres + MinIO.

Part of [**Beak**](https://github.com/SimonErich/beak), a low-code,
configuration-driven admin-panel framework for Dart/Flutter. See the
[architecture guide](../../docs/architecture.md) for how the packages fit
together.

## What it is

The runnable backend for the [reference admin](../reference_admin): a thin
`bin/` that boots `beak_backend`'s auto-generated CRUD API over the shared
`reference_admin_models`, persisted with worm on Postgres and serving image
uploads from MinIO (S3). It also ships `bin/worm.dart`, the project-aware worm
CLI that owns the catalog migrations and seeder. The interesting entry points
are `buildReferenceServer`, `referenceStorageConfig`, `referenceMigrations`,
and `ReferenceSeeder`.

## Usage

```dart
import 'package:beak_backend/beak_backend.dart';
import 'package:reference_admin_server/reference_admin_server.dart';
import 'package:worm/worm.dart';

Future<void> main() async {
  final env = BeakEnv.resolve();
  final config = BeakBackendConfig.fromEnv(environment: env);
  await initializeWormPostgres(config);

  final storageConfig = referenceStorageConfig(env);
  final server = buildReferenceServer(
    config: config,
    adapter: Worm.adapter(),
    storage: storageConfig == null ? null : resolveStorage(storageConfig),
  );
  await server.start();
}
```

Run it end to end from this directory:

```bash
melos run up                                # Postgres :25432 + MinIO :29000
dart run bin/worm.dart migrate              # apply catalog schema
dart run bin/worm.dart db:seed              # sample Products/Users/Orders
dart run bin/reference_admin_server.dart    # serve the generated API
```

## Key types

- `buildReferenceServer` — assembles the `BeakServer` (registry + `WormDataSource`
  + optional storage) from a config, adapter, and driver.
- `referenceStorageConfig` — reads `BEAK_STORAGE_DRIVER` into a
  `BeakStorageConfig?` (`s3`, `memory`, or none).
- `referenceMigrations` — the ordered worm migrations registered in `bin/worm.dart`.
- `ReferenceSeeder` — seeds the catalog with representative sample data.

## Status

Pre-1.0, part of the Beak monorepo. This is the server half of the
[reference admin](../reference_admin) example. Contributions welcome — see
[CONTRIBUTING](../../CONTRIBUTING.md) at the repo root.

## License

Apache-2.0 © Marqably GmbH.
