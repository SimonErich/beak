---
title: Going to production
description: Build, migrate and run a Beak backend and panel on a real host, what the deploy/ files do and where they fall short today, and what stays yours.
type: guide
audience: [expert]
status: stable
---

# Going to production

A Beak project compiles to two programs, a server and a panel, and both have to reach a host with a migrated database between them. The `deploy/` folder in the repository is a starting point for that: two Dockerfiles, an nginx config and a compose file, written for the shop in `examples/clean_beak_config`. After this page you can build and run both halves, know which parts of `deploy/` work as they stand and which do not, and list what remains your job.

`deploy/` is something you copy and adapt. Beak does not run your servers, terminate your TLS, rotate your secrets or back up your database, and nothing in the files pretends to.

## At a glance

| File | What it does |
| --- | --- |
| `deploy/Dockerfile.server` | Resolves the project, runs `beak prepare`, builds the server and the migrate CLI with `dart build cli`, and copies the two bundles into a `debian:bookworm-slim` image |
| `deploy/Dockerfile.web` | Builds the panel with `flutter build web --release` and serves the static files with nginx |
| `deploy/nginx.conf` | Serves the panel, falls back to `index.html` so client-side routes survive a refresh, and caches `/assets/` |
| `deploy/docker-compose.prod.yml` | Postgres, a one-shot migrate step, the server (uploads on a volume) and the panel |
| `deploy/.env.prod.example` | The server's variables, to copy to a git-ignored `.env.prod` beside it |
| `.dockerignore` (repository root) | Keeps `.git`, build output, local databases and `.env` out of the build context |

```mermaid
flowchart LR
  browser["Browser"] -->|"static files"| web["web (nginx, :8090)"]
  browser -->|"/api, /uploads"| server["server (:8080)"]
  server --> postgres[("Postgres")]
  server --> storage[("upload storage")]
  migrate["migrate (one-shot)"] --> postgres
```

The split follows a real boundary. The server is pure Dart and never imports Flutter or obers_ui, so it builds to a self-contained bundle and needs no Flutter in its runtime image. Only the panel needs a Flutter toolchain, and only at build time. `beak doctor` fails when a panel file imports server code, which matters because `dart:io` compiles for the web and only breaks when it runs.

!!! warning "One known failure in the deploy files"
    `Dockerfile.web` cannot build until the obers_ui pin moves. The pubspecs pin obers_ui by git commit, and at the commit pinned when this page was checked (`c956d25634c9`) the panel does not compile: resolving `beak_frontend` against it gives 175 analyzer errors, such as undefined `OiFieldLabel`, `OiBarPattern` and `headerGap`. The panel is written against a newer obers_ui than the one pinned. See [Working with obers_ui](../contributing/working-with-obers-ui.md) for the pin and how to move it.

    The server steps below were run on the host against Postgres 16, and the commands `Dockerfile.server` runs (`dart build cli` for the server and the migrate CLI) were run on the host as well. The server image itself was not built where this page was checked: `docker build --check` passes for both Dockerfiles, and building the web image would stop on the pin.

## Build the server

Resolve the project, generate the wiring, and build. From the project directory (`examples/clean_beak_config` here; in your own project, `beak prepare` is the installed command):

```console
$ flutter pub get
$ dart run ../../packages/beak_cli/bin/beak.dart prepare
$ dart build cli --target bin/serve.dart -o build/serve
Running build hooks...Running link hooks...Copying 1 build assets:
package:sqlite3/src/ffi/libsqlite3.g.dart
Generated: .../build/serve/bundle/bin/serve
$ dart build cli --target bin/migrate.dart -o build/migrate
```

`dart build cli` ships with recent Dart SDKs (these steps ran on 3.13.2). It writes a bundle, not a single file: `bundle/bin/<name>` is the executable and `bundle/lib/` holds the native SQLite library the build hook produced. Ship the whole `bundle/` directory, with `bin` and `lib` side by side. `bin/serve.dart` and `bin/migrate.dart` are the two entrypoints every Beak project has, because `beak prepare` writes them. They are generated, so build them after `prepare`.

