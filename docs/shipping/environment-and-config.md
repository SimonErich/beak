---
title: Environment and config
description: Every variable a Beak backend reads, which value wins when a name is set twice, and the settings that are compiled in and never read at runtime.
type: guide
audience: [expert]
status: stable
---

# Environment and config

A Beak backend configures itself from environment variables, with a `.env` file for local defaults and the real process environment on top for deployment. After this page you can name every variable the backend reads, predict which value wins when a name is set in two places, and tell the settings that can change at runtime from the ones that are compiled in.

None of the variables is required. A project that sets nothing runs on a SQLite file, keeps uploads on local disk beside it, and listens on port 8080, which is what the first `beak dev` should do. Everything below is opt-in, and a wrong value fails at boot with a message that names the variable.

## At a glance

| Variable | Read by | Default | Effect |
| --- | --- | --- | --- |
| `DATABASE_URL` | `BeakBackendConfig.fromEnv` | `sqlite:beak.db` | Database. `sqlite:` or `file:` opens SQLite, anything else must be `postgres://` or `postgresql://` |
| `PORT` | `BeakBackendConfig.fromEnv` | `8080` | Listen port, 1 to 65535 |
| `HOST` | `BeakBackendConfig.fromEnv` | `0.0.0.0` | Interface to bind, must not be empty |
| `BEAK_STORAGE_DRIVER` | `BeakStorageSettings.fromEnv` | unset: local disk under `storage/uploads` | `s3`, `ftp`, `local`, `memory` or `none` |
| `BEAK_S3_ENDPOINT`, `BEAK_S3_BUCKET`, `BEAK_S3_ACCESS_KEY`, `BEAK_S3_SECRET_KEY`, `BEAK_S3_REGION` | `BeakStorageSettings.fromEnv` | none | Required when the driver is `s3` |
| `BEAK_S3_USE_PATH_STYLE` | `BeakStorageSettings.fromEnv` | `false` | `true` for path-style addressing, which MinIO needs |
| `BEAK_S3_PUBLIC_BASE_URL` | `BeakStorageSettings.fromEnv` | none | Where browsers fetch files from, for a CDN or proxy in front of the bucket |
| `BEAK_LOCAL_ROOT_DIR`, `BEAK_LOCAL_PUBLIC_BASE_URL` | `BeakStorageSettings.fromEnv` | none | Required when the driver is `local` |
| `BEAK_FTP_HOST`, `BEAK_FTP_USER`, `BEAK_FTP_PASSWORD`, `BEAK_FTP_BASE_DIR`, `BEAK_FTP_PUBLIC_BASE_URL` | `BeakStorageSettings.fromEnv` | none | Required when the driver is `ftp` |
| `BEAK_FTP_PORT` | `BeakStorageSettings.fromEnv` | `21` | FTP port |
| `WORM_ENV` | worm, from the process environment; the CLI also reads `.env` | `development` | `development`, `staging`, `production`, `testing` (case-insensitive); see below |
| `BEAK_API_BASE_URL` | the Flutter compiler, as `--dart-define` | `api.baseUrl` from `beak.yaml` | The origin the panel calls; compiled in, not read at runtime |

That is the whole list. Beak has no built-in variable for an authentication secret; you choose a name and read it through `defaults.environment` in `lib/server.dart`.

The repository's own `.env.example` shows the shape, pointed at the dev services:

```bash title=".env.example"
PORT=8180
DATABASE_URL=postgres://beak:beak@localhost:25432/beak
BEAK_STORAGE_DRIVER=s3
BEAK_S3_ENDPOINT=http://localhost:29000
BEAK_S3_BUCKET=beak-uploads
BEAK_S3_ACCESS_KEY=beak
BEAK_S3_SECRET_KEY=beaksecret
BEAK_S3_REGION=us-east-1
BEAK_S3_USE_PATH_STYLE=true
```

Those ports belong to this repository's dev stack (see [Dev infrastructure](../contributing/dev-infrastructure.md)). A deployment uses its own hostnames and ports, and its own credentials.

## Which value wins

A variable can come from three places. The lowest is the default `beak.yaml` bakes into the generated host, the middle is the `.env` file, and the real process environment is on top:

```dart title="packages/beak_backend/lib/src/config/env_loader.dart"
--8<-- "packages/beak_backend/lib/src/config/env_loader.dart:resolve"
```

