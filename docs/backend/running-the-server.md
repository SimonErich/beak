---
title: Running the server
description: Boot a Beak backend from a main(): read the environment, connect worm to Postgres, assemble a BeakServer, and bind the socket.
---

# Running the server

After this page you can write the `main()` that starts a Beak backend: read config from
the environment, connect worm to Postgres, build a `BeakServer`, and serve it on a port.

A Beak server is four moves in a row. Read the effective environment, validate it into a
typed config, connect the database, and assemble the server. The reference backend's
entrypoint does exactly that and nothing else.

## The whole entrypoint

Here is `examples/store/bin/serve.dart` in full. It is the
tutorial store's server, and it fits on one screen.

```dart title="examples/store/bin/serve.dart"
Future<void> main() async {
  final Map<String, String> environment = BeakEnv.resolve();
  final config = BeakBackendConfig.fromEnv(environment: environment);
  await initializeWormPostgres(config);
  final storageConfig = referenceStorageConfig(environment);
  final server = buildReferenceServer(
    config: config,
    adapter: Worm.adapter(),
    storage: storageConfig == null ? null : resolveStorage(storageConfig),
  );
  final HttpServer httpServer = await server.start();
  stderr.writeln(
    'store listening on '
    'http://${httpServer.address.host}:${httpServer.port}',
  );
}
```

Run it from the app directory:

```bash
cd examples/store
dart run bin/store.dart
```

You should see, on stderr:

```text
store listening on http://0.0.0.0:8080
```

The tutorial store binds `0.0.0.0` on port **8080** by default, so the panel reaches it
at `http://localhost:8080`. (The kitchen-sink showcase, `superdashboard`, runs its
server on **8180** instead. Match the port to the app or a client hits
connection-refused.)

!!! note "What just happened"
    - `BeakEnv.resolve()` built the effective environment: a `.env` file overlaid by
      the real process environment.
    - `BeakBackendConfig.fromEnv` validated that into a typed config (database URL,
      port, host).
    - `initializeWormPostgres` opened the worm connection pool.
    - `buildReferenceServer` assembled the registry, data source, and storage into a
      `BeakServer`, and `start()` bound the socket.

## Configuration from the environment

Nothing in Beak reads environment variables except one factory: `BeakBackendConfig.fromEnv`.
It takes an already-resolved map and validates it, throwing a
`BeakConfigurationException` on anything missing or malformed. That is the only place
config is parsed, so a bad value fails loudly at startup instead of halfway through a
request.

```dart title="packages/beak_backend/lib/src/config/beak_backend_config.dart"
factory BeakBackendConfig.fromEnv({Map<String, String>? environment}) {
  final env = environment ?? Platform.environment;
  final rawDatabaseUrl = env['DATABASE_URL'];
  // ...validates DATABASE_URL, PORT, HOST...
}
```

The variables it reads:

| Variable | Required | Default | Rule |
| --- | --- | --- | --- |
| `DATABASE_URL` | yes | none (required) | An absolute URL with a scheme and host, e.g. `postgres://user:pass@host:5432/db`. |
| `PORT` | no | `8080` | An integer between 1 and 65535. |
| `HOST` | no | `0.0.0.0` | Non-empty. |

The port and host defaults are exposed as named constants, so the `8080` above is not a
bare literal:

```dart title="packages/beak_backend/lib/src/config/beak_backend_config.dart"
/// The port the server listens on when `PORT` is unset.
static const int defaultPort = 8080;

/// The interface the server binds when `HOST` is unset.
static const String defaultHost = '0.0.0.0';
```

One more thing worth knowing: the config's `toString` redacts the database credentials,
so you can log the config object without leaking a password.

### Where the values come from: BeakEnv.resolve

`BeakEnv.resolve()` produces the map you feed to `fromEnv`. It reads an optional `.env`
file and lets the real process environment win over it, so local development uses the
file and a deployment configures itself with real environment variables. No file is
required in any environment.