`Dockerfile.server` runs the same two commands, then copies both `bundle/` directories into the runtime image, as `/opt/beak/server` and `/opt/beak/migrate`. The SQLite library travels inside each bundle, so the runtime image installs nothing but CA certificates. Build the image and start it once before you trust it.

## Migrate, then seed if you must

The bundle from `bin/migrate.dart` is the same worm CLI that `beak migrate` runs, so it works on a host with no Dart SDK. `beak migrate <verb>` and the compiled CLI map as follows:

```dart title="packages/beak_cli/lib/src/commands/dev_command.dart"
--8<-- "packages/beak_cli/lib/src/commands/dev_command.dart:BeakMigrateVerb"
```

Against an empty Postgres 16:

```console
$ export DATABASE_URL=postgres://beak:beak@127.0.0.1:5432/beak
$ ./build/migrate/bundle/bin/migrate migrate
migrated  20260926_000000_beak_commit_receipts
migrated  20260927_000000_beak_outbox
migrated  20260926_201252_create_companies_table
...
migrated  20260927_230000_add_variant_combinations
$ ./build/migrate/bundle/bin/migrate migrate
Nothing to migrate.
```

Migration order follows each migration's declared name, except that a table is created after the tables its foreign keys point at. Run this as a deploy step, before the new server version takes traffic, and again after every schema change. The server never migrates a file or Postgres database for you; only `sqlite::memory:` is migrated on boot, because no other process could do it.

Seeding is a separate decision. `db:seed` runs every eligible seeder every time you call it, so a seeder has to be safe to repeat, and demonstration data does not belong in production unless you meant it:

```console
$ ./build/migrate/bundle/bin/migrate db:seed
seeded  ShopSeeder
```

Two guards apply to destructive commands, both driven by `WORM_ENV`. With `WORM_ENV=production`, `migrate:fresh` and `migrate:refresh` refuse to run without `--force`. Set it in the environment of the migrate step and of the server. `migrate:rollback` has no guard.

## Configure and start the server

Set the variables from [Environment and config](environment-and-config.md). For one server in front of Postgres with uploads on a volume:

```bash
DATABASE_URL=postgres://beak:CHANGE-ME@db.internal:5432/beak?sslmode=require
PORT=8080
HOST=127.0.0.1
WORM_ENV=production
BEAK_STORAGE_DRIVER=local
BEAK_LOCAL_ROOT_DIR=/data/uploads
BEAK_LOCAL_PUBLIC_BASE_URL=https://api.example.com/uploads
```

Start the bundle. It handles `SIGINT` and `SIGTERM` itself, so `docker stop` and a systemd stop close the listener and exit cleanly:

```dart title="examples/clean_beak_config/bin/serve.dart"
  stderr.writeln('listening on http://${server.address.host}:${server.port}');
  await stopped;
  stderr.writeln('shutting down');
  await server.close();
  exit(0);
```

```console
$ ./build/serve/bundle/bin/serve
listening on http://127.0.0.1:8080
```

A setting the host refuses (a `PORT` that is not a number, an unsupported `DATABASE_URL`, a storage variable it cannot use, a port that is already taken) ends the process with one line on stderr and exit `78`. It prints no stack trace.

Two probes sit outside `/api` and outside authentication, so a platform can ask them without a token. `/healthz` is 200 while the process serves and never touches the database, so a database outage cannot cause a restart loop. `/readyz` is 200 when the data source answers and 503 when it does not, with no cause in the body:

```console
$ curl -s localhost:8080/healthz
{"status":"ok"}
$ curl -s localhost:8080/readyz
{"status":"ok"}
```

