# beak_backend

The Shelf server for Beak: generated CRUD/query/batch/relations/aggregate
endpoints, validated uploads, auth, search, and CSV export — all from a
`BeakModelRegistry` over the worm ORM.

Part of [**Beak**](https://github.com/SimonErich/beak), a low-code,
configuration-driven admin-panel framework for Dart/Flutter. See the
[architecture guide](../../docs/architecture.md) for how the packages fit
together.

## What it is

The server layer of the Beak stack. It turns a `BeakModelRegistry` into a
complete REST surface — one resource router per registered model mounted under
`/api/{table}` — wrapped in Beak's middleware stack (request log → CORS → JSON
→ error mapping → auth). It is the **only** package that imports `worm`: the
default `WormDataSource` translates every `BeakQuerySpec` to worm against an
injected `DatabaseAdapter`, keeping `beak_core` source-agnostic. The primary
entry points are `BeakServer`, `beakApiRouter`, and `WormDataSource`.

## Usage

```dart
import 'package:beak_backend/beak_backend.dart';
import 'package:worm/worm.dart';

final BeakModelRegistry registry = buildReferenceRegistry();

final server = BeakServer(
  config: BeakBackendConfig.fromEnv(environment: BeakEnv.resolve()),
  registry: registry,
  dataSource: WormDataSource(registry, adapter: Worm.adapter()),
  storage: resolveStorage(const BeakMemoryStorageConfig()),
  policy: const BeakAllowAllPolicy(),
);

final http = await server.start();
// POST /api/products/query, GET /api/products/<id>, ... are now live.
```

Compose the generated API by hand — e.g. to mount it inside a larger Shelf app:

```dart
final handler = const Pipeline()
    .addMiddleware(beakJsonMiddleware())
    .addMiddleware(beakErrorMappingMiddleware())
    .addHandler(
      beakApiRouter(
        registry: registry,
        dataSource: WormDataSource(registry, adapter: adapter),
      ),
    );
```

## Key types

- `BeakServer` — composes the middleware stack around the router; `start()`
  binds the socket, `handler` exposes the raw `Handler`.
- `beakApiRouter` — builds the full generated API `Handler` from a registry
  and data source (uploads, auth, search, and export included).
- `WormDataSource` — the default `BeakDataSource`, executing every operation
  on an injected worm `DatabaseAdapter`.
- `BeakBackendConfig` — validated host/port/runtime config, `fromEnv(...)`.
- `UploadService` — validated per-column file uploads through a storage driver.
- `CsvExportService` / `GlobalSearchService` — CSV export and cross-model search.
- `BeakPolicy` / `BeakAuthGuard` — per-operation authorization and auth guarding.

## Status

Pre-1.0, part of the Beak monorepo. Consumed by the
[reference admin](../../apps/reference_admin). Contributions welcome — see
[CONTRIBUTING](../../CONTRIBUTING.md) at the repo root.

## License

Apache-2.0 © Marqably GmbH. See [LICENSE](LICENSE).
