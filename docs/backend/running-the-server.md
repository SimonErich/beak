---
title: Running the server
description: Boot a Beak backend from the generated bin/serve.dart, understand the BeakServeHost behind it, and change the parts that are yours in lib/server.dart.
---

# Running the server

After this page you can start a Beak backend, point it at a database, and change
the parts of it that are actually yours: the policy, the login accounts, the
middleware, the upload driver.

You no longer write a `main()` for the server. `beak prepare` writes two of them,
`bin/serve.dart` and `bin/migrate.dart`, and both are a single statement over the
same generated host.

## The whole entrypoint

Here is `examples/store/bin/serve.dart`, minus the "generated, do not edit"
header every generated file carries.

```dart title="examples/store/bin/serve.dart"
import 'dart:io';

import 'package:store/beak/server.g.dart';

/// Serves the API.
Future<void> main() async {
  final HttpServer server = await beakHost().serve();
  stderr.writeln('listening on http://${server.address.host}:${server.port}');
}
```

Run it from the project directory:

```bash
cd examples/store
dart run bin/serve.dart
```

You should see, on stderr:

```text
listening on http://0.0.0.0:8080
```

The store binds `0.0.0.0` on port **8080** by default, so the panel reaches it at
`http://localhost:8080`. The kitchen-sink showcase, `examples/superdashboard`,
sets `server.port: 8180` in its `beak.yaml` because both run from this
repository. Match the port to the app or a client hits connection-refused.

`beak dev` is the same boot with a regeneration in front of it: it runs
`beak prepare`, prints the `flutter run` line for the panel, and then starts
`bin/serve.dart` for you.

!!! note "What just happened"
    - `beakHost()` came from `lib/beak/server.g.dart`: your registry, your
      migrations, your seeders, and your `lib/server.dart` if you wrote one.
    - `serve()` resolved the environment, validated it into a typed config,
      connected the database, resolved the upload driver, built the server, and
      bound the socket.
    - Not one line of that chain is a file you maintain.

## What beakHost() is

`lib/beak/server.g.dart` is generated and committed. It is the only place your
project's parts are named, and `beak prepare` names them by looking at the
folders they live in.

```dart title="examples/store/lib/beak/server.g.dart"
BeakServeHost beakHost({Map<String, String>? environment}) => BeakServeHost(
  environment: environment,
  registry: buildBeakRegistry(),
  migrations: const [
    CreateCategoriesTable(),
    CreateUsersTable(),
    CreateOrdersTable(),
    CreateProductsTable(),
    CreateOrderItemsTable(),
    CreateRoastProfilesTable(),
    CreateTagsTable(),
    CreateProductTagTable(),
  ],
  seeders: const [StoreSeeder()],
  configure: server.beakServer,
);
```

| Argument | Where it comes from |
| --- | --- |
| `registry` | Every `@Resource` class under `lib/models/`, through the generated `buildBeakRegistry()`. |
| `migrations` | Every `Migration` under `lib/migrations/`, ordered by its `name`. |
| `seeders` | Every `Seeder` under `lib/seeders/`. |
| `configure` | Present only because the store has a `lib/server.dart` declaring `beakServer`. |
| `storageRegistry` | Present only when that same file also declares `beakStorageRegistry`. |
| `environment` | The parameter above, or `BeakEnv.resolve()` when the caller passes nothing. |

There is no list to keep in step. Adding a migration means adding a file under
`lib/migrations/`; adding a seeder means adding a file under `lib/seeders/`. The
list that used to be hand-maintained is the list that used to be wrong.

The `environment` parameter is what makes the backend testable end to end. A test
hands the real host a different database and a temporary upload directory, and
still exercises the wiring the deployment runs:

```dart title="examples/store/test/api_sqlite_test.dart"
  runStoreApiScenario(
    description: 'store API on sqlite',
    environmentFor: (port) => {
      'DATABASE_URL': 'sqlite::memory:',
      'BEAK_STORAGE_DRIVER': 'local',
      'BEAK_LOCAL_ROOT_DIR': uploads.path,
      // Served by the Beak server itself, so an uploaded file's URL resolves
      // with nothing else running.
      'BEAK_LOCAL_PUBLIC_BASE_URL': 'http://127.0.0.1:$port/uploads',
    },
  );
```