Use `/healthz` for the liveness probe and `/readyz` for readiness. The runtime image has no `curl`, so let the platform make the HTTP call rather than exec a command in the container.

Logs go to stderr, one line per request, with an id that also appears in error bodies and in the `x-request-id` response header. For a log aggregator that wants JSON on stdout, pass the logger Beak ships:

```dart title="packages/beak_backend/lib/src/server/middleware/request_log_middleware.dart"
BeakRequestLogger beakJsonRequestLogger({StringSink? sink}) {
  final StringSink target = sink ?? stdout;
  return (entry) => target.writeln(jsonEncode(entry.toJson()));
}
```

```dart
// Illustrative: lib/server.dart
BeakServer beakServer(BeakServerDefaults defaults) =>
    defaults.build(onRequest: beakJsonRequestLogger());
```

## Build the panel

The panel is a Flutter web app. Its API origin is compiled in, so build it for the address browsers will use:

```console
$ flutter build web --release --dart-define=BEAK_API_BASE_URL=https://api.example.com
```

`Dockerfile.web` takes the same value as the build argument `BEAK_API_BASE_URL`. It defaults to `http://localhost:8080`, which is only right on your own machine. The result is `build/web`: static files. `deploy/nginx.conf` serves them and falls back to `index.html`, so a refresh on a client-side route works:

```nginx title="deploy/nginx.conf"
server {
  listen 80;
  server_name _;

  root /usr/share/nginx/html;
  index index.html;

  # Long-cache the hashed build assets, never the entry document.
  location /assets/ {
    expires 30d;
    add_header Cache-Control "public, immutable";
    try_files $uri =404;
  }

  location / {
    try_files $uri $uri/ /index.html;
  }
}
```

It serves the panel and nothing else. It does not proxy `/api`, sets no security headers and does not enable gzip, so the JavaScript bundle goes out uncompressed. Add what you need, with `nginx -t` as the check.

### One origin or two

| Topology | Panel build | Server | Trade-off |
| --- | --- | --- | --- |
| Two origins (what `deploy/` does) | `BEAK_API_BASE_URL=https://api.example.com` | `corsOrigin: 'https://admin.example.com'` | Simple files, and the browser makes cross-origin calls, so CORS must name the panel |
| One origin, `/api` proxied | `api.baseUrl: auto` in `beak.yaml` | Default CORS is harmless | One certificate and no CORS at all, at the cost of a `location /api/` block |

For the second, the proxy block is short. It is illustrative: the syntax was checked with `nginx -t` against a literal upstream address, and `server` here is the compose service name.

```nginx
location /api/ {
  proxy_pass http://server:8080;
  proxy_set_header X-Forwarded-Proto $scheme;
  proxy_set_header Host $host;
  client_max_body_size 12m;
}
```

Route `/uploads/` the same way if the local driver serves your files, and size `client_max_body_size` to the largest upload column.

## The compose stack

`deploy/docker-compose.prod.yml` wires Postgres 16, the server and the panel. It parses (`docker compose -f deploy/docker-compose.prod.yml config`). Its intended flow, from the repository root:

```bash
cp deploy/.env.prod.example deploy/.env.prod   # then edit the secrets

# the database
docker compose -f deploy/docker-compose.prod.yml up -d postgres

# one-time setup (schema, seed)
docker compose -f deploy/docker-compose.prod.yml --profile setup run --rm migrate
docker compose -f deploy/docker-compose.prod.yml --profile setup run --rm migrate db:seed

# the app
docker compose -f deploy/docker-compose.prod.yml up -d --build server web
```

The API is published on `127.0.0.1:8080` and the panel on `127.0.0.1:8090`, and Postgres publishes nothing. The shop's server has no policy and no login (next section), so the stack keeps both application ports on the loopback interface. Publish them on another interface only once that is fixed and TLS is in front. `up` never migrates; the `migrate` service sits behind the `setup` profile and runs when you ask, so run it again after every schema change.

