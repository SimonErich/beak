---
title: Running the server
description: Boot the generated Shelf host, see what it resolves, change it in lib/server.dart and mount the same handler in a Shelf app of your own.
type: guide
audience: [beginner, expert]
status: stable
---

# Running the server

`beak prepare` already wrote a server. After this page you can start it, name what it resolved from your environment, change it in one file, and mount the same handler inside a Shelf app you own.

You do not write routes, a `main()` or a database bootstrap. The generated `bin/serve.dart` asks the generated `beakHost()` for a `BeakServeHost`, the host builds a `BeakServer`, and the server serves every model in your registry. The one file that is yours is the optional `lib/server.dart`.

## At a glance

| Piece | Who writes it | What it does |
| --- | --- | --- |
| `lib/beak/server.g.dart` | `beak prepare` | `beakHost()`: the registry, the migrations, the seeders and your `beakServer` function, wired into a `BeakServeHost` |
| `bin/serve.dart` | `beak prepare` | `beakHost().serve()`, then waits for SIGINT or SIGTERM and closes the server |
| `bin/migrate.dart` | `beak prepare` | `beakHost().runCli(args)`, which is what `beak migrate` and `beak seed` call |
| `lib/server.dart` | you, optional | `BeakServer beakServer(BeakServerDefaults defaults)`: policy, sessions, middleware, routes, graph rules, outbox |

```bash
beak migrate   # apply pending migrations, see the Migrations page
beak dev       # regenerate, print the flutter run line, serve the API
```

