---
title: Configuration options
description: Every beak.yaml key, every environment variable, and every field of BeakBackendConfig, the storage configs, BeakPanelConfig and BeakResource, with defaults.
---

# Configuration options

After this page you can configure a Beak app end to end: the project file the
generator reads, the environment variables the server reads at startup, the
storage configs those variables map to, and the typed config objects Beak
generates from them, each with its default.

Configuration lives in four places, and none of them reads another's keys.

| Where | Read when | Holds |
| --- | --- | --- |
| `beak.yaml` | `beak prepare` runs | Panel title, API origin, server binding, per-resource presentation |
| The environment (and `.env`) | The server boots | Database URL, port, host, storage credentials |
| Override files (`lib/panel.dart`, `lib/resources/<table>.dart`, …) | The app compiles | Anything holding a symbol or a closure |
| The generated `lib/beak/*.g.dart` | Never by hand | The typed config objects the two above produce |

## `beak.yaml`

The project file. Read at *generate* time and emitted as typed Dart literals, so
no map ever reaches runtime. Every key is optional: delete the file and Beak
still boots, titling the panel after the package. An unknown key is an error
naming the line, because a typo that quietly does nothing is worse than one that
fails at generate time.

```yaml title="examples/superdashboard/beak.yaml"
name: Beak Superdashboard

api:
  baseUrl: http://localhost:8180

server:
  # The store example already has 8080, and both run from this repository.
  port: 8180
```

