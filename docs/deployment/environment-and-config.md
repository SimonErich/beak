---
title: Environment and config
description: The environment variables a Beak backend reads, how the real environment wins over the .env file, and where the panel's API origin comes from instead.
---

# Environment and config

A Beak backend configures itself from environment variables: a `.env` file for local defaults, overlaid by the real process environment for deployment. This page is the map of that surface, and of the one thing that is deliberately not on it, the panel's API origin.

## The environment surface

Every variable below is read at startup. **None of them is required.** A project that sets nothing runs on a SQLite file, with uploads on local disk beside it, which is exactly what the first `beak dev` should do.

| Variable | What it sets | Read by | Default |
| --- | --- | --- | --- |
| `DATABASE_URL` | Database connection URL. `sqlite:` or `file:` opens SQLite, anything else is Postgres. | `BeakBackendConfig.fromEnv` | `sqlite:beak.db` |
| `PORT` | HTTP listen port (1 to 65535). | `BeakBackendConfig.fromEnv` | `8080` |
| `HOST` | Interface the server binds. | `BeakBackendConfig.fromEnv` | `0.0.0.0` |
| `BEAK_STORAGE_DRIVER` | `s3`, `ftp`, `local`, `memory`, or `none` (no upload endpoints at all). | `BeakStorageSettings.fromEnv` | unset: local disk under `storage/uploads` |
| `BEAK_S3_ENDPOINT` | S3 / MinIO endpoint URL. | `BeakStorageSettings.fromEnv` | required when the driver is `s3` |
| `BEAK_S3_BUCKET` | Bucket for uploaded files. | `BeakStorageSettings.fromEnv` | required when the driver is `s3` |
| `BEAK_S3_ACCESS_KEY` | S3 access key. | `BeakStorageSettings.fromEnv` | required when the driver is `s3` |
| `BEAK_S3_SECRET_KEY` | S3 secret key. | `BeakStorageSettings.fromEnv` | required when the driver is `s3` |
| `BEAK_S3_REGION` | S3 region. | `BeakStorageSettings.fromEnv` | required when the driver is `s3` |
| `BEAK_S3_USE_PATH_STYLE` | `true` for path-style URLs (MinIO wants this). | `BeakStorageSettings.fromEnv` | `false` |
| `BEAK_LOCAL_ROOT_DIR` | Directory uploaded files are written to. | `BeakStorageSettings.fromEnv` | required when the driver is `local` |
| `BEAK_LOCAL_PUBLIC_BASE_URL` | The URL those files are served from. | `BeakStorageSettings.fromEnv` | required when the driver is `local` |
| `BEAK_FTP_HOST`, `BEAK_FTP_USER`, `BEAK_FTP_PASSWORD`, `BEAK_FTP_BASE_DIR`, `BEAK_FTP_PUBLIC_BASE_URL` | The FTP driver's connection and public base. | `BeakStorageSettings.fromEnv` | required when the driver is `ftp` |
| `BEAK_FTP_PORT` | FTP port. | `BeakStorageSettings.fromEnv` | `21` |

A driver selected without the settings it needs fails at boot with a `BeakConfigurationException` naming the missing variable, and an unrecognised driver name fails with the list of the ones that exist. A typo in `.env` is a startup error carrying its own fix, not a broken upload three screens later.

Unset is not "off". It is the same posture as the database: `BeakServeHost` falls back to `BeakLocalDiskStorageDriver` rooted at `storage/uploads` and serves those files itself at `/uploads`, so an upload column works on a fresh project with no setup. `BEAK_STORAGE_DRIVER=none` is how a deployment turns the upload endpoints off outright.

Application-specific secrets and feature flags are read by the application's
`lib/server.dart` from `defaults.environment`. They are not automatically defined
or secured by Beak's built-in environment loader. Configure production secrets
through the deployment's secret store.

## The zero-config default

`DATABASE_URL` is optional, and the default is a file:

```dart title="packages/beak_backend/lib/src/config/beak_backend_config.dart"
/// The database a project gets when it names none.
///
/// A file beside the project, so the very first `beak dev` needs no Docker,
/// no credentials and no `.env`. Requiring a database to see anything at all
/// loses more first-time users than any other step.
static const String defaultDatabaseUrl = 'sqlite:beak.db';
```

The scheme is what picks the driver, in one place, so `beak dev`, the migration CLI and a hand-built server cannot disagree about what `DATABASE_URL` means. `sqlite:beak.db` is a file beside the process, `sqlite::memory:` is a database that vanishes with it (what a test wants), and anything else is Postgres.

Switching to Postgres is one line in the environment:

```bash
DATABASE_URL=postgres://user:pass@host:5432/beak
```

## How the environment resolves