`beak dev` is `prepare` plus `dart run bin/serve.dart`. It does not watch files, so a change to a schema class or to `lib/server.dart` needs a restart. [CLI commands](../reference/cli-commands.md#beak-dev) has its flags.

```console
$ PORT=8391 HOST=127.0.0.1 dart run bin/serve.dart
listening on http://127.0.0.1:8391
[cd3cbc2ad0a8b9fc] GET /healthz -> 200 (4ms)
[781a5f186f4c00c9] POST /api/products/query -> 200 (11ms)
```

With nothing set, that is `0.0.0.0:8080` on a SQLite file called `beak.db`. The two log lines are the request log, one per request, on stderr.

## What the host resolves

The generated file is short, because everything it lists was found on disk:

```dart title="examples/clean_beak_config/lib/beak/server.g.dart"
BeakServeHost beakHost({Map<String, String>? environment}) => BeakServeHost(
  environment: environment,
  registry: buildBeakRegistry(),
  migrations: const [
    // ...
  ],
  seeders: const [ShopSeeder()],
  configure: server.beakServer,
);
```

`serve()` turns that into a listening socket. Read it once, because it says what happens at boot and, more usefully, what does not:

```dart title="packages/beak_backend/lib/src/server/beak_serve_host.dart"
--8<-- "packages/beak_backend/lib/src/server/beak_serve_host.dart:BeakServeHostServe"
```

1. The environment is `.env` overlaid by the process environment, and `BeakBackendConfig` reads `DATABASE_URL`, `PORT` and `HOST` from it. [Environment and config](../shipping/environment-and-config.md) lists every variable.
2. `initializeBeakDatabase` opens the adapter the `DATABASE_URL` scheme names, see [Databases](databases.md).
3. Migrations are applied here for one database only: `sqlite::memory:`, which vanishes with the process and cannot be prepared by another one. Every other database is migrated by `beak migrate`, on purpose, before the server that needs the columns starts.
4. `resolveStorageDriver()` picks the upload driver, see [Uploads and storage wiring](uploads-and-storage-wiring.md).
5. `buildServer` calls your `beakServer` if `lib/server.dart` has one, and `defaults.build()` if it does not.
6. If the server carries an outbox schedule, the host validates it before binding the port, so a broken schedule fails the boot and not the first effect. Its drain loop starts once the socket is bound and stops when you close the server.

The constructor arguments are the only levers, and `beak prepare` fills all of them. A test overrides `environment` and `now`:

| Argument | Meaning |
| --- | --- |
| `registry` | Every model this backend serves |
| `migrations`, `seeders` | What the CLI applies and runs, in the order `beak prepare` listed them |
| `storageRegistry` | A `BeakStorageRegistry Function()` from `beakStorageRegistry()` in `lib/server.dart`, for plug-in upload drivers |
| `configure` | Your `beakServer` function |
| `environment` | Replaces the whole resolved environment, `.env` included |
| `now` | The clock behind every write |

## Change the server in lib/server.dart

The file declares one top-level function. The host hands it everything it resolved (`config`, `registry`, `dataSource`, `environment`, `storage`, `now`), and you return the server. `beak eject server` writes a starter that returns `defaults.build()` unchanged. Run `beak prepare` after creating the file, because until then the generated host does not call it.

The shop passes two things: the preparer that owns its cross-record rules, and the tables that may only be written through it.

```dart title="examples/clean_beak_config/lib/server.dart"
--8<-- "examples/clean_beak_config/lib/server.dart:shopServer"
```

Everything `build` accepts, quoted from the source:

```dart title="packages/beak_backend/lib/src/server/beak_serve_host.dart"
--8<-- "packages/beak_backend/lib/src/server/beak_serve_host.dart:BeakServerDefaultsBuild"
```

Pass what you want to change. Everything else keeps the value the host resolved.

| Parameter | Default | Covered in |
| --- | --- | --- |
| `policy` | `BeakAllowAllPolicy()`, which allows everything | [Auth and policies](auth-and-policies.md) |
| `authSessions` | none: no `/api/auth` routes | [Auth and policies](auth-and-policies.md) |
| `authGuard` | a token guard over the sessions' store, or none | [Auth and policies](auth-and-policies.md) |
| `middleware` | none | [Middleware](middleware.md) |
| `routes` | none | [Middleware](middleware.md) |
| `corsOrigin` | `*` | [Middleware](middleware.md) |
| `onRequest` | one line per request on stderr | [Middleware](middleware.md) |
| `onUnexpectedError` | the error and its stack trace on stderr | [Middleware](middleware.md) |
| `preparePlan` | none | [Transactional business rules](graph-business-rules.md) |
| `graphOnly` | none | [Transactional business rules](graph-business-rules.md) |
| `finalizePlan` | none | [Durable effects](durable-effects.md) |
| `outbox` | none | [Durable effects](durable-effects.md) |
| `generateId` | a v4 uuid | Replaces the id mint behind every write, handy in tests |
| `transformRunner` | the `beak_image` runner | [Uploads and storage wiring](uploads-and-storage-wiring.md) |
| `storage` | the driver the environment selects | [Uploads and storage wiring](uploads-and-storage-wiring.md) |
| `dataSource` | the worm source over the database | [Custom data sources](../extending/custom-data-sources.md) |
| `signedUrlLifetime` | one hour | [Uploads and storage wiring](uploads-and-storage-wiring.md) |

`build` also takes `storage:` and `dataSource:`, which replace what the host resolved: `defaults.build(storage: MyStorageDriver())` serves uploads through a driver you built, and `defaults.build(dataSource: MyDataSource())` serves the API from a source that is not worm, which is where [Custom data sources](../extending/custom-data-sources.md) picks up. A driver from a package goes through `beakStorageRegistry()` and `BEAK_STORAGE_DRIVER` instead. `signedUrlLifetime:` sets how long the links of a signing driver stay valid (default one hour).

## Health probes

Two routes sit outside `/api`, mounted before it, for a container platform:

```console
$ curl -s localhost:8391/healthz
{"status":"ok"}
$ curl -s localhost:8391/readyz
{"status":"ok"}
```

`/healthz` answers while the process serves and never touches the database, so an outage cannot start a restart loop. `/readyz` counts the rows of the first registered model. It answers `503` with `{"status":"unavailable","detail":"the data source did not answer"}` when that fails, and the real error goes to `onUnexpectedError`. Neither probe consults a policy. [REST API](../reference/rest-api.md#health-probes) has the details.

## Embed the handler in a Shelf app

`BeakServer.handler` is the whole pipeline (request log, CORS, JSON, error mapping, auth, your middleware, the router) as one Shelf `Handler`. `host.buildServer` makes the server without binding a port, so another process can own the socket:

```dart
// Illustrative: a file of your own, using real Beak names. Nothing here is generated.
import 'package:beak/migrations.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shop_admin/beak/server.g.dart';

Future<void> main() async {
  final BeakServeHost host = beakHost();
  final DatabaseAdapter adapter = adapterFromUrl(host.config.databaseUrl);
  await adapter.connect();
  final BeakServer beak = host.buildServer(
    adapter: adapter,
    storage: host.resolveStorageDriver(),
  );
  Future<Response> app(Request request) async => switch (request.url.path) {
    'ping' => Response.ok('pong'),
    _ => await beak.handler(request),
  };
  await shelf_io.serve(app, '127.0.0.1', 8394);
}
```

That serves `/ping` from your code and everything else from Beak, with your `beakServer` applied. For most projects `routes:` on `defaults.build` does the same job without a second server, and a route of yours wins over a generated one on the same path.

Two things `buildServer` does not do, because `serve()` does them. It does not migrate `sqlite::memory:`, and it does not start the outbox: call `beak.outbox?.start(adapter, onError: beak.onUnexpectedError)` yourself, and stop the loop it returns when you shut down.

## Test the same host

Because the host is built from the registry, the policies and the transport contracts you ship, a test can run the real thing. The shop's harness starts an isolated host on an ephemeral loopback port and talks to it with the same `BeakClient` the panel uses:

```dart title="examples/clean_beak_config/test/support/shop_test_api.dart"
--8<-- "examples/clean_beak_config/test/support/shop_test_api.dart:ShopTestApi"
```

Three seams do the work. `beakHost(environment: {...})` replaces the resolved environment, so a test never reads your `.env`. `MigrationRunner(...).fresh(seed: true)` builds the schema and the seed data in memory. `host.buildServer(adapter:)` builds the server over the adapter you hand it and binds nothing until you call `start()`. `dispose` closes the client, the server and the adapter, and resets worm's state.

## Rules and limits

| Rule | Consequence |
| --- | --- |
| No `policy` means `BeakAllowAllPolicy` | A server built with `defaults.build()` answers anonymous requests in full. Bound beyond loopback (the default `0.0.0.0` counts) it prints one `warning:` line at boot; `onWarning` redirects it |
| The host binds `0.0.0.0` and answers CORS with `*` by default | Fine in a container or on your laptop, open to the network anywhere else. Set `HOST` and `corsOrigin`. See [Security](../shipping/security.md) |
| `lib/server.dart` is wired by `beak prepare` | A new or renamed `beakServer` is ignored until you run it. `beak dev`, `beak migrate` and `beak seed` run it for you |
| A bad `DATABASE_URL`, `PORT` or `HOST` fails the boot | `serve()` throws a `BeakConfigurationException` that names the variable. The generated `bin/serve.dart` prints it as one line (`error: PORT must be ...`) and exits `BeakServeHost.configurationExitCode` (`78`); an entry point that does not catch it ends in `Unhandled exception:` and exit `255` |
| A port that is already taken is a configuration failure | `Port 8080 is already in use on 0.0.0.0. Stop the other process or choose another port with PORT (server.port in beak.yaml).` It is a `BeakConfigurationException` from `BeakServer.start()`, so it prints as one line like the others |
| `serve()` initializes worm's default adapter | Calling it twice in one process, without `Worm.reset()` between, throws |
| `defaults.build` sets no storage driver or data source | Use `beakStorageRegistry()` for a driver, a hand-built `BeakServer` for a data source |
| One process holds the default sessions | The built-in session store is in memory, so a second instance does not know the first one's tokens. See [Auth and policies](auth-and-policies.md) |

## Verify it

Start the server and ask it three things. The first two prove the process is up and the database answers, the third proves the API exists and shows what your policy says to an anonymous caller:

```console
$ curl -s localhost:8391/healthz
{"status":"ok"}
$ curl -s localhost:8391/readyz
{"status":"ok"}
$ curl -s -X POST localhost:8391/api/products/query \
    -H 'content-type: application/json' -d '{"table":"products"}'
{"items":[{"values":{"id":"00000000-0000-4000-8000-000000000001","name":"Espresso beans","price":12.5,"active":true,"created_at":null,"updated_at":null},"relations":{}}],"total":1,"page":1,"perPage":25}
```

With a `BeakPolicies` set that does not list the model, the third call must answer `401`. `beak doctor` checks that the generated files are current, that every model has a migration and that the database has the columns your schema classes declare.

## Reference

- `packages/beak_backend/lib/src/server/beak_serve_host.dart`: `BeakServeHost`, `BeakServerDefaults`.
- `packages/beak_backend/lib/src/server/beak_server.dart`: `BeakServer` and its pipeline.
- `packages/beak_backend/lib/src/endpoints/health_router.dart`: the probes.
- [Configuration and environment](../reference/configuration.md) lists `BeakServerDefaults`, `BeakBackendConfig` and `BeakServeHost` member by member.
- [Backend flow](../architecture/backend-flow.md) follows one request through the layers.

## Continue reading

- [Databases](databases.md) how `DATABASE_URL` picks SQLite or Postgres.
- [Migrations](migrations.md) the step that has to run before the server does.
- [Auth and policies](auth-and-policies.md) closing the door `BeakAllowAllPolicy` leaves open.
- [Middleware](middleware.md) the pipeline around the router and how to add to it.
