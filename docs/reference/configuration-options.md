---
title: Configuration options
description: Every environment variable and every field of BeakBackendConfig, BeakPanelConfig, and the storage configs, with defaults.
---

# Configuration options

After this page you can configure a Beak app end to end: the environment variables
the backend reads at startup, every field of the backend and panel config objects,
and the storage configs those variables map to, each with its default.

Beak splits configuration in two. The backend reads a small set of environment
variables (a database URL, a port, storage credentials) and validates them into a
typed `BeakBackendConfig`. The panel takes a single `BeakPanelConfig` value, in
code, describing the whole UI. Neither reads config the other owns.

## A note on ports

Beak ships two demo apps, and they run on different ports. Keep the frontend's
`apiBaseUrl` pointed at the matching backend or you get connection-refused.

| App | Backend port | Frontend `apiBaseUrl` |
| --- | --- | --- |
| `reference_admin` (the tutorial store) | `8080` | `http://localhost:8080` |
| `beak_superdashboard` (the showcase) | `8180` | `http://localhost:8180` |

`BeakBackendConfig`'s built-in default port is `8080`. The committed root
`.env.example` sets `PORT=8180` because it configures the superdashboard demo
backend, whose port avoids the `8080`-`8082` range common stacks reach for first.

## Environment variables

`.env.example` documents the keys a Beak backend reads. Copy it to `.env` for
local development (the real `.env` is git-ignored; secrets never live in a
committed file).

```bash title=".env.example"
# The demo backend's HTTP port (8180 - 8080-8082 are commonly taken by Serverpod-style stacks).
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

Two groups of variables live here, read by two different pieces of code.

### Read by `BeakBackendConfig.fromEnv`

These configure the HTTP server itself. `BeakBackendConfig.fromEnv` validates them
and throws a `BeakConfigurationException` on anything missing or malformed.

| Variable | Required | Default | Meaning |
| --- | --- | --- | --- |
| `DATABASE_URL` | yes | none | The database connection URL. Must be an absolute URL with a scheme and host, e.g. `postgres://user:pass@host:5432/db`. |
| `PORT` | no | `8080` | The port the server listens on. An integer in `1`-`65535`. |
| `HOST` | no | `0.0.0.0` | The interface the server binds. Must not be empty. |

### Read by the app's storage wiring