Read the file before you rely on it:

- The credentials live in two places. The compose file sets `POSTGRES_PASSWORD: beak`, and your `.env.prod` repeats it inside `DATABASE_URL`. Change both, or the server cannot log in.
- Uploads use the `local` driver, on the `uploads` volume the server mounts at `/data/uploads`. The public URL in `.env.prod` (`BEAK_LOCAL_PUBLIC_BASE_URL`) is what the browser is given, so set it to the address the API is reachable at. The shop registers no S3 driver, so `BEAK_STORAGE_DRIVER=s3` would stop the server at boot (see [Environment and config](environment-and-config.md#storage)).
- The server has no auth or policy. The shop is a demonstration with no login. See the next section.

## What stays yours

The shop's server is a demonstration: it has no policy and no login, and it answers anonymous requests in full. Everything in this table is outside what `deploy/` does for you.

| Concern | The decision |
| --- | --- |
| Authentication and authorization | A `BeakPolicies` set and a real `BeakAuthGuard`; see [Security](security.md). Without them the API is open. |
| TLS | Terminate at a proxy or platform. The Beak port speaks plain HTTP and the tokens are bearer tokens. |
| Which port is public | Bind Beak to a private interface (`HOST`) or network and publish only the proxy. |
| Secrets | From the platform's secret store into the environment. Never in an image, a `--dart-define` or a committed file. |
| Backups and restore | A Postgres backup policy, tested. Uploaded files need their own. |
| Migrations | A CI or release step that runs before traffic moves, with `WORM_ENV=production`. |
| More than one server process | The built-in session store is per process, so use a shared `TokenSessionStore` or your own guard first. Receipts already keep a save from applying twice across processes. |
| Upload storage | Durable, and reachable at the public URL you configured. Files on a container's own disk disappear with it. |
| Limits | Request size, rate limits and `perPage` at the proxy; see [Performance](performance.md). |
| Monitoring | Probes, the JSON request log, and an alert on 5xx and on `/readyz`. |

If your backend is Serverpod, this page does not apply: the Beak API runs inside the Serverpod server. See [Serverpod](../serverpod/index.md).

## Rules and limits

- Build the entrypoints after `beak prepare` in the same revision as the schema, and run migrations before the server that needs them starts. A server that meets a missing column fails on the first request that touches it.
- A pure-Dart server image needs no Flutter, but a build that resolves a Beak project needs a Flutter SDK, because the project's shared pubspec depends on Flutter.
- `dart build cli` bundles must move as directories. Copying `bundle/bin/serve` alone loses the SQLite library.
- The panel's API origin is fixed at build time. A different origin means a different build.

## Verify it

After a deploy, run through a short list against the real host:

```console
$ curl -s https://api.example.com/healthz
{"status":"ok"}
$ curl -s https://api.example.com/readyz
{"status":"ok"}
$ curl -s -o /dev/null -w '%{http_code}\n' -X POST https://api.example.com/api/products/query \
    -H 'content-type: application/json' -d '{"table":"products"}'
```

The last call must print 401 once your policy is in place. Then sign in to the panel and create, read and edit one record, upload one file and open its URL from a second machine, restart the server and confirm the panel signs in again, and pull the network cable on a save (or stop the server mid-request) to see the form recover by its save id and not duplicate the write. `beak doctor` in CI catches stale generated files before a build starts.

## Reference

- [Environment and config](environment-and-config.md) for every variable and how they resolve.
- `deploy/README.md` for the commands the compose file was written around.
- [Running the server](../backend/running-the-server.md) for how the generated host becomes a live server.
- [Migrations](../backend/migrations.md) for writing and ordering them.

## Continue reading

- [Security](security.md) the policy, the login and the limits to settle before launch.
- [Performance](performance.md) the pool, the isolate and the proxy settings that matter under load.
- [Testing](testing.md) the suites to run before a build.