## What the host does

`BeakServeHost` owns the whole lifecycle: environment, typed config, database
adapter, registry, running server, plus the migration and seeding CLI over the
same wiring.

```dart title="packages/beak_backend/lib/src/server/beak_serve_host.dart"
  BeakServeHost({
    required this.registry,
    this.migrations = const [],
    this.seeders = const [],
    this.storageRegistry,
    this.configure,
    Map<String, String>? environment,
    DateTime Function()? now,
  }) : _environment = environment ?? BeakEnv.resolve(),
       _now = now ?? DateTime.now;
```

`serve()` does what every hand-written `main()` used to do, in the order it has
to happen: connect the database, resolve the upload driver, build the server,
bind the socket.

```dart title="packages/beak_backend/lib/src/server/beak_serve_host.dart"
  Future<HttpServer> serve() async {
    await initializeWormPostgres(config);
    final server = buildServer(
      adapter: Worm.adapter(),
      storage: resolveStorageDriver(),
    );
    return server.start();
  }
```

`buildServer` is the seam underneath it: it assembles the data source and the
defaults, and hands them to your `configure` hook if you have one.

```dart title="packages/beak_backend/lib/src/server/beak_serve_host.dart"
  BeakServer buildServer({
    required DatabaseAdapter adapter,
    BeakStorageDriver? storage,
  }) {
    final defaults = BeakServerDefaults(
      config: config,
      registry: registry,
      dataSource: WormDataSource(registry, adapter: adapter, now: _now),
      environment: _environment,
      storage: storage,
    );
    return configure?.call(defaults) ?? defaults.build();
  }
```

