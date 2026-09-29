---
title: Configuration and environment
description: Every environment variable, override file, backend config type and storage setting of a Beak app, with defaults and the code that reads them.
type: reference
audience: [expert, agent]
status: stable
search: {boost: 2}
---

# Configuration and environment

A Beak app is configured in five places, and none of them reads another's keys. This page lists the environment, the override files, the typed backend configuration and the storage configs, each with its default and the code that reads it, plus a one-line index of the `beak.yaml` keys.

## Import

```dart
import 'package:beak/server.dart';
```

`package:beak/server.dart` exports `BeakBackendConfig`, `BeakEnv`, `BeakStorageSettings`, `BeakServeHost`, `BeakServerDefaults`, `BeakServer` and the storage wiring, and re-exports `package:beak/beak.dart` with the storage configs (`BeakS3Config`, `BeakFtpConfig`, `BeakLocalDiskStorageConfig`, `BeakMemoryStorageConfig`). It reaches `dart:io` and database drivers, so panel code never imports it. Panel configuration (`BeakPanel`, `BeakPanelConfig`) is in [Panel and resource options](panel-options.md).

## Summary

| Where | Read when | Holds | Reference |
| --- | --- | --- | --- |
| `beak.yaml` | `beak prepare` runs | Panel title, API origin, default server port and host, panel entrypoint, agent files, sidebar, default resource presentation | [Project file keys](#project-file-keys) |
| The environment and `.env` | The server boots | Database URL, port, host, storage driver and credentials | [Environment variables](#environment-variables) |
| Override files under `lib/` | The app compiles | Anything holding a symbol or a closure: panel config, themes, auth, server policy and middleware | [Override files](#override-files) |
| `--dart-define` | The panel is built | The API origin | [The panel build](#the-panel-build) |
| `lib/beak/*.g.dart` | Never by hand | The typed objects the four above produce | [Generated files](generated-files.md) |

All variables at a glance:

| Variable | Default | Read by |
| --- | --- | --- |
| `DATABASE_URL` | `sqlite:beak.db` | `BeakBackendConfig.fromEnv` |
| `PORT` | `8080` | `BeakBackendConfig.fromEnv` |
| `HOST` | `0.0.0.0` | `BeakBackendConfig.fromEnv` |
| `WORM_ENV` | `development` | worm: migrations, seeders and the `--force` guard |
| `BEAK_STORAGE_DRIVER` | local disk under `storage/uploads` | `BeakStorageSettings.fromEnv` |
| `BEAK_S3_*` (6) | none | `BeakStorageSettings.fromEnv`, with `s3` |
| `BEAK_FTP_*` (6) | none, port `21` | `BeakStorageSettings.fromEnv`, with `ftp` |
| `BEAK_LOCAL_*` (2) | none | `BeakStorageSettings.fromEnv`, with `local` |
| `BEAK_API_BASE_URL` | `http://localhost:8080` | the panel, as a compile-time define, not an environment variable |

## Environment variables

The server reads its environment once, at startup, through `BeakEnv.resolve()`. `BeakBackendConfig.fromEnv` validates the first three variables and throws a `BeakConfigurationException` naming the problem on anything malformed. `BeakStorageSettings.fromEnv` reads the storage variables.

### The server

| Variable | Required | Default | Meaning |
| --- | --- | --- | --- |
| `DATABASE_URL` | no | `sqlite:beak.db` | The database. An absolute URL with a scheme; every scheme except `sqlite:` and `file:` must also have a host |
| `PORT` | no | `8080` | The listening port, an integer from 1 to 65535. `beak.yaml` `server.port` sets a default for it |
| `HOST` | no | `0.0.0.0` | The interface to bind, not empty. `beak.yaml` `server.host` sets a default for it |
| `WORM_ENV` | no | `development` | `development`, `staging`, `production` or `testing`, case-insensitive. Selects which seeders apply, and `production` makes `migrate fresh` and `migrate refresh` require `--force` |

`DATABASE_URL` forms:

| URL | Database |
| --- | --- |
| `sqlite:beak.db`, `file:beak.db` | A SQLite file beside the process. The default, so a new project needs no Docker and no credentials |
| `sqlite:///abs/path/beak.db` | A SQLite file at an absolute path |
| `sqlite::memory:` | In-memory SQLite. Vanishes with the process. `serve()` applies the migrations and seeders itself, because `beak migrate` is another process |
| `postgres://user:pass@host:5432/db`, `postgresql://...` | Postgres. The port defaults to 5432, `?sslmode=require` turns TLS on, credentials are URL-decoded, the pool holds up to 10 connections |

Anything else is a `BeakConfigurationException`. `WORM_ENV` is read from the process environment only. A `WORM_ENV` line in `.env` does not reach worm, though `beak migrate fresh` and `refresh` read it there for their `--force` guard.

```dart title="packages/beak_backend/lib/src/data/worm/worm_bootstrap.dart"
--8<-- "packages/beak_backend/lib/src/data/worm/worm_bootstrap.dart:adapterFromUrl"
```

### Storage

`BEAK_STORAGE_DRIVER` selects a driver and the other variables configure it. Unset, the server uses local disk under `storage/uploads`, served by the server itself at `/uploads`, so an upload column works on a fresh project. `none` turns the upload routes off. Any other value throws at boot and names the supported ones.

```dart title="packages/beak_backend/lib/src/server/beak_storage_settings.dart"
--8<-- "packages/beak_backend/lib/src/server/beak_storage_settings.dart:supportedDrivers"
```

| Variable | With driver | Required | Default | Meaning |
| --- | --- | --- | --- | --- |
| `BEAK_STORAGE_DRIVER` | all | no | local disk under `storage/uploads` | `s3`, `ftp`, `local`, `memory` or `none` |
| `BEAK_S3_ENDPOINT` | `s3` | yes | none | The S3 endpoint, an AWS host or a MinIO URL |
| `BEAK_S3_BUCKET` | `s3` | yes | none | The bucket uploads land in |
| `BEAK_S3_ACCESS_KEY` | `s3` | yes | none | Access key id. A secret |
| `BEAK_S3_SECRET_KEY` | `s3` | yes | none | Secret access key. A secret |
| `BEAK_S3_REGION` | `s3` | yes | none | The bucket region, for example `eu-central-1` |
| `BEAK_S3_USE_PATH_STYLE` | `s3` | no | `false` | Exactly `true` selects path-style addressing (`endpoint/bucket/key`), which MinIO needs. Any other value is `false` |
| `BEAK_S3_PUBLIC_BASE_URL` | `s3` | no | none | The address files are served from, for a CDN or proxy in front of the bucket. Unset or empty, file URLs are built from `BEAK_S3_ENDPOINT` |
| `BEAK_FTP_HOST` | `ftp` | yes | none | The FTP host |
| `BEAK_FTP_USER` | `ftp` | yes | none | Login user |
| `BEAK_FTP_PASSWORD` | `ftp` | yes | none | Login password. A secret |
| `BEAK_FTP_BASE_DIR` | `ftp` | yes | none | The remote directory uploads are stored under |
| `BEAK_FTP_PUBLIC_BASE_URL` | `ftp` | yes | none | The base URL stored files are served from |
| `BEAK_FTP_PORT` | `ftp` | no | `21` | The FTP port. A value that is not an integer is `21` |
| `BEAK_LOCAL_ROOT_DIR` | `local` | yes | none | The directory files are written under |
| `BEAK_LOCAL_PUBLIC_BASE_URL` | `local` | yes | none | The URL prefix files are served from. Beak mounts a read-only route at its path, see [REST API](rest-api.md#local-files) |

A missing required variable throws `<KEY> is required when BEAK_STORAGE_DRIVER=<driver>.` at boot. A driver that is selected but not registered fails at boot, naming the drivers that are: `beak_backend` depends on no driver package, so `s3` needs `beak_storage_s3` and a `beakStorageRegistry()` function in `lib/server.dart`, see [Storage registry](#storage-registry). The `memory` and `local` drivers are in the box.

### How `.env` resolves

`BeakEnv.resolve` overlays the `.env` file with the real process environment, and real variables always win. A deployment configures itself with real variables and never needs the file.

```dart title="packages/beak_backend/lib/src/config/env_loader.dart"
--8<-- "packages/beak_backend/lib/src/config/env_loader.dart:resolve"
```

`BeakEnv.parse` accepts `#` comments, blank lines, an optional `export ` prefix, whitespace around `=` and matching surrounding quotes, and splits on the first `=` only. A line without `=` or with an invalid key throws `BeakConfigurationException`. A missing `.env` is not an error. `.env` is git-ignored by the scaffold; commit an `.env.example` instead, and keep secrets out of `beak.yaml`.

`beak introspect --save-url` writes `DATABASE_URL` into `.env`.

### Your own variables

A `lib/server.dart` override reads app-specific settings from `BeakServerDefaults.environment`, which is the same resolved map, and not from `Platform.environment`. A test that injects an environment into `BeakServeHost` then injects it into your policy and auth as well.

### The panel build

The panel is a compiled Flutter app and has no environment. Its API origin is a compile-time define:

```bash
flutter build web --dart-define=BEAK_API_BASE_URL=https://api.example.com
```

The generated panel reads `api.baseUrl` from `beak.yaml` as the default of that define. `api.baseUrl: auto` uses the origin the panel was served from and ignores the define. `BeakPanel(apiBaseUrl:)` has the same default in an authored panel.

## Project file keys

`beak.yaml` is read by the CLI at generate time and never at runtime. Its keys, in one line each; [beak.yaml](beak-yaml.md) has the defaults, the errors and what each way of booting does with them.

| Key | Effect |
| --- | --- |
| `name` | The panel title |
| `api.baseUrl` | The default of the `BEAK_API_BASE_URL` compile-time define, or `auto` for the serving origin |
| `server.port`, `server.host` | Defaults for `PORT` and `HOST` in the generated host. A real variable wins |
| `panel.entrypoint` | The Dart file that boots the panel in an app that keeps its own `lib/main.dart`. `prepare` then never writes `lib/main.dart`, `dev` prints `flutter run -t <file>`, and `doctor` checks that file |
| `agents.instructions`, `agents.docs`, `agents.skills` | Which `AGENTS.md` files, docs copy and skill folders `prepare` and `beak agents` may write |
| `theme.sidebar.collapsible`, `theme.sidebar.startCollapsed` | Sidebar behaviour |
| `resources.<table>.icon`, `.label`, `.section`, `.hidden` | Presentation of the default resource of a model that has no `BeakResource` class |

## Override files

Each is optional, found by file name and function name, and wired in by `beak prepare`. `beak eject <target>` writes a starter that returns Beak's default.

| File | Function | Read by | Purpose |
| --- | --- | --- | --- |
| `lib/panel.dart` | `BeakPanelConfig beakPanel(BeakPanelConfig defaults)` | `panel.g.dart` | The last word on the panel config |
| `lib/theme.dart` | `OiThemeData beakLightTheme()`, `OiThemeData beakDarkTheme()` | `panel.g.dart` | Light and dark theme |
| `lib/auth.dart` | `BeakAuthConfig beakAuth()` | `panel.g.dart` | Sign-in routes and adapter |
| `lib/server.dart` | `BeakServer beakServer(BeakServerDefaults defaults)` | `server.g.dart` | Policy, sessions, middleware, routes, graph rules, outbox |
| `lib/server.dart` | `BeakStorageRegistry beakStorageRegistry()` | `server.g.dart` | Extra storage drivers, independent of `beakServer` |

```dart title="packages/beak_cli/lib/src/project/beak_discovery.dart"
--8<-- "packages/beak_cli/lib/src/project/beak_discovery.dart:beakOverrideKind"
```

An authored `lib/main.dart` calls the first three only if its text does: `beak eject main` writes the call for each of those files that exists at that moment, and later ones you add by hand. The server files apply to both bootstraps.

### BeakServerDefaults

The argument of `beakServer`: everything `BeakServeHost` resolved.

| Field | Type | Meaning |
| --- | --- | --- |
| `config` | `BeakBackendConfig` | Database URL, host and port |
| `registry` | `BeakModelRegistry` | Every model the project registered |
| `dataSource` | `WormDataSource` | The data source, over the database connection |
| `storage` | `BeakStorageDriver?` | The resolved upload driver, `null` when uploads are off |
| `environment` | `Map<String, String>` | The resolved environment, `.env` included |
| `now` | `DateTime Function()?` | The host's clock, `null` for `DateTime.now` |

`defaults.build(...)` returns the standard server. Every argument is optional; each is documented on `BeakServer.new`.

| Parameter | Type | Default | Purpose |
| --- | --- | --- | --- |
| `policy` | `BeakPolicy` | `BeakAllowAllPolicy()` | Who may do what; see [Auth and policies](../backend/auth-and-policies.md) |
| `authSessions` | `BeakAuthSessions?` | `null` | Mounts `POST /api/auth/login`, `/logout` and `GET /api/auth/me` and guards requests by their sessions |
| `authGuard` | `BeakAuthGuard?` | sessions' store guard, else none | Identifies callers some other way |
| `middleware` | `List<Middleware>` | `[]` | Shelf middleware, after authentication and inside the error mapping |
| `routes` | `Handler?` | `null` | Extra endpoints, tried before the generated API |
| `corsOrigin` | `String` | `*` | The origin browsers may call from |
| `onRequest` | `BeakRequestLogger?` | one line per request to stderr | Request log |
| `onUnexpectedError` | `BeakUnexpectedErrorListener?` | error and stack to stderr | Every failure no typed exception describes |
| `preparePlan` | `BeakSavePlanPreparer?` | `null` | Transactional business rules for a graph commit |
| `finalizePlan` | `BeakSavePlanFinalizer?` | `null` | Enqueues durable effects in the commit's transaction |
| `graphOnly` | `List<BeakModel>` | `[]` | Models whose per-record write routes are closed |
| `outbox` | `BeakOutboxSchedule?` | `null` | Delivers the effects `finalizePlan` enqueued while the host serves |
| `generateId` | `String Function()?` | UUID v4 | The id mint behind every write |
| `transformRunner` | `BeakTransformRunner?` | the `beak_image` runner | The image pipeline behind image uploads |

`build` takes `storage:` and `dataSource:` too, which replace what the host resolved. A driver from a package goes through `beakStorageRegistry()` and `BEAK_STORAGE_DRIVER`; a driver you built yourself or a custom data source goes straight into `build`.

The default policy allows everything and the default CORS origin is `*`. Set a policy before exposing the server.

```dart title="examples/clean_beak_config/lib/server.dart"
/// Adds the example's transactional shop invariants to the generated host.
BeakServer beakServer(BeakServerDefaults defaults) => defaults.build(
  preparePlan: ShopGraphPreparer(defaults.registry).prepare,
```

### Storage registry

```dart title="packages/beak_backend/lib/src/server/storage_wiring.dart"
--8<-- "packages/beak_backend/lib/src/server/storage_wiring.dart:createDefaultStorageRegistry"
```

`beakStorageRegistry()` returns the registry `BeakServeHost` resolves the selected driver from. Register a driver package on top of the default one:

```dart
// Illustrative: the shape of the function, with real names.
BeakStorageRegistry beakStorageRegistry() {
  final registry = createDefaultStorageRegistry();
  registerS3Storage(registry); // from package:beak_storage_s3
  return registry;
}
```

`registerS3Storage(registry)` and `registerFtpStorage(registry)` (from `beak_storage_ftp`) each add one factory to the registry passed in, and registering an id twice throws. See [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md) and [Custom storage drivers](../extending/custom-storage-drivers.md).

## BeakBackendConfig

The typed, validated runtime configuration. The generated host builds it from the environment; construct it by hand only in tests or when embedding. Its `toString` redacts the database credentials, so it is safe to log.

```dart title="packages/beak_backend/lib/src/config/beak_backend_config.dart"
--8<-- "packages/beak_backend/lib/src/config/beak_backend_config.dart:BeakBackendConfig"
```

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `databaseUrl` | `Uri` | required | The connection URL, credentials included |
| `port` | `int` | `8080` | The listening port |
| `host` | `String` | `0.0.0.0` | The bound interface |

| Static | Value |
| --- | --- |
| `BeakBackendConfig.defaultDatabaseUrl` | `sqlite:beak.db` |
| `BeakBackendConfig.defaultPort` | `8080` |
| `BeakBackendConfig.defaultHost` | `0.0.0.0` |

`BeakBackendConfig.fromEnv({Map<String, String>? environment})` reads `DATABASE_URL`, `PORT` and `HOST`; without an argument it reads `Platform.environment` and not `.env`, so pass `BeakEnv.resolve()`.

## BeakServeHost

The server's lifecycle in one object: environment to config to database adapter to registry to a running server. `beak prepare` writes `beakHost()` into `lib/beak/server.g.dart`; you do not construct it.

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `registry` | `BeakModelRegistry` | required | Every model served |
| `migrations` | `List<Migration>` | `[]` | Run by `beak migrate`; applied by `serve()` on in-memory SQLite |
| `seeders` | `List<Seeder>` | `[]` | Run by `beak seed`; run by `serve()` on in-memory SQLite |
| `storageRegistry` | `BeakStorageRegistry Function()?` | in-box drivers | Adds plug-in drivers |
| `configure` | `BeakServerCustomizer?` | `defaults.build()` | Your `beakServer` |
| `environment` | `Map<String, String>?` | `BeakEnv.resolve()` | The environment, injected in tests |
| `now` | `DateTime Function()?` | `DateTime.now` | The clock |

| Member | Meaning |
| --- | --- |
| `config` | The `BeakBackendConfig` resolved from `environment` |
| `resolveStorageDriver()` | The driver the environment selects, `null` for `none`, local disk when unset |
| `buildServer({adapter, storage})` | The server over an adapter without binding a port; the test seam |
| `serve()` | Connects the database, builds the server, binds the listener and starts the outbox loop. Never migrates a file or Postgres database |
| `runCli(args)` | The worm CLI (`migrate`, `db:seed`, and so on) over this host, which `bin/migrate.dart` calls |

```dart title="packages/beak_backend/lib/src/server/beak_serve_host.dart"
--8<-- "packages/beak_backend/lib/src/server/beak_serve_host.dart:resolveStorageDriver"
```

## Storage configs

`BEAK_STORAGE_DRIVER` selects one of the sealed `BeakStorageConfig` variants. Each is plain data that the matching driver consumes; `beak_core` owns them, so an app configures storage without importing a driver package. Configs with secrets redact them in `toString`.

### BeakS3Config

For AWS S3, MinIO and other S3-compatible stores. Consumed by `beak_storage_s3`.

```dart title="packages/beak_core/lib/src/storage/drivers/beak_s3_config.dart"
--8<-- "packages/beak_core/lib/src/storage/drivers/beak_s3_config.dart:BeakS3Config"
```

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `endpoint` | `Uri` | required | The S3 API endpoint |
| `bucket` | `String` | required | The bucket |
| `accessKey` | `String` | required | Access key id, redacted |
| `secretKey` | `String` | required | Secret access key, redacted |
| `region` | `String` | required | The bucket region |
| `usePathStyle` | `bool` | `false` | Path-style addressing |
| `publicBaseUrl` | `Uri?` | `null` | Replaces driver-generated file URLs, for a CDN in front of the bucket |

### BeakFtpConfig

Consumed by `beak_storage_ftp`.

```dart title="packages/beak_core/lib/src/storage/drivers/beak_ftp_config.dart"
--8<-- "packages/beak_core/lib/src/storage/drivers/beak_ftp_config.dart:BeakFtpConfig"
```

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `host` | `String` | required | FTP host |
| `port` | `int` | `21` | FTP port |
| `user` | `String` | required | Login user |
| `password` | `String` | required | Login password, redacted |
| `baseDir` | `String` | required | The remote directory |
| `publicBaseUrl` | `Uri` | required | The base URL files are served from |

### BeakLocalDiskStorageConfig

Files land in a directory this server then serves. Registered by `createDefaultStorageRegistry()`, no package needed.

```dart title="packages/beak_core/lib/src/storage/drivers/beak_local_disk_storage_config.dart"
--8<-- "packages/beak_core/lib/src/storage/drivers/beak_local_disk_storage_config.dart:BeakLocalDiskStorageConfig"
```

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `rootDir` | `String` | required | Where files are written |
| `publicBaseUrl` | `Uri` | required | The URL `rootDir` is served from |

### BeakMemoryStorageConfig

Holds uploads in memory and takes no fields. For tests: `BEAK_STORAGE_DRIVER=memory` or `const BeakMemoryStorageConfig()`. It is registered by `BeakStorageRegistry` itself.

## Rules and limits

- Real environment variables beat `.env`, which beats `beak.yaml` defaults (`server.port`, `server.host`).
- Nothing in `beak.yaml` reaches the server except the two `server` defaults.
- Configuration errors are `BeakConfigurationException` (HTTP `500`, code `configuration`) and stop the boot; see [Exceptions](exceptions.md).
- `BeakBackendConfig.toString` and the storage configs redact secrets.
- The Postgres pool size (10) is not configurable from the environment.
- `WORM_ENV` comes from the process environment. `.env` does not set it.
- Configuration is read once at boot. Changing a variable needs a restart.

## Source

- `packages/beak_backend/lib/src/config/beak_backend_config.dart` and `env_loader.dart` hold `BeakBackendConfig` and `BeakEnv`.
- `packages/beak_backend/lib/src/server/beak_storage_settings.dart`, `storage_wiring.dart`, `beak_serve_host.dart` and `beak_server.dart` hold the storage variables, the registry, the host and `BeakServer`.
- `packages/beak_backend/lib/src/data/worm/worm_bootstrap.dart` maps `DATABASE_URL` onto an adapter.
- `packages/beak_core/lib/src/storage/drivers/` holds the storage configs.
- `packages/beak_cli/lib/src/project/beak_discovery.dart` finds the override files.
- `examples/clean_beak_config/lib/server.dart` is a real `beakServer`.

## Continue reading

- [beak.yaml](beak-yaml.md) the project file that sits beside these.
- [Panel and resource options](panel-options.md) the panel side: `BeakPanel`, `BeakPanelConfig`, `BeakResource`.
- [Environment and config](../shipping/environment-and-config.md) the deployment side of these variables.
- [Running the server](../backend/running-the-server.md) how the host, the middleware and the routes fit together.