`BeakEnv.resolve` reads the `.env` file, then overlays the real process environment on top, so an exported variable always beats a file value. That single rule is what lets the same build run locally off a file and in production off the container environment, with no file at all.

```dart title="packages/beak_backend/lib/src/config/env_loader.dart"
/// The effective environment: the dotenv file at [filePath] overlaid by
/// [processEnvironment] (defaults to [Platform.environment]), so real
/// environment variables always win over file values.
static Map<String, String> resolve({
  String filePath = '.env',
  Map<String, String>? processEnvironment,
}) => {...loadFile(filePath), ...processEnvironment ?? Platform.environment};
```

`loadFile` returns an empty map when the file is missing, so a `.env` is optional everywhere. Secrets never belong in a committed file: `.env` is git-ignored, and a committed `.env.example` documents the keys without the values.

## What `BeakBackendConfig` reads

The resolved map feeds into `BeakBackendConfig.fromEnv`, which is the only thing that reads `DATABASE_URL`, `PORT`, and `HOST`. It validates each one and throws a `BeakConfigurationException` on anything malformed, so a misconfigured server fails loudly at boot instead of halfway through a request.

You never call it. `BeakServeHost`, which the generated `lib/beak/server.g.dart` builds, resolves the environment once and holds the result:

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

That `environment` parameter is the test seam. The generated `beakHost({Map<String, String>? environment})` passes it straight through, which is how a suite points the real host at `sqlite::memory:` and a temporary upload directory without touching the machine it runs on.

Its defaults are constants on the config class:

```dart title="packages/beak_backend/lib/src/config/beak_backend_config.dart"
/// The port the server listens on when `PORT` is unset.
static const int defaultPort = 8080;

/// The interface the server binds when `HOST` is unset.
static const String defaultHost = '0.0.0.0';
```

Binding `0.0.0.0` by default is what makes the container reachable: inside Docker the server has to listen on every interface, not just loopback.

## Where the port is decided

Three places, in order of who wins.

1. **Beak's default**, `8080`.
2. **`beak.yaml`**, under `server:`. `beak prepare` bakes it into the generated host as a default. Use it when a project needs a fixed development port different from 8080.
3. **The real `PORT`**, which beats both. Where a process binds is a deployment's decision, not a repository's.

For example, `server.port: 8180` selects a different generated default.
The real process `PORT` still takes precedence.

## The panel's API origin

The panel is a Flutter web app, so it has no environment at runtime: whatever origin it should call is compiled in. That decision lives in `beak.yaml`, not in `.env`.

```yaml title="examples/clean_beak_config/beak.yaml"
api:
  baseUrl: http://localhost:8080
```

`beak prepare` turns that into a compile-time default in the generated panel config:

```dart title="examples/clean_beak_config/lib/beak/panel.g.dart"
    apiBaseUrl: const String.fromEnvironment(
      'BEAK_API_BASE_URL',
      defaultValue: 'http://localhost:8080',
    ),
```

So one build can point somewhere else without editing the file:

```bash
flutter build web --dart-define=BEAK_API_BASE_URL=https://api.example.com
```

Set `baseUrl: auto` and the generated expression resolves to the origin the panel was served from instead, which is what a deployment fronting both halves behind one host wants.

The number that matters is the one the server actually listens on. If you change `PORT`, change `api.baseUrl` (or pass the `--dart-define`) to match, or the browser hits connection-refused.

## Storage and auth read the rest

`BeakBackendConfig` deliberately does not know about storage or auth. The `BEAK_STORAGE_DRIVER` and the driver-specific variables are consumed by `BeakStorageSettings.fromEnv`, which turns them into a `BeakStorageConfig`; `BeakServeHost.resolveStorageDriver` then resolves that config to a driver, falling back to local disk when nothing is named and to `null` when the name is `none`. Which drivers can be resolved at all is your project's choice: `beak_backend` depends on no driver package, so an app that uploads to S3 declares `beak_storage_s3` and registers it in `lib/server.dart`. Auth is the same shape, read by the code you wrote. Each concern reads its own slice of the environment, and a server that never names `s3` is never asked for S3 credentials.

!!! note "The exhaustive tables live in Reference"
    This page is the deployment-shaped view. Every field on `BeakBackendConfig`, `BeakS3Config`, and the panel config, with types and validation, is in [Configuration options](../reference/configuration-options.md). Every `beak.yaml` key is in [beak.yaml](../reference/beak-yaml.md).

## Continue reading

- [beak.yaml](../reference/beak-yaml.md) the project file that decides the API origin, the port default, and the sidebar.
- [Configuration options](../reference/configuration-options.md) the exhaustive field-by-field tables.
- [Running the server](../backend/running-the-server.md) how the config becomes a live server.
- [Going to production](going-to-production.md) where these variables land in `.env.prod`.
- [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md) what the storage variables drive.
