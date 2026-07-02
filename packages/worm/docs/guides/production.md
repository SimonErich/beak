---
title: Production
description: Environment semantics, destructive command gates, deploy patterns, pooling, and the go-live checklist.
---

This page collects everything that changes when worm runs against data you cannot afford to lose. It builds on [migrations in depth](../database/migrations-in-depth.md) and [strict mode](./strict-mode.md), and ends with a checklist.

## Set the environment

Worm resolves its runtime environment in this order:

1. The `WORM_ENV` process environment variable, parsed case-insensitively against the `Environment` enum names (`development`, `staging`, `production`, `testing`, `all`). Unrecognized values are ignored.
2. `WormConfig.environment`, if `Worm.initialize` has run.
3. `Environment.development` as the final fallback.

Set both in production so the CLI and the runtime agree:

```bash
export WORM_ENV=production
```

```dart
await Worm.initialize(
  config: const WormConfig(environment: Environment.production),
  adapters: {'default': adapter},
);
```

The CLI reads the environment through the `CliContext` you construct. Wire it with `Worm.environment` so `WORM_ENV` governs `--force` gating and seeder filtering.

## Destructive command gates

Three CLI behaviors protect production data:

- `migrate:fresh` and `migrate:refresh` refuse to run in production without `--force`. They write `error: refusing to run destructive command in production without --force` to stderr and exit with code 1.
- `schema:dump --prune` deletes every migration file under `migrations/` and therefore requires `--force` in every environment, not just production.
- `db:seed --force` is not a production gate. It bypasses the seeder environment filter, which makes it more dangerous in production, not less. Never put it in a deploy script.

The full flag and exit-code tables live in the [CLI reference](../reference/cli-commands.md).

## Deploying migrations

Facts that shape a safe migration deploy:

- Migrations run sequentially and are not wrapped in a transaction. A failing migration can leave partial DDL behind. Keep each migration small and test the exact sequence against a staging copy first.
- Rollback requires the migration class to be registered. The runner resolves recorded names against the `migrations` list in your `CliContext`; a recorded name with no registered class throws a `MigrationException`. Never delete migration files that production has applied (use `schema:dump` squashing deliberately instead).
- Applied migrations are tracked in the `worm_migrations` table with batch numbers. `migrate:rollback` pops whole batches.

A deploy pipeline that respects those facts:

```bash
# 1. Preview what would run, without touching the database.
dart run worm migrate --pretend

# 2. Apply pending migrations (optionally staged).
dart run worm migrate
# or: dart run worm migrate --step=1

# 3. Verify state.
dart run worm migrate:status
```

`--pretend` prints the compiled statements per pending migration. Adapter calls are recorded, never executed. One caution: the Dart code in a migration body still runs under pretend, so side effects outside the adapter (file writes, network calls) happen for real. See [migrations in depth](../database/migrations-in-depth.md).

## Connection pools

Pool sizing lives on `ConnectionConfig`:

- `poolSize` (default 10) sets the pool size for that named connection.
- `maxTotalConnections` (default unset) caps the total slots all pools created from config may reserve within one isolate. When a new pool would exceed the cap, its size is clamped; when nothing is available, construction throws a `ConfigurationException` with key `maxTotalConnections`.
- `port: 0` means "use the protocol default" (5432 for PostgreSQL, 3306 for MySQL).

Size against your database server's `max_connections` budget, and remember the cap is per isolate: four isolates with `maxTotalConnections: 25` can still open 100 connections. Driver specifics live on [PostgreSQL](../drivers/postgresql.md) and [MySQL](../drivers/mysql.md); see [multiple connections](../database/multiple-connections.md) when several named connections share one cap.

## Strictness and logging in production

Enable the prevention flags and keep detector throws conservative:

```dart
const strictness = StrictnessConfig(
  preventLazyLoading: true,
  preventFullTableScans: true,
  preventSilentMassAssignment: true,
  preventDestructiveWithoutWhere: true,
  warnOnN1Queries: true,
);

final logger = QueryLogger.fromConfig(
  const LogConfig(
    file: '/var/log/worm.log',
    logQueryParameters: false,
  ),
);

final logging = LoggingAdapter(
  inner: adapter,
  logger: logger,
  strictness: strictness,
  adapterName: 'Postgres',
);

await Worm.initialize(
  config: const WormConfig(
    environment: Environment.production,
    strictness: strictness,
  ),
  adapters: {'default': logging},
);
```

Notes on this block:

- The `LoggingAdapter` wrap is explicit and must happen before `Worm.initialize`. There is no auto-wiring.
- `logQueryParameters: false` redacts bound values from log lines (`params: [REDACTED]`). Recommended wherever queries carry user data; see [security](./security.md).
- Keep `throwOnN1Queries` off unless you have verified your hot paths. Bulk writes can look like N+1 to the detector and would abort mid-request.
- `FileLogger` holds an open sink. Call `close()` on shutdown or trailing lines may be lost.

Flag semantics are on [strict mode](./strict-mode.md); logger wiring is on [logging and debugging](./logging-and-debugging.md).

## Seeder hygiene

`Seeder.environment` defaults to `Environment.all`, which means an unannotated seeder runs everywhere, including production. Set it explicitly on every seeder:

```dart
final class DemoUsersSeeder extends Seeder {
  const DemoUsersSeeder();

  @override
  String get name => 'DemoUsersSeeder';

  @override
  Environment get environment => Environment.development;

  @override
  Future<void> run(DatabaseAdapter adapter) async {
    // dev-only fixture data
  }
}
```

Reserve `Environment.production` (or `all`) for reference data that genuinely belongs in production, such as country tables. Two sharp edges: `db:seed --class=<Name>` runs the named seeder and skips the environment filter entirely, and the CLI wires no tracking store, so seeders re-run on every invocation. Idempotent tracking via `SeederRecordStore` is a programmatic pattern; see [seeding](../database/seeding.md).

## Health and lifecycle

- `Worm.isInitialized` is a cheap, non-throwing readiness probe for health endpoints.
- `Worm.initialize` connects every registered adapter and throws a `ConfigurationException` when no adapter matches the default connection, so a misconfigured deploy fails at startup rather than on first query.
- On graceful shutdown, call `Worm.reset()` to disconnect every registered adapter, and `close()` any `FileLogger` you created.

## Production checklist

- `WORM_ENV=production` is set on every process that runs the app or the CLI.
- `WormConfig.environment` is `Environment.production`.
- Strictness prevention flags are on; `throwOnN1Queries` decision is deliberate.
- Adapter is wrapped in `LoggingAdapter` with `logQueryParameters: false` and a file sink.
- TLS verified for MySQL (`onBadCertificate` overridden) and enabled for PostgreSQL (`useSsl: true`). See [security](./security.md).
- Credentials come from the environment, not source control.
- Pool sizes and `maxTotalConnections` fit the database server's connection budget across all isolates.
- Migration deploy uses `--pretend` first; no unregistered migrations; no migration files deleted outside a deliberate `schema:dump --prune`.
- Every seeder declares an explicit `environment`; no `db:seed --force` or `--class` in deploy scripts.
- Health endpoint checks `Worm.isInitialized`; shutdown path calls `Worm.reset()` and closes file loggers.

## Continue reading

- [Migrations in depth](../database/migrations-in-depth.md) for squashing, pretend mode, and dependency ordering.
- [Strict mode](./strict-mode.md) for what each prevention flag throws.
- [Security](./security.md) for injection, TLS, and credential handling.
- [CLI reference](../reference/cli-commands.md) for every command, flag, and exit code.
