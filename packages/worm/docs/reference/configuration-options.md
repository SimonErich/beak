---
title: Configuration options
description: Exhaustive field tables for WormConfig, ConnectionConfig, StrictnessConfig, LogConfig, and the Environment enum.
---

Every field on every configuration type, with its exact default. For the narrative walkthrough of bootstrapping, read [configuration](../start-here/configuration.md); for the runtime members these configs feed, see the [Worm runtime reference](./worm-runtime.md).

All types on this page are exported from `package:worm/worm.dart`, are `const`-constructible, and provide a `copyWith` method.

## Mini-index

| Symbol | One-liner |
| --- | --- |
| [WormConfig](#wormconfig) | Top-level runtime configuration passed to `Worm.initialize` |
| [ConnectionConfig](#connectionconfig) | Metadata describing one named database connection |
| [StrictnessConfig](#strictnessconfig) | Independently toggleable safety gates |
| [LogConfig](#logconfig) | Query-logging configuration |
| [LogLevel](#loglevel) | Log severity levels |
| [Environment](#environment) | Runtime environment enum, `WORM_ENV` aware |

### WormConfig

**Signature**

```dart
const WormConfig({
  String defaultConnection = 'default',
  Map<String, ConnectionConfig> connections = const {},
  int poolSize = 10,
  PrimaryKeyType primaryKeyType = PrimaryKeyType.uuid,
  bool timestamps = true,
  bool softDeletes = false,
  StrictnessConfig strictness = const StrictnessConfig(),
  Environment environment = Environment.development,
})
```

**Fields**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `defaultConnection` | `String` | `'default'` | Name of the implicit default connection. `Worm.initialize` throws `ConfigurationException('adapter.missing')` if no adapter is registered under this name. |
| `connections` | `Map<String, ConnectionConfig>` | `{}` | Named connection metadata. Starts empty; adapters are supplied separately to `Worm.initialize`. |
| `poolSize` | `int` | `10` | Default pool size for connections that do not declare their own. Individual `ConnectionConfig` entries may override it. |
| `primaryKeyType` | `PrimaryKeyType` | `PrimaryKeyType.uuid` | Default primary-key strategy for models. Values: `uuid`, `integer`. |
| `timestamps` | `bool` | `true` | Whether `created_at` / `updated_at` are managed automatically. |
| `softDeletes` | `bool` | `false` | Whether soft deletes are enabled by default (still opt-in per model via the `SoftDeletes` mixin). |
| `strictness` | `StrictnessConfig` | all flags off | See [StrictnessConfig](#strictnessconfig). |
| `environment` | `Environment` | `Environment.development` | Overridden at runtime by the `WORM_ENV` process variable in `Worm.environment`. |

**Example**

```dart
const config = WormConfig(
  strictness: StrictnessConfig(
    preventFullTableScans: true,
    preventSilentMassAssignment: true,
  ),
  environment: Environment.production,
);
await Worm.initialize(config: config, adapters: {'default': adapter});
```

**Gotchas**

- `connections` carries metadata only. Adapters themselves go into the `adapters` map of `Worm.initialize`, keyed by the same connection names.
- Passing a config twice (double `initialize`) throws `ConfigurationException('initialization.duplicate')`; call `Worm.reset()` first in tests.

**Related:** [Worm runtime: initialize](./worm-runtime.md#initialize), [start here: configuration](../start-here/configuration.md)

### ConnectionConfig

**Signature**

```dart
const ConnectionConfig({
  String driver = 'inMemory',
  String host = 'localhost',
  int port = 0,
  String database = '',
  String? username,
  String? password,
  bool useSsl = false,
  int poolSize = 10,
  int? maxTotalConnections,
  Duration connectionTimeout = const Duration(seconds: 5),
  Duration idleTimeout = const Duration(seconds: 300),
})
```

**Fields**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `driver` | `String` | `'inMemory'` | Driver identifier adapter packages match to claim a connection. Known ids: `'postgres'`, `'mongodb'`, `'inMemory'`. |
| `host` | `String` | `'localhost'` | Hostname or socket path. |
| `port` | `int` | `0` | Sentinel: `0` means "unset". Adapters supply their protocol default when the value is `0`. |
| `database` | `String` | `''` | Database, keyspace, or namespace name. |
| `username` | `String?` | `null` | `null` means unauthenticated. |
| `password` | `String?` | `null` | `null` means unauthenticated. |
| `useSsl` | `bool` | `false` | Whether to negotiate TLS on the wire. |
| `poolSize` | `int` | `10` | Connections held open per isolate. |
| `maxTotalConnections` | `int?` | `null` | Cap on total connections across all isolates. `null` disables the cap. |
| `connectionTimeout` | `Duration` | 5 seconds | Maximum wait when acquiring a new connection. |
| `idleTimeout` | `Duration` | 300 seconds | Time a connection may idle before being closed. |

**Example**

```dart
const analytics = ConnectionConfig(
  driver: 'postgres',
  host: 'db.internal',
  database: 'analytics',
  username: 'app',
  password: 'secret',
  useSsl: true,
  maxTotalConnections: 40,
);
```

**Gotchas**

- `ConnectionConfig` is metadata only. Worm core never opens sockets from it; adapter packages consume the subset they need.
- `port: 0` is not an error. It is the documented "use the protocol default" sentinel.

**Related:** [multiple connections](../database/multiple-connections.md), [choosing a database](../drivers/choosing-a-database.mdx), [production guide](../guides/production.md)

### StrictnessConfig

**Signature**

```dart
const StrictnessConfig({
  bool preventLazyLoading = false,
  bool preventFullTableScans = false,
  bool preventSilentMassAssignment = false,
  bool warnOnN1Queries = false,
  bool throwOnN1Queries = false,
  bool warnOnMissingIndex = false,
  bool preventDestructiveWithoutWhere = false,
  Duration slowQueryThreshold = const Duration(milliseconds: 500),
})
```

**Fields**

| Field | Type | Default | Effect when enabled |
| --- | --- | --- | --- |
| `preventLazyLoading` | `bool` | `false` | Accessing an unloaded relation throws `LazyLoadingException`. |
| `preventFullTableScans` | `bool` | `false` | A read query without a WHERE clause throws `FullTableScanException`. Also acts as the umbrella flag for destructive writes (see below). |
| `preventSilentMassAssignment` | `bool` | `false` | `fill()` throws `MassAssignmentException` instead of silently skipping guarded or non-fillable keys. |
| `warnOnN1Queries` | `bool` | `false` | Detected N+1 query patterns log a `[WARNING]` line. |
| `throwOnN1Queries` | `bool` | `false` | Escalates detected N+1 patterns to a thrown `DangerousQueryException`. |
| `warnOnMissingIndex` | `bool` | `false` | Warns when an EXPLAIN plan shows a query not using an index (adapter must support explain). |
| `preventDestructiveWithoutWhere` | `bool` | `false` | `UPDATE` or `DELETE` without a WHERE clause throws `FullTableScanException`. |
| `slowQueryThreshold` | `Duration` | 500 ms | Queries exceeding this duration trigger a slow-query warning. |

**Example**

```dart
const production = StrictnessConfig(
  preventLazyLoading: true,
  preventFullTableScans: true,
  preventSilentMassAssignment: true,
  warnOnN1Queries: true,
  preventDestructiveWithoutWhere: true,
);
```

**Gotchas**

- Flags are orthogonal: flipping one never implicitly flips another. The one asymmetry is enforcement-side: a destructive write without WHERE is blocked when either `preventDestructiveWithoutWhere` or `preventFullTableScans` is set (locally on the builder or globally).
- `DangerousQueryException` is a typedef of `FullTableScanException`; catching either catches both.
- `warnOnN1Queries` and `throwOnN1Queries` are independent. Keep `throwOnN1Queries` off in bulk-write and benchmark suites; bulk writes can look like N+1 patterns to the detector.
- Every gate honors `Worm.unsafe(...)` as the per-call escape hatch, except per-model `strictMassAssignment` overrides.
- `Worm.strictness` merges with per-builder `StrictnessConfig`: strict wins on either side.
- This `slowQueryThreshold` (500 ms) is separate from `LogConfig.slowQueryThreshold` (200 ms). The first drives the strictness warning; the second drives the `[SLOW QUERY]` log prefix.

**Related:** [strict mode guide](../guides/strict-mode.md), [Worm runtime: unsafe](./worm-runtime.md#unsafe), [exceptions](./exceptions.md)

### LogConfig

**Signature**

```dart
const LogConfig({
  bool enabled = true,
  LogLevel level = LogLevel.debug,
  String? file,
  Duration slowQueryThreshold = const Duration(milliseconds: 200),
  bool logQueryParameters = true,
  bool formatQueries = true,
})
```

**Fields**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `enabled` | `bool` | `true` | Master switch. When `false` every log method is a no-op. |
| `level` | `LogLevel` | `LogLevel.debug` | Reserved. The current logger does not yet drop sub-threshold entries. |
| `file` | `String?` | `null` | Consumed by `QueryLogger.fromConfig`: non-null returns a `FileLogger` appending to that path, null returns a `ConsoleQueryLogger` writing to stdout. |
| `slowQueryThreshold` | `Duration` | 200 ms | Queries at or above this duration are formatted with the `[SLOW QUERY]` prefix instead of `[QUERY]`. |
| `logQueryParameters` | `bool` | `true` | When `false`, the params section reads `params: [REDACTED]`. |
| `formatQueries` | `bool` | `true` | Reserved for future SQL pretty-printing work. |

**Example**

```dart
final logger = QueryLogger.fromConfig(
  const LogConfig(
    file: 'logs/queries.log',
    logQueryParameters: false, // redact bound values
  ),
);
```

**Gotchas**

- `level` and `formatQueries` are reserved fields: they exist on the config but the current implementation does not act on them yet.
- Directly constructed loggers ignore `file`; wire it through `QueryLogger.fromConfig` or construct `FileLogger` yourself.

**Related:** [logging and debugging](../guides/logging-and-debugging.md), [security guide](../guides/security.md)

### LogLevel

**Signature**

```dart
enum LogLevel { debug, info, warning, error }
```

**Example**

```dart
assert(LogLevel.warning.severity > LogLevel.debug.severity);
```

Ordered from least to most severe. The `severity` getter returns an `int` (the enum index) for direct comparison.

**Gotchas**

- Filtering by level is not implemented yet; see the `LogConfig.level` reserved-field note above.

**Related:** [LogConfig](#logconfig), [logging and debugging](../guides/logging-and-debugging.md)

### Environment

**Signature**

```dart
enum Environment { development, staging, production, testing, all }
```

**Example**

```sh
WORM_ENV=production dart run bin/server.dart
```

```dart
final env = Worm.environment; // Environment.production
```

**Values**

| Value | Meaning |
| --- | --- |
| `development` | Local development. The fallback when nothing else is set. |
| `staging` | Pre-production staging. |
| `production` | Live production. Destructive CLI commands require force gates here. |
| `testing` | Automated test runs. |
| `all` | Seeder-only marker meaning "run in every environment". Not a deployment target. |

**Precedence in `Worm.environment`**

1. The `WORM_ENV` process environment variable, trimmed and matched case-insensitively against the value names above.
2. `WormConfig.environment`.
3. `Environment.development` when neither is available.

**Gotchas**

- `WORM_ENV` silently overrides the config value. An unparseable `WORM_ENV` falls through to the config.
- `all` exists for seeder targeting; setting `WORM_ENV=all` is technically parseable but meaningless as a runtime environment.

**Related:** [Worm runtime: environment](./worm-runtime.md#environment), [seeding](../database/seeding.md), [production guide](../guides/production.md)

## Continue reading

- [Strict mode guide](../guides/strict-mode.md) for each strictness gate in practice, with the exact exception it throws.
- [Worm runtime](./worm-runtime.md) for the statics that consume these configs.
- [Multiple connections](../database/multiple-connections.md) for wiring several `ConnectionConfig` entries and adapters.
- [Logging and debugging](../guides/logging-and-debugging.md) for `LogConfig` in a working setup.
