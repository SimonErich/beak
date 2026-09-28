# beak_backend

The Shelf server for Beak: generated CRUD, query, batch, relation, aggregate
and summary endpoints, graph commits with a durable outbox, validated uploads,
auth, health probes and CSV export, all derived from a `BeakModelRegistry`
over the worm ORM.

Part of [**Beak**](https://github.com/SimonErich/beak), a low-code,
configuration-driven admin-panel framework for Dart/Flutter. See the
[architecture guide](../../docs/architecture/index.md) for how the packages fit
together.

## What it is

The server layer of the Beak stack. It turns a registry into a complete REST
surface, one resource router per model under `/api/{table}`, wrapped in Beak's
middleware stack (request log → CORS → JSON → error mapping → auth → your
middleware). `WormDataSource` translates every `BeakQuerySpec` to worm against
a `DatabaseAdapter`, which keeps `beak_core` source-agnostic.

A project imports it through `package:beak/server.dart` and rarely wires it
by hand.

## Usage

`beak prepare` writes `lib/beak/server.g.dart`, a `BeakServeHost` holding every
discovered model, migration and seeder, plus the `bin/serve.dart` and
`bin/migrate.dart` entrypoints that call it. The host reads `.env`, connects
`DATABASE_URL`, resolves the storage driver and serves the API.

The part that is yours is `lib/server.dart`. The host hands it the resolved
`BeakServerDefaults`, and `defaults.build(...)` takes whatever you want to
change:

```dart
import 'package:beak/server.dart';

import 'domain/order_preparer.dart';
import 'domain/order_effects.dart';
import 'models/models.dart';

BeakServer beakServer(BeakServerDefaults defaults) => defaults.build(
  policy: const ShopPolicy(),
  // Transactional rules for graph commits, and the models that may only be
  // written through them.
  preparePlan: OrderPreparer(defaults.registry).prepare,
  finalizePlan: const OrderEffects().finalize,
  graphOnly: const [OrderModel(), OrderItemModel()],
  // Effects the finalizer enqueued, delivered while the host serves.
  outbox: BeakOutboxSchedule(
    interval: const Duration(seconds: 5),
    handlers: {'receipt': sendReceipt},
  ),
  // Extra endpoints in front of the generated API, and middleware that runs
  // after authentication.
  routes: (Router()..get('/api/stats', stats)).call,
  middleware: [rateLimit()],
  corsOrigin: 'https://admin.example.com',
);
```

`BeakServeHost.serve()` validates the outbox schedule, binds the socket, starts
the schedule and stops it again when the returned server closes. An invalid
schedule fails the boot before any request is served. With
`DATABASE_URL=sqlite::memory:` it also applies the migrations and runs the
seeders in-process, since that database exists only inside the serving
process. `beak eject server` writes a starter `lib/server.dart`.

### Embedding in another Shelf app

`beakApiRouter` is the generated API as one `Handler`. Wrap it in the JSON and
error-mapping middleware so typed exceptions become JSON responses:

```dart
final config = BeakBackendConfig.fromEnv();
await initializeBeakDatabase(config);
final registry = buildBeakRegistry();
final handler = const Pipeline()
    .addMiddleware(beakJsonMiddleware())
    .addMiddleware(beakErrorMappingMiddleware())
    .addHandler(
      beakApiRouter(
        registry: registry,
        dataSource: WormDataSource(registry, adapter: Worm.adapter()),
      ),
    );
```

`BeakServer(...)` gives you the full middleware stack around it as
`server.handler`, or `server.start()` to bind the socket yourself.

## Key types

- `BeakServeHost`: environment, database, storage, serving, and the migration
  and seeding CLI (`runCli`).
- `BeakServerDefaults`: what the host resolved; `build(...)` returns the
  standard server with your changes.
- `BeakServer`: the middleware stack around the API. `handler` is the raw Shelf
  `Handler` and `start()` binds the socket.
- `beakApiRouter`: the generated API as one `Handler`.
- `WormDataSource`: the default `BeakDataSource`, executing every operation on
  a worm `DatabaseAdapter`.
- `BeakGraphCommitService` typedefs (`BeakSavePlanPreparer`,
  `BeakSavePlanFinalizer`): the transactional hooks behind `/api/commits`.
- `BeakOutbox`, `BeakOutboxSchedule`, `BeakOutboxWorker`: effects enqueued
  inside a commit and delivered after it.
- `BeakBackendConfig`: validated host, port and database URL, `fromEnv(...)`.
- `BeakPolicy`, `BeakRowPolicy`, `BeakFieldPolicy`, `BeakAuthGuard`,
  `BeakAuthSessions`: authorization and authentication.
- `adapterFromUrl`, `initializeBeakDatabase`: open the database a
  `DATABASE_URL` names.

## Status

Pre-1.0, part of the Beak monorepo. Consumed by the
[canonical shop](../../examples/clean_beak_config) and the
[Foodio admin panel](../../examples/foodio-adminpanel). Contributions welcome;
see [CONTRIBUTING](../../CONTRIBUTING.md) at the repo root.

## License

Apache-2.0 © Marqably GmbH. See [LICENSE](LICENSE).