These are not read by `beak_backend` core. The demo servers read
`BEAK_STORAGE_DRIVER` and, when it is `s3`, build a [`BeakS3Config`](#s3-beaks3config)
from the `BEAK_S3_*` variables. This is app code you own, so your own server can
read these keys differently.

```dart title="apps/reference_admin_server/lib/src/server_builder.dart"
BeakStorageConfig? referenceStorageConfig(Map<String, String> environment) {
  switch (environment['BEAK_STORAGE_DRIVER']) {
    case 's3':
      // ... require(...) throws when an s3 variable is missing
      return BeakS3Config(
        endpoint: Uri.parse(require('BEAK_S3_ENDPOINT')),
        bucket: require('BEAK_S3_BUCKET'),
        accessKey: require('BEAK_S3_ACCESS_KEY'),
        secretKey: require('BEAK_S3_SECRET_KEY'),
        region: require('BEAK_S3_REGION'),
        usePathStyle: environment['BEAK_S3_USE_PATH_STYLE'] == 'true',
      );
    case 'memory':
      return const BeakMemoryStorageConfig();
    case null || '':
      return null;
    case final String other:
      throw BeakConfigurationException(
        'Unsupported BEAK_STORAGE_DRIVER "$other" (use "s3" or "memory").',
      );
  }
}
```

| Variable | Required | Default | Meaning |
| --- | --- | --- | --- |
| `BEAK_STORAGE_DRIVER` | no | uploads off | `s3` builds an S3 config, `memory` selects the in-memory driver (tests), unset or empty disables uploads. Any other value throws. |
| `BEAK_S3_ENDPOINT` | with `s3` | none | The S3 API endpoint (AWS host or a MinIO URL). |
| `BEAK_S3_BUCKET` | with `s3` | none | The bucket uploads land in. |
| `BEAK_S3_ACCESS_KEY` | with `s3` | none | Access key id. A secret. |
| `BEAK_S3_SECRET_KEY` | with `s3` | none | Secret access key. A secret. |
| `BEAK_S3_REGION` | with `s3` | none | The bucket region, e.g. `us-east-1`. |
| `BEAK_S3_USE_PATH_STYLE` | no | `false` | `true` uses path-style addressing (`endpoint/bucket/key`), which MinIO requires. Any other value is `false`. |

### How `.env` resolves

`BeakEnv.resolve` overlays the `.env` file with the real process environment, so a
deployment configures itself through real environment variables and never needs a
file. Real environment variables always win over file values.

```dart title="packages/beak_backend/lib/src/config/env_loader.dart"
static Map<String, String> resolve({
  String filePath = '.env',
  Map<String, String>? processEnvironment,
}) => {...loadFile(filePath), ...processEnvironment ?? Platform.environment};
```

Feed the result straight into the backend config:

```dart
final config = BeakBackendConfig.fromEnv(environment: BeakEnv.resolve());
```

`BeakEnv.parse` handles comments (`#`), blank lines, an optional `export ` prefix,
whitespace around `=`, and matching surrounding quotes. A line without a separator,
or with an invalid key, throws a `BeakConfigurationException`.

## `BeakBackendConfig`

The typed, validated runtime configuration of a backend. Build it once at startup
and hand it to the server. Its `toString` redacts the database credentials, so it
is safe to log.

```dart title="packages/beak_backend/lib/src/config/beak_backend_config.dart"
const BeakBackendConfig({
  required this.databaseUrl,
  this.port = defaultPort,
  this.host = defaultHost,
});
```

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `databaseUrl` | `Uri` | required | The database connection URL, credentials included (redacted by `toString`). |
| `port` | `int` | `8080` (`defaultPort`) | The port the HTTP server listens on. |
| `host` | `String` | `0.0.0.0` (`defaultHost`) | The interface the HTTP server binds. |

`BeakBackendConfig.fromEnv` is the usual way in: it reads the [server variables
above](#read-by-beakbackendconfigfromenv) and validates them. Construct the object
directly only when you have the parts already validated (tests, embedding).

## Storage configs

`BEAK_STORAGE_DRIVER` selects one of these sealed `BeakStorageConfig` variants.
Each is pure data (credentials included) that the matching driver consumes;
`beak_core` owns the config surface so an app configures storage without importing
a driver package. Configs carrying secrets redact them in `toString`.

### S3 (`BeakS3Config`)

For AWS S3, MinIO, and other S3-compatible stores. Consumed by `beak_storage_s3`.

```dart title="packages/beak_core/lib/src/storage/drivers/beak_s3_config.dart"
const BeakS3Config({
  required this.endpoint,
  required this.bucket,
  required this.accessKey,
  required this.secretKey,
  required this.region,
  this.usePathStyle = false,
  this.publicBaseUrl,
});
```

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `endpoint` | `Uri` | required | The S3 API endpoint (AWS host or MinIO URL). |
| `bucket` | `String` | required | Bucket uploads are stored in. |
| `accessKey` | `String` | required | Access key id (redacted in `toString`). |
| `secretKey` | `String` | required | Secret access key (redacted in `toString`). |
| `region` | `String` | required | Bucket region, e.g. `eu-central-1`. |
| `usePathStyle` | `bool` | `false` | Path-style addressing (`endpoint/bucket/key`), as MinIO requires, instead of AWS virtual-host style. |
| `publicBaseUrl` | `Uri?` | `null` | Overrides driver-generated file URLs (e.g. a CDN in front of the bucket); `null` lets the driver build endpoint URLs. |

### FTP (`BeakFtpConfig`)

Consumed by `beak_storage_ftp`.

```dart title="packages/beak_core/lib/src/storage/drivers/beak_ftp_config.dart"
const BeakFtpConfig({
  required this.host,
  this.port = 21,
  required this.user,
  required this.password,
  required this.baseDir,
  required this.publicBaseUrl,
});
```

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `host` | `String` | required | FTP server host name. |
| `port` | `int` | `21` | FTP server port. |
| `user` | `String` | required | Login user name. |
| `password` | `String` | required | Login password (redacted in `toString`). |
| `baseDir` | `String` | required | Remote directory uploads are stored under. |
| `publicBaseUrl` | `Uri` | required | Base URL stored files are served from. |

### Local disk (`BeakLocalDiskStorageConfig`)

Files land under a directory the app serves statically. Pre-registered in
`beak_core`, so no driver package is needed.

```dart title="packages/beak_core/lib/src/storage/drivers/beak_local_disk_storage_config.dart"
const BeakLocalDiskStorageConfig({
  required this.rootDir,
  required this.publicBaseUrl,
});
```

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `rootDir` | `String` | required | Directory files are written under. |
| `publicBaseUrl` | `Uri` | required | Base URL the app serves `rootDir` from. |

### Memory (`BeakMemoryStorageConfig`)

Holds uploads in memory. It takes no fields and is meant for tests. Selected by
`BEAK_STORAGE_DRIVER=memory` or `const BeakMemoryStorageConfig()`.

## `BeakPanelConfig`

Everything a panel needs at startup, in one declarative value. Hand it to a
`BeakPanel` and the whole UI (navigation, routing, generated CRUD pages,
dashboard) is stood up from it. Compose it in a builder so tests can vary the API
origin.

```dart title="packages/beak_frontend/lib/src/panel/beak_panel_config.dart"
const BeakPanelConfig({
  required this.title,
  required this.resources,
  required this.apiBaseUrl,
  this.pages = const [],
  this.auth,
  this.maintenance,
  this.theme,
  this.darkTheme,
  this.initialThemeMode = OiThemeMode.system,
  this.sidebarCollapsible = true,
  this.sidebarDefaultCollapsed = false,
  this.dashboardStats = const [],
  this.dashboardCharts = const [],
  this.notifications,
});
```

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | `String` | required | The panel title, shown in the shell and login screen. |
| `resources` | `List<BeakResource>` | required | The resources the panel exposes, in navigation order. |
| `apiBaseUrl` | `String` | required | Origin of the `beak_backend` server (e.g. `http://localhost:8080`). Match it to the backend port. |
| `pages` | `List<BeakScreen>` | `const []` | Custom, non-resource screens, in navigation order. |
| `auth` | `BeakAuthConfig?` | `null` | Authentication routes; `null` mounts only a default `/login`. |
| `maintenance` | `BeakMaintenanceConfig?` | `null` | Maintenance / coming-soon routes; `null` mounts neither. |
| `theme` | `OiThemeData?` | `null` (`OiThemeData.light()`) | The light theme. |
| `darkTheme` | `OiThemeData?` | `null` (`OiThemeData.dark()`) | The dark theme. |
| `initialThemeMode` | `OiThemeMode` | `OiThemeMode.system` | The theme mode the panel starts in; toggled live from the shell. |
| `sidebarCollapsible` | `bool` | `true` | Whether the sidebar can collapse to an icon rail. |
| `sidebarDefaultCollapsed` | `bool` | `false` | Whether the sidebar starts collapsed. |
| `dashboardStats` | `List<BeakStat>` | `const []` | The dashboard's metric cards, in order. |
| `dashboardCharts` | `List<BeakChart>` | `const []` | The dashboard's charts, in order. |
| `notifications` | `BeakNotificationSource?` | `null` | Binds a model's rows to the shell's notification bell; `null` shows no bell. |

`buildRegistry()` walks `resources` and registers every model, so the data layer
can resolve a table name back to its model. Registering the same table twice is a
configuration error the registry surfaces.

### The resources inside it

Each entry in `resources` is a `BeakResource`: a registered `BeakModel` plus its
navigation presentation, actions, filters, view modes, and optional detail and
form layouts. It is a config object in its own right, documented in full on the
[Resources](../panel/resources.md) page.

```dart title="packages/beak_frontend/lib/src/panel/beak_panel_config.dart"
const BeakResource({
  required this.model,
  required this.icon,
  this.label,
  this.section,
  this.recordActions = const [],
  this.bulkActions = const [],
  this.globalActions = const [],
  this.filters = const [],
  this.viewModes = const [BeakTableView()],
  this.detail,
  this.formSteps,
  this.formLayout,
});
```

`label` defaults to the title-cased table name, and `viewModes` defaults to a
single table view. The rest default to empty or `null`.

## Continue reading

- [Running the server](../backend/running-the-server.md) how `BeakBackendConfig` and storage wiring come together into a live server.
- [Environment and config](../deployment/environment-and-config.md) the deployment side of these variables.
- [Going to production](../deployment/going-to-production.md) picking real values for a real deployment.
- [Resources](../panel/resources.md) the full `BeakResource` surface referenced above.
- [REST API](rest-api.md) the endpoints the configured backend serves.