Because `buildServer` binds no socket, it is also how tests and embedded hosts
get a real server without a port. The
[`examples/embedded`](https://github.com/SimonErich/beak/tree/main/examples/embedded)
app calls it and mounts `server.handler` inside a Shelf app it already had.

## Configuration from the environment

The server's own settings are parsed in exactly one factory,
`BeakBackendConfig.fromEnv`. It takes an already-resolved map and validates it,
throwing a `BeakConfigurationException` on anything malformed, so a bad value
fails at startup instead of halfway through a request. (`BeakStorageSettings`
does the same job for the `BEAK_STORAGE_*` variables covered further down, over
the same resolved map. Those two are the whole of it: no handler, service or
data source reads a variable.)

The variables it reads:

| Variable | Required | Default | Rule |
| --- | --- | --- | --- |
| `DATABASE_URL` | no | `sqlite:beak.db` | An absolute URL with a scheme. A `sqlite:` URL names a file (or `:memory:`); anything else needs a host, for example `postgres://user:pass@host:5432/db`. |
| `PORT` | no | `8080` | An integer between 1 and 65535. |
| `HOST` | no | `0.0.0.0` | Non-empty. |

The defaults are named constants, so the `8080` above is not a bare literal:

```dart title="packages/beak_backend/lib/src/config/beak_backend_config.dart"
  /// The port the server listens on when `PORT` is unset.
  static const int defaultPort = 8080;

  /// The interface the server binds when `HOST` is unset.
  static const String defaultHost = '0.0.0.0';
```

So is the database:

```dart title="packages/beak_backend/lib/src/config/beak_backend_config.dart"
  /// The database a project gets when it names none.
  ///
  /// A file beside the project, so the very first `beak dev` needs no Docker,
  /// no credentials and no `.env`. Requiring a database to see anything at all
  /// loses more first-time users than any other step.
  static const String defaultDatabaseUrl = 'sqlite:beak.db';
```

One more thing worth knowing: the config's `toString` redacts the database
credentials, so you can log the config object without leaking a password.

### A fixed development port

A project that wants a different port every day sets `PORT`. A project that
wants the same one forever says so in `beak.yaml`:

```yaml title="examples/superdashboard/beak.yaml"
server:
  # The store example already has 8080, and both run from this repository.
  port: 8180
```

`beak prepare` folds that into the generated host as a *default*, spread before
the resolved environment so a real `PORT` in a deployment still wins:

```dart title="examples/superdashboard/lib/beak/server.g.dart"
  environment: {'PORT': '8180', ...environment ?? BeakEnv.resolve()},
```

### Where the values come from: BeakEnv.resolve

`BeakEnv.resolve()` produces the map `fromEnv` validates. It reads an optional
`.env` file and lets the real process environment win over it, so local
development uses the file and a deployment configures itself with real
environment variables. No file is required in any environment.

```dart title="packages/beak_backend/lib/src/config/env_loader.dart"
  static Map<String, String> resolve({
    String filePath = '.env',
    Map<String, String>? processEnvironment,
  }) => {...loadFile(filePath), ...processEnvironment ?? Platform.environment};
```

Secrets live in `.env`, which is git-ignored. A committed `.env.example`
documents the keys without the values. See
[Environment and config](../deployment/environment-and-config.md) for the
deployment side of this.

## Connecting the database

One function maps a `DATABASE_URL` to a driver, and everything that opens a
connection goes through it: the server, the migration CLI, and a hand-built
adapter in a test.

```dart title="packages/beak_backend/lib/src/data/worm/worm_bootstrap.dart"
--8<-- "packages/beak_backend/lib/src/data/worm/worm_bootstrap.dart:adapterFromUrl"
```

`initializeWormPostgres` is the call `serve()` makes before anything else. It
registers a single `'default'` adapter chosen by that scheme.

```dart title="packages/beak_backend/lib/src/data/worm/worm_bootstrap.dart"
--8<-- "packages/beak_backend/lib/src/data/worm/worm_bootstrap.dart:initializeWormPostgres"
```

Switching database is one variable:

=== "SQLite (the default)"

    ```bash
    # Nothing to set. The server writes beak.db beside the project,
    # and .gitignore already excludes it.
    ```

=== "Postgres"

    ```bash
    DATABASE_URL=postgres://beak:beak@localhost:25432/beak
    ```

The Postgres adapter is lazy: it opens a pool of up to ten connections on first
use, not at `initialize` time. After the call, `Worm.adapter()` returns the live
adapter the data source runs on.

!!! warning "Call it once"
    Calling `initializeWormPostgres` twice without a `Worm.reset()` in between
    throws. In tests, `tearDown(Worm.reset)` keeps each test on a fresh adapter.

## Changing what the server does

`lib/server.dart` is the file you write when the defaults are not enough.
Declare a top-level function called `beakServer` taking `BeakServerDefaults`, and
`beak prepare` wires it into the host. `beak eject server` writes the starter
version, which returns Beak's own default and changes nothing until your first
edit.

The store uses it for the two things Beak cannot guess: who may log in, and
which rows each of them sees.

```dart title="examples/store/lib/server.dart"
BeakServer beakServer(BeakServerDefaults defaults) {
  final String secret =
      defaults.environment['AUTH_SECRET'] ?? 'store-dev-secret';
  final store = InMemoryTokenSessionStore();
  return defaults.build(
    policy: const StorePolicy(),
    authSessions: BeakAuthSessions(
      store: store,
      secret: secret,
      users: [
        BeakUserAccount(
          username: 'ada@example.com',
          passwordHash: hashBeakPassword('espresso', secret: secret),
          principal: const BeakPrincipal(
            id: StoreSeedIds.userAda,
            roles: {'staff'},
          ),
        ),
        // ...and linus@example.com, a customer.
      ],
    ),
    authGuard: TokenSessionAuthGuard(store),
  );
}
```

`BeakServerDefaults` carries everything the host already resolved:

| Member | What it holds |
| --- | --- |
| `config` | Host, port and database URL, validated. |
| `registry` | Every model the project registered. |
| `dataSource` | The `WormDataSource` over the connected adapter. |
| `storage` | The resolved upload driver, or `null` when uploads are off. |
| `environment` | The environment the host resolved, `.env` included. |
| `build(...)` | The server Beak would have built, with your changes applied. |

`build` takes the arguments worth changing and fills the rest in from the
defaults:

```dart title="packages/beak_backend/lib/src/server/beak_serve_host.dart"
  BeakServer build({
    BeakPolicy policy = const BeakAllowAllPolicy(),
    BeakAuthSessions? authSessions,
    BeakAuthGuard? authGuard,
    BeakRequestLogger? onRequest,
    BeakUnexpectedErrorListener? onUnexpectedError,
  }) => BeakServer(
```

!!! tip "Read settings from `defaults.environment`, not `Platform.environment`"
    The store reads its `AUTH_SECRET` off `defaults.environment`. That is what
    makes the whole server testable: a test that hands `beakHost` an environment
    hands it to the policy and the auth configuration too. Reaching for
    `Platform.environment` inside `beakServer` would quietly opt out of that.

Leaving `policy` at its default `BeakAllowAllPolicy` permits every request.
Tighten it with a real policy, covered in
[Auth and policies](auth-and-policies.md).

### Registering an upload driver

`beak_backend` depends on no driver package on purpose, so an S3 dependency does
not land in the graph of every Beak backend. A project that uploads to S3
declares the package and registers it from the same `lib/server.dart`, in a
second function called `beakStorageRegistry`:

```dart title="examples/embedded/lib/server.dart"
--8<-- "examples/embedded/lib/server.dart:beakStorageRegistry"
```

`beak prepare` notices the second function and passes it through as the host's
`storageRegistry`. Selecting a driver that is not registered throws a
`BeakConfigurationException` naming it at boot, rather than failing on the first
upload.

## Uploads without S3, MinIO or a proxy

`BEAK_STORAGE_DRIVER` picks the driver, and `local` needs nothing else running.
Files land under `BEAK_LOCAL_ROOT_DIR`, and the Beak server serves them itself
under the path of `BEAK_LOCAL_PUBLIC_BASE_URL`:

```bash
BEAK_STORAGE_DRIVER=local
BEAK_LOCAL_ROOT_DIR=var/uploads
BEAK_LOCAL_PUBLIC_BASE_URL=http://localhost:8080/uploads
```

That is the same posture as the default SQLite database: the first upload works
on a laptop with no infrastructure. A deployment usually puts a CDN or a web
server in front instead, in which case you point the public base URL at that and
the built-in route stops being used. The details are in
[Uploads and storage wiring](uploads-and-storage-wiring.md).

With `BEAK_STORAGE_DRIVER` unset you get that same local disk driver without
setting anything: files land under `storage/uploads` and the server serves them
at `/uploads`. `BEAK_STORAGE_DRIVER=none` is the way to turn uploads off, and
then the upload endpoints are not mounted at all.

## Migrations and seeds run separately

The server binary does not touch your schema. `bin/migrate.dart` is the same
host with `runCli` instead of `serve`, so the migrations it applies and the API
the server exposes can never come from different registries:

```bash
cd examples/store
dart run bin/migrate.dart migrate
dart run bin/migrate.dart db:seed
```

`beak migrate` and `beak seed` are the same two commands with a regeneration in
front. Booting the server never applies a migration: a production schema change
should be a decision you make, not a side effect of a deploy. See
[Migrations](migrations.md) and [Seeding](seeding.md).

## Booting the host in a test

Because `beakHost` takes an environment and `buildServer` takes an adapter, an
integration test drives the real backend with no infrastructure at all. The
store's API suite does exactly that on `sqlite::memory:`, then runs the identical
assertions against Postgres under the `e2e` tag.

```dart title="examples/store/test/api_scenario.dart"
      final BeakServeHost host = beakHost(environment: environment);
      adapter = adapterFromUrl(host.config.databaseUrl);
      await adapter.connect();
      await MigrationRunner(
        adapter: adapter,
        migrations: host.migrations.toList(),
        seeders: host.seeders,
      ).fresh(seed: true);

      final server = host.buildServer(
        adapter: adapter,
        storage: host.resolveStorageDriver(),
      );
      httpServer = await server.start();
```

## Continue reading

- [The generated API](the-generated-api.md) the routes the running server exposes.
- [Migrations](migrations.md) get the schema in place before the first boot.
- [Middleware](middleware.md) what wraps the router inside `BeakServer.handler`.
- [Auth and policies](auth-and-policies.md) what `lib/server.dart` usually exists for.
- [Environment and config](../deployment/environment-and-config.md) the same config in a
  deployment.
