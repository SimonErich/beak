---
title: Environment and config
description: The .env surface a Beak backend reads, how the real environment wins over the file, and the port split between the two demo apps.
---

# Environment and config

A Beak backend configures itself from environment variables: a `.env` file for local defaults, overlaid by the real process environment for deployment. This page is the map of that surface.

## The `.env` surface

Every variable below is read at startup. `DATABASE_URL` is the only one that is required; the rest have defaults or turn a feature off when absent.

| Variable | What it sets | Read by | Default |
| --- | --- | --- | --- |
| `DATABASE_URL` | Postgres connection URL (credentials included). | `BeakBackendConfig.fromEnv` | required |
| `PORT` | HTTP listen port (1 to 65535). | `BeakBackendConfig.fromEnv` | `8080` |
| `HOST` | Interface the server binds. | `BeakBackendConfig.fromEnv` | `0.0.0.0` |
| `BEAK_STORAGE_DRIVER` | `s3`, `memory`, or unset (uploads off). | the app's storage wiring | unset |
| `BEAK_S3_ENDPOINT` | S3 / MinIO endpoint URL. | the app's storage wiring | required when driver is `s3` |
| `BEAK_S3_BUCKET` | Bucket for uploaded files. | the app's storage wiring | required when driver is `s3` |
| `BEAK_S3_ACCESS_KEY` | S3 access key. | the app's storage wiring | required when driver is `s3` |
| `BEAK_S3_SECRET_KEY` | S3 secret key. | the app's storage wiring | required when driver is `s3` |
| `BEAK_S3_REGION` | S3 region. | the app's storage wiring | required when driver is `s3` |
| `BEAK_S3_USE_PATH_STYLE` | `true` for path-style URLs (MinIO wants this). | the app's storage wiring | `false` |
| `BEAK_AUTH_SECRET` | Secret that signs and verifies auth tokens. | the auth layer, when you wire it | required when auth is on |

The committed root `.env.example` shows the shape you copy for local development:

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

The reference numbers here (host port `25432` for Postgres, `29000` for MinIO) come from the dev stack, which remaps its host ports to avoid colliding with default installs. See [Dev infrastructure](dev-infrastructure.md) for why.

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

`loadFile` returns an empty map when the file is missing, so a `.env` is optional everywhere. Secrets never belong in a committed file: `.env` is git-ignored, and the committed `.env.example` documents the keys without the values.

## What `BeakBackendConfig` reads

The resolved map feeds straight into `BeakBackendConfig.fromEnv`, which is the only thing that reads `DATABASE_URL`, `PORT`, and `HOST`. It validates each one and throws a `BeakConfigurationException` on anything missing or malformed, so a misconfigured server fails loudly at boot instead of halfway through a request.

```dart title="apps/reference_admin_server/bin/reference_admin_server.dart"
final Map<String, String> environment = BeakEnv.resolve();
final config = BeakBackendConfig.fromEnv(environment: environment);
```

Its defaults are constants on the class:

```dart title="packages/beak_backend/lib/src/config/beak_backend_config.dart"
/// The port the server listens on when `PORT` is unset.
static const int defaultPort = 8080;

/// The interface the server binds when `HOST` is unset.
static const String defaultHost = '0.0.0.0';
```

Binding `0.0.0.0` by default is what makes the container reachable: inside Docker the server has to listen on every interface, not just loopback.

## Storage and auth read the rest

`BeakBackendConfig` deliberately does not know about storage or auth. The `BEAK_STORAGE_DRIVER` and `BEAK_S3_*` variables are consumed by the app's own storage wiring, which turns them into a `BeakStorageConfig` and resolves a driver (or `null` to serve without uploads). `BEAK_AUTH_SECRET` is consumed by the auth layer when you wire authentication in. This keeps each concern reading its own slice of the environment, and it means a server with uploads off never demands S3 credentials.

!!! note "The exhaustive tables live in Reference"
    This page is the deployment-shaped view. Every field on `BeakBackendConfig`, `BeakS3Config`, and the panel config, with types and validation, is in [Configuration options](../reference/configuration-options.md).

## The port split: 8080 and 8180

Two demo apps, two ports, and the reason is mundane.

- **`reference_admin_server`** takes the framework default, `8080`. Its panel's `apiBaseUrl` defaults to `http://localhost:8080`.
- **`beak_superdashboard`** forces `8180`, which is also what the root `.env.example` sets via `PORT=8180`. Ports 8080 to 8082 are commonly taken by Serverpod-style stacks on a dev machine, so the showcase steps aside.

The number that matters is the one the server actually listens on. If you change `PORT`, change the panel's `apiBaseUrl` to match, or the browser hits connection-refused.

## The panel's `apiBaseUrl`

The panel is a Flutter web app, so it has no environment at runtime: whatever origin it should call is baked in at build time. The reference panel takes it as a parameter with a default.

```dart title="apps/reference_admin/lib/main.dart"
BeakPanelConfig buildReferencePanelConfig({
  String apiBaseUrl = 'http://localhost:8080',
}) => BeakPanelConfig(
  title: 'Beak Admin',
  apiBaseUrl: apiBaseUrl,
  // resources, dashboard, ...
);
```

The superdashboard is identical but defaults to `http://localhost:8180`. For a real remote deploy, pass your API origin before you build the web image. There is no runtime override once the bundle is compiled.

## Continue reading

- [Configuration options](../reference/configuration-options.md) the exhaustive field-by-field tables.
- [Running the server](../backend/running-the-server.md) how the config becomes a live server.
- [Going to production](going-to-production.md) where these variables land in `.env.prod`.
- [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md) what the `BEAK_S3_*` variables drive.