That single rule lets one build run locally off a file and in production off the container environment with no file at all. `BeakEnv.resolve` reads `.env` from the working directory of the process, so a server started from another directory does not find it. A missing file is not an error.

The `server:` block in `beak.yaml` (keys `port` and `host`) seeds `PORT` and `HOST` as defaults. `beak prepare` bakes it into the generated host, and a real `PORT` in the environment still decides where the process binds. Use it for a fixed development port that is not 8080, and leave production to the environment.

The file format is dotenv, and it is smaller than dotenv is elsewhere. It supports `#` comment lines, blank lines, an optional `export ` prefix, spaces around `=` and matching quotes around a value. It splits on the first `=`. It does not support comments after a value: `PORT=8080 # http` sets `PORT` to `8080 # http`, which fails validation. A line without `=` or with an invalid key throws.

In a test, `beakHost(environment: {...})` replaces the resolved environment entirely, `.env` included. That is the seam that lets a suite point the real host at `sqlite::memory:` without touching the machine ([Testing](testing.md)).

## The database

The scheme picks the driver, in one place, so `beak dev`, `bin/migrate.dart` and a hand-built server cannot disagree about what `DATABASE_URL` means.

| Value | Result |
| --- | --- |
| unset | `sqlite:beak.db`, a file beside the process |
| `sqlite:beak.db`, `sqlite:///var/data/beak.db`, `file:...` | SQLite at that path |
| `sqlite::memory:` | SQLite that vanishes with the process; the server migrates and seeds it itself on boot |
| `postgres://user:pass@host:5432/db` | Postgres; the port defaults to 5432 |
| `postgres://...?sslmode=require` | Postgres over TLS |
| `beak.db` (no scheme) | Boot error: `DATABASE_URL must be an absolute URL` |

`sslmode=require` is the only value recognized. Any other value, including `verify-full`, leaves TLS off, so put certificate checking at the network layer if you need it. The Postgres pool has ten connections, and there is no variable for that number.

The configuration object redacts the credentials when printed, so logging it is safe.

## The server address

The backend listens on `0.0.0.0:8080` unless told otherwise. Binding every interface is what makes a container reachable, since a server inside Docker that listened on loopback only would be unreachable from outside. Outside a container it means the port is open to the network. Behind a reverse proxy on the same host, set `HOST=127.0.0.1`.

## Storage

With `BEAK_STORAGE_DRIVER` unset, uploads go to `storage/uploads` relative to the working directory, and the server serves them itself at `/uploads`. `none` removes the upload endpoints entirely. A typo fails at boot with the supported names in the message. A driver chosen without its settings fails naming the first missing variable:

```console
$ BEAK_STORAGE_DRIVER=s3 ./build/serve/bundle/bin/serve
error: BEAK_S3_ENDPOINT is required when BEAK_STORAGE_DRIVER=s3.
```

Two things need care on a real host.

### The default URL points at `localhost`

With nothing configured, an uploaded file's URL is built from the bind address, and `0.0.0.0` becomes `localhost`. The browser gets `http://localhost:8080/uploads/...`, which is right on your machine and wrong on a server. For local disk in production, choose the driver explicitly and give it the public address, on a directory that survives a restart:

```bash
BEAK_STORAGE_DRIVER=local
BEAK_LOCAL_ROOT_DIR=/data/uploads
BEAK_LOCAL_PUBLIC_BASE_URL=https://api.example.com/uploads
```

The server mounts a read-only route at the path of the public URL (`/uploads`), so those files are served without a bucket, a CDN or a proxy rule. Point the variable at a CDN or the web server and that route stops being used.

### A driver must be registered before the variable can select it

`beak_backend` depends on no driver package, so `s3` and `ftp` fail with `No storage driver is registered for "s3". Registered drivers: memory, local.` until the project adds the driver package and declares a `beakStorageRegistry()` in `lib/server.dart`. `beak prepare` then hands it to the generated host. The shop's `lib/server.dart` does not, so pointing the shop at `s3` fails at boot; [Custom storage drivers](../extending/custom-storage-drivers.md) shows the registration.

The S3 driver builds file URLs from `BEAK_S3_ENDPOINT` (with the bucket, for path-style) unless `BEAK_S3_PUBLIC_BASE_URL` is set. An endpoint that is only reachable inside your network therefore hands the browser URLs it cannot open until you set that variable to the address the browser can reach. Or use `local`.