```dart title="packages/beak_backend/lib/src/config/env_loader.dart"
static Map<String, String> resolve({
  String filePath = '.env',
  Map<String, String>? processEnvironment,
}) => {...loadFile(filePath), ...processEnvironment ?? Platform.environment};
```

Secrets live in `.env`, which is git-ignored. A committed `.env.example` documents the
keys without the values. See [Environment and config](../deployment/environment-and-config.md)
for the deployment side of this.

## Connecting worm to Postgres

`initializeWormPostgres` is the one call that wires the worm ORM to your database. It
registers a single `'default'` adapter derived from the config's `DATABASE_URL`. Call it
once, before serving, and pair it with `Worm.reset()` on shutdown.

```dart title="packages/beak_backend/lib/src/data/worm/worm_bootstrap.dart"
Future<void> initializeWormPostgres(BeakBackendConfig config) =>
    Worm.initialize(
      config: const WormConfig(),
      adapters: <String, DatabaseAdapter>{
        'default': postgresAdapterFromUrl(config.databaseUrl),
      },
    );
```

The adapter is lazy: it opens a pool of up to ten connections on first use, not at
`initialize` time. After this call, `Worm.adapter()` returns the live adapter you hand
to the data source.

!!! warning "Call it once"
    Calling `initializeWormPostgres` twice without a `Worm.reset()` in between throws.
    In tests, `tearDown(Worm.reset)` keeps each test on a fresh adapter.

## Assembling the server

`BeakServer` is the composed backend: the middleware stack wrapped around the generated
router. Its constructor takes the config, the data source, the registry, and a handful
of optional knobs.

```dart title="packages/beak_backend/lib/src/server/beak_server.dart"
BeakServer({
  required this.config,
  required this.dataSource,
  required this.registry,
  this.storage,
  BeakTransformRunner? transformRunner,
  BeakPolicy policy = const BeakAllowAllPolicy(),
  BeakAuthSessions? authSessions,
  Handler? router,
  BeakAuthGuard? authGuard,
  BeakRequestLogger? onRequest,
  BeakUnexpectedErrorListener? onUnexpectedError,
});
```

The store example wraps this in a small builder so its `main()` reads cleanly. The
builder is where the three pieces meet: the registry, a `WormDataSource` over it, and
optional storage.

```dart title="examples/store/lib/server.dart"
BeakServer buildReferenceServer({
  required BeakBackendConfig config,
  required DatabaseAdapter adapter,
  BeakStorageDriver? storage,
}) {
  final BeakModelRegistry registry = buildBeakRegistry();
  return BeakServer(
    config: config,
    registry: registry,
    dataSource: WormDataSource(registry, adapter: adapter),
    storage: storage,
  );
}
```

Pass `storage: null` to serve without file uploads; pass a resolved
`BeakStorageDriver` to turn the upload endpoints on. When you leave `policy` at its
default `BeakAllowAllPolicy`, every request is permitted. Tighten that with a real
policy, covered in [Auth and policies](auth-and-policies.md).

Call `start()` on the result and it binds the configured host and port, returning the
live `HttpServer` you can later close to stop accepting connections.

```dart title="packages/beak_backend/lib/src/server/beak_server.dart"
Future<HttpServer> start() =>
    shelf_io.serve(handler, config.host, config.port);
```

## Migrations and seeds run separately

The server binary does not touch your schema. Migrations are explicit and applied
through a companion CLI, `bin/migrate.dart`, that registers the same migrations and
seeders:

```bash
cd examples/store
dart run bin/migrate.dart migrate
dart run bin/migrate.dart db:seed
```

That keeps schema changes deliberate: the server assumes the tables already exist. See
[Migrations](migrations.md) and [Seeding](seeding.md).

## Continue reading

- [The generated API](the-generated-api.md) the routes the running server exposes.
- [Migrations](migrations.md) get the schema in place before the first boot.
- [Middleware](middleware.md) what wraps the router inside `BeakServer.handler`.
- [Environment and config](../deployment/environment-and-config.md) the same config in a
  deployment.