| Key | Type | Default | Meaning |
| --- | --- | --- | --- |
| `name` | string | title-cased package name | The panel title, in the shell and the browser tab. |
| `api.baseUrl` | string | `http://localhost:8080` | The origin the panel calls. `auto` means "the origin the panel was served from", which is what a single-host deployment wants. |
| `server.port` | int, `1`-`65535` | none (Beak's `8080`) | Default port the generated host binds. A real `PORT` still wins. |
| `server.host` | string | none (Beak's `0.0.0.0`) | Default interface the generated host binds. A real `HOST` still wins. |
| `resources.<table>.icon` | lowerCamelCase string | a default icon | Sidebar icon: any `OiIcons` name. |
| `resources.<table>.label` | string | title-cased table name | Navigation label. |
| `resources.<table>.section` | string | none | Sidebar group heading. |
| `resources.<table>.hidden` | bool | `false` | `true` keeps the resource out of the sidebar. It keeps its model, its API and its relationships. |
| `theme.sidebar.collapsible` | bool | `true` | Whether the sidebar can collapse to an icon rail. |
| `theme.sidebar.startCollapsed` | bool | `false` | Whether it starts collapsed. |

`resources` is keyed by **table name**, so a key naming no discovered table stops
`beak prepare` with a message naming the line, and a did-you-mean. An `icon`
that is not a lowerCamelCase identifier is rejected by name, because the value
is spliced into generated Dart and a typo would otherwise surface as a compile
error inside a file you did not write.

`api.baseUrl` becomes a compile-time default the panel reads, so one build can
point elsewhere without touching the file:

```bash
flutter build web --dart-define=BEAK_API_BASE_URL=https://api.example.com
```

Full page, with what deliberately does not live here:
[beak.yaml](beak-yaml.md).

## Environment variables

The server reads these at startup. `BeakBackendConfig.fromEnv` validates the
first three and throws a `BeakConfigurationException` on anything malformed;
`BeakStorageSettings.fromEnv` reads the rest.

### The server

| Variable | Required | Default | Meaning |
| --- | --- | --- | --- |
| `DATABASE_URL` | no | `sqlite:beak.db` | The database connection URL. Must be an absolute URL with a scheme; anything but `sqlite:`/`file:` must also have a host, e.g. `postgres://user:pass@host:5432/db`. |
| `PORT` | no | `8080` | The port the server listens on. An integer in `1`-`65535`. |
| `HOST` | no | `0.0.0.0` | The interface the server binds. Must not be empty. |

The SQLite default is the point: a new project runs with no Docker, no
credentials and no `.env` at all. `sqlite:beak.db` is a file beside the process,
`sqlite::memory:` a database that vanishes with it. Set `DATABASE_URL` to a
`postgres://` URL when you want a server database.

### Storage

`BEAK_STORAGE_DRIVER` selects a driver and the rest configure it. Unset, the
server falls back to local disk under `storage/uploads`, served by itself at
`/uploads`, so an upload column works on a fresh project with no setup.
`BEAK_STORAGE_DRIVER=none` turns the upload endpoints off outright. Any value
outside the supported set throws at boot, naming the supported ones.

| Variable | Required | Default | Meaning |
| --- | --- | --- | --- |
| `BEAK_STORAGE_DRIVER` | no | local disk under `storage/uploads` | One of `s3`, `ftp`, `local`, `memory`, `none`. |
| `BEAK_S3_ENDPOINT` | with `s3` | none | The S3 API endpoint (AWS host or a MinIO URL). |
| `BEAK_S3_BUCKET` | with `s3` | none | The bucket uploads land in. |
| `BEAK_S3_ACCESS_KEY` | with `s3` | none | Access key id. A secret. |
| `BEAK_S3_SECRET_KEY` | with `s3` | none | Secret access key. A secret. |
| `BEAK_S3_REGION` | with `s3` | none | The bucket region, e.g. `us-east-1`. |
| `BEAK_S3_USE_PATH_STYLE` | no | `false` | `true` uses path-style addressing (`endpoint/bucket/key`), which MinIO requires. Any other value is `false`. |
| `BEAK_FTP_HOST` | with `ftp` | none | FTP server host name. |
| `BEAK_FTP_USER` | with `ftp` | none | Login user name. A secret's other half. |
| `BEAK_FTP_PASSWORD` | with `ftp` | none | Login password. A secret. |
| `BEAK_FTP_BASE_DIR` | with `ftp` | none | Remote directory uploads are stored under. |
| `BEAK_FTP_PUBLIC_BASE_URL` | with `ftp` | none | Base URL stored files are served from. |
| `BEAK_FTP_PORT` | no | `21` | FTP server port. |
| `BEAK_LOCAL_ROOT_DIR` | with `local` | none | Directory files are written under. |
| `BEAK_LOCAL_PUBLIC_BASE_URL` | with `local` | none | Base URL the server serves `rootDir` from. Beak mounts a read-only route at its path, so an upload's URL resolves with no bucket, CDN or proxy. |

A driver selected but not registered fails at boot by name: `beak_backend`
depends on no driver package, so an app uploading to S3 adds
`beak_storage_s3` and declares a `beakStorageRegistry()` in `lib/server.dart`,
which `beak prepare` wires into the generated host. The `memory` and `local`
drivers are in the box.

```dart title="examples/embedded/lib/server.dart"
BeakStorageRegistry beakStorageRegistry() {
  final registry = createDefaultStorageRegistry();
  registerS3Storage(registry);
  return registry;
}
```

```dart title="packages/beak_backend/lib/src/server/beak_storage_settings.dart"
  static const Set<String> supportedDrivers = {
    's3',
    'ftp',
    'memory',
    'local',
    'none',
  };
```

A driver outside that set is still usable: register it and build its config
yourself. `BeakStorageSettings` covers the ones configurable purely from
environment variables.

### Your own variables

A `lib/server.dart` override reads everything else through
`BeakServerDefaults.environment` rather than `Platform.environment`, so a test
that injects an environment injects it into the policy and the auth config too:

```dart title="examples/store/lib/server.dart"
  final String secret =
      defaults.environment['AUTH_SECRET'] ?? 'store-dev-secret';
```

### How `.env` resolves

`BeakEnv.resolve` overlays the `.env` file with the real process environment, so
a deployment configures itself through real environment variables and never
needs a file. Real environment variables always win over file values.

```dart title="packages/beak_backend/lib/src/config/env_loader.dart"
  static Map<String, String> resolve({
    String filePath = '.env',
    Map<String, String>? processEnvironment,
  }) => {...loadFile(filePath), ...processEnvironment ?? Platform.environment};
```

`BeakEnv.parse` handles comments (`#`), blank lines, an optional `export `
prefix, whitespace around `=`, and matching surrounding quotes. It splits on the
first `=` only. A line without a separator, or with an invalid key, throws a
`BeakConfigurationException`. A missing `.env` is not an error: it is the
supported default.

Keep secrets out of the repository. A committed `.env.example` documents the
keys; the real `.env` is git-ignored.

## `BeakBackendConfig`

The typed, validated runtime configuration of a backend. The generated
`BeakServeHost` builds it for you from the environment; construct it directly
only when you have the parts already validated (tests, embedding). Its
`toString` redacts the database credentials, so it is safe to log.

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

| Static | Value | Meaning |
| --- | --- | --- |
| `defaultDatabaseUrl` | `sqlite:beak.db` | The database a project gets when it names none. |
| `defaultPort` | `8080` | The port when `PORT` is unset. |
| `defaultHost` | `0.0.0.0` | The interface when `HOST` is unset. |

## Storage configs

`BEAK_STORAGE_DRIVER` selects one of these sealed `BeakStorageConfig` variants.
Each is pure data (credentials included) that the matching driver consumes;
`beak_core` owns the config surface so an app configures storage without
importing a driver package. Configs carrying secrets redact them in `toString`.

### S3 (`BeakS3Config`)

For AWS S3, MinIO, and other S3-compatible stores. Consumed by
`beak_storage_s3`.

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

Files land under a directory this server then serves. Pre-registered in
`beak_core`, so no driver package is needed, and Beak mounts a read-only route
at the public base URL's path for you.

```dart title="packages/beak_core/lib/src/storage/drivers/beak_local_disk_storage_config.dart"
  const BeakLocalDiskStorageConfig({
    required this.rootDir,
    required this.publicBaseUrl,
  });
```

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `rootDir` | `String` | required | Directory files are written under. |
| `publicBaseUrl` | `Uri` | required | Base URL the server serves `rootDir` from. |

### Memory (`BeakMemoryStorageConfig`)

Holds uploads in memory. It takes no fields and is meant for tests. Selected by
`BEAK_STORAGE_DRIVER=memory` or `const BeakMemoryStorageConfig()`.

## `BeakPanelConfig`

Everything a panel needs at startup, in one declarative value. You do not write
one: `beak prepare` generates it into `lib/beak/panel.g.dart` from `beak.yaml`
and the discovered models and screens. To change it, add `lib/panel.dart`
(`beak eject panel`) and `copyWith` the parts you want different:

```dart
BeakPanelConfig beakPanel(BeakPanelConfig defaults) =>
    defaults.copyWith(title: 'Acme, staging');
```

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

| Field | Type | Default | Generated from |
| --- | --- | --- | --- |
| `title` | `String` | required | `name` in `beak.yaml` |
| `resources` | `List<BeakResource>` | required | every model under `lib/models/` |
| `apiBaseUrl` | `String` | required | `api.baseUrl` in `beak.yaml` |
| `pages` | `List<BeakScreen>` | `const []` | `lib/dashboard.dart` when present, then every screen under `lib/screens/` |
| `auth` | `BeakAuthConfig?` | `null` (a default `/login` only) | `lib/auth.dart`, when present |
| `maintenance` | `BeakMaintenanceConfig?` | `null` (neither route) | `lib/panel.dart` |
| `theme` | `OiThemeData?` | `null` (`OiThemeData.light()`) | `lib/theme.dart`, when present |
| `darkTheme` | `OiThemeData?` | `null` (`OiThemeData.dark()`) | `lib/theme.dart`, when present |
| `initialThemeMode` | `OiThemeMode` | `OiThemeMode.system` | `lib/panel.dart` |
| `sidebarCollapsible` | `bool` | `true` | `theme.sidebar.collapsible` |
| `sidebarDefaultCollapsed` | `bool` | `false` | `theme.sidebar.startCollapsed` |
| `dashboardStats` | `List<BeakStat>` | `const []` | `lib/panel.dart` |
| `dashboardCharts` | `List<BeakChart>` | `const []` | `lib/panel.dart` |
| `notifications` | `BeakNotificationSource?` | `null` (no bell) | `lib/panel.dart` |

`buildRegistry()` walks `resources` and registers every model, so the data layer
can resolve a table name back to its model. Registering the same table twice is
a configuration error the registry surfaces.

## `BeakResource`

One entry in `resources`: a `BeakModel` plus its navigation presentation,
actions, filters, view modes, and optional detail and form layouts. Generated
too. To change one without ejecting the whole panel, add
`lib/resources/<table>.dart` (`beak eject resource <table>`):

```dart
BeakResource beakResource(BeakResource generated) => generated.copyWith(
  viewModes: const [BeakTableView(), BeakKanbanView(/* ... */)],
);
```

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

Three fields fall back to something derived rather than to their literal
default, so a resource that says nothing still gets a sensible page:

| Getter | Falls back to |
| --- | --- |
| `effectiveLabel` | the title-cased table name |
| `effectiveFilters` | one control per `@Column(filterable: true)`: select for an enum, switch for a bool, contains-search for text, range for a date |
| `effectiveDetail` | a headline card of the first four fields, the rest beside it, and a tab per to-many relationship |

The full surface, with worked examples: [Resources](../panel/resources.md).

## Continue reading

- [beak.yaml](beak-yaml.md) the project file in full, and what deliberately stays out of it.
- [Running the server](../backend/running-the-server.md) how these values come together into a live server.
- [Environment and config](../deployment/environment-and-config.md) the deployment side of these variables.
- [Going to production](../deployment/going-to-production.md) picking real values for a real deployment.
- [REST API](rest-api.md) the endpoints the configured backend serves.