## `WORM_ENV`

`WORM_ENV` is worm's variable, not Beak's, and it matters in production. It is read from the real process environment only, never from `.env`, and it defaults to `development` when unset. The exception is the CLI: `beak migrate fresh`, `refresh` and `beak seed` read `WORM_ENV` from `.env` too (the shell wins), so a production marker in the file arms the `--force` requirement and filters the seeders.

- `migrate:fresh` and `migrate:refresh` refuse to run under `WORM_ENV=production` without `--force`. Under any other value, including unset, they run, and they roll every migration back first.
- A seeder can declare the environment it belongs to, and `db:seed` skips seeders declared for another one. Seeders that declare nothing run everywhere, and `db:seed` runs every eligible seeder every time you call it, so write them to be repeatable.

```console
$ WORM_ENV=production ./build/migrate/bundle/bin/migrate migrate:fresh
error: refusing to run destructive command in production without --force
```

`migrate:rollback` is not guarded. Set `WORM_ENV=production` in the environment of the migrate step and of the server, so a stray command on the wrong shell cannot wipe a database by accident.

## The panel's API origin

The panel is a Flutter web app, so it has no environment when it runs. The origin it calls is compiled in, from `api.baseUrl` in `beak.yaml`, and the generated panel reads it as a compile-time default:

```dart title="examples/quickstart/lib/beak/panel.g.dart"
    apiBaseUrl: const String.fromEnvironment(
      'BEAK_API_BASE_URL',
      defaultValue: 'http://localhost:8080',
    ),
```

One build can point elsewhere without touching the file:

```bash
flutter build web --release --dart-define=BEAK_API_BASE_URL=https://api.example.com
```

The value has to be an address the browser can reach, not a hostname from inside your container network. With `api.baseUrl: auto` the generated panel calls the origin it was served from instead, which is right when one host serves both the panel and `/api`. `auto` ignores `BEAK_API_BASE_URL`. If you change `PORT` and the panel and API sit on separate origins, change the compiled origin to match, or the browser meets a refused connection.

## Rules and limits

| Rule | Consequence |
| --- | --- |
| Configuration is read once at startup | Changing a variable needs a restart. Nothing reloads. |
| `BeakBackendConfig` knows only `DATABASE_URL`, `PORT` and `HOST` | Storage and auth read their own slices, so a server that never selects `s3` is never asked for S3 credentials. |
| The panel has no runtime environment | Anything the browser needs is compiled in. Never put a secret in a `--dart-define`: it ships in the JavaScript. |
| `.env` is not read from another working directory | Start the process from the project directory, or set real variables. |
| Values in a container come from its environment only | `.dockerignore` keeps `.env` out of the image, and `env_file` or `-e` supplies the variables at run time. |
| Application settings are yours | Read them from `defaults.environment` in `lib/server.dart`, not from `Platform.environment`, so a test that injects an environment injects them too. |

Keep secrets out of the repository. `.env` is git-ignored here and your project needs the same line; a committed `.env.example` documents the keys without the values.

## Verify it

Boot with a wrong value and read the message. Each of these fails before the server binds a port, prints one line and exits with code 78:

```console
$ PORT=abc ./build/serve/bundle/bin/serve
error: PORT must be an integer between 1 and 65535, got "abc".
$ BEAK_STORAGE_DRIVER=local ./build/serve/bundle/bin/serve
error: BEAK_LOCAL_ROOT_DIR is required when BEAK_STORAGE_DRIVER=local.
```

A driver name that does not exist fails the same way and lists the five that do.

`beak doctor` reports which database it will use when `DATABASE_URL` is unset (the default SQLite file), and checks the generated files against your schema.

## Reference

- [Configuration and environment](../reference/configuration.md) has the field-by-field tables for `BeakBackendConfig` and the storage configs.
- [beak.yaml](../reference/beak-yaml.md) documents `api.baseUrl` and `server:`.
- `packages/beak_backend/lib/src/config/`, `packages/beak_backend/lib/src/server/beak_storage_settings.dart` and `beak_serve_host.dart` are the code behind this page.

## Continue reading

- [Going to production](going-to-production.md) where these variables land in the deployment files.
- [Security](security.md) secrets, CORS and the auth settings the environment cannot supply.
- [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md) what the storage variables drive.
