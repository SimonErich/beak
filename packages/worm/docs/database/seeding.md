---
title: Seeding
description: Fill your database with known data using seeders, environment filters, explicit ordering, and optional run tracking.
---

Seeders put known rows into your database: reference data, demo accounts, local fixtures. Seeds today, worms tomorrow. This page builds on [migrations](./migrations.md) and pairs well with [factories](../models/factories.md) for realistic fake data.

## Writing a seeder

Extend `Seeder`, give it a `name`, and implement `run`. The runner hands you the raw `DatabaseAdapter`, so writes go through descriptors:

```dart title="seeds/users_seeder.dart"
import 'package:worm/worm.dart';

final class UsersSeeder extends Seeder {
  const UsersSeeder();

  @override
  String get name => 'UsersSeeder';

  @override
  Future<void> run(DatabaseAdapter adapter) async {
    await adapter.insert(
      const InsertDescriptor(
        table: 'users',
        values: <String, Object?>{
          'id': 1,
          'name': 'Alice',
          'email': 'alice@example.com',
        },
      ),
    );
  }
}
```

`worm make:seeder UsersSeeder` scaffolds this skeleton into `seeds/`, with a `// TODO` in `run` where your inserts go. Note that `name` has no default: every seeder must override it. The runner uses it for `--class` targeting and for tracking rows.

Three optional overrides tune how the runner treats a seeder:

```dart
final class DemoAccountsSeeder extends Seeder {
  const DemoAccountsSeeder();

  @override
  String get name => 'DemoAccountsSeeder';

  @override
  Environment get environment => Environment.development;

  @override
  int get order => 1;

  @override
  bool get muteEvents => true;

  @override
  Future<void> run(DatabaseAdapter adapter) async {
    // Bulk inserts without observer or hook overhead.
  }
}
```

- `environment` restricts where the seeder may run. `Environment` has five values: `development`, `staging`, `production`, `testing`, and `all`. Matching is exact, or `all`. The default is `Environment.all`.
- `order` sorts seeders ascending before the run. The default is `0`. The sort is stable, so ties keep registration order.
- `muteEvents` wraps `run` in `Worm.withoutEvents`, so model saves inside it skip lifecycle hooks and observers. Validation still runs; muting never disables it. See [lifecycle hooks and observers](../models/lifecycle-hooks-and-observers.md).

## Composing with DatabaseSeeder

A `DatabaseSeeder` is a master seeder that runs children sequentially, in the exact order you declare them:

```dart title="seeds/app_seeder.dart"
final class AppSeeder extends DatabaseSeeder {
  const AppSeeder();

  @override
  String get name => 'AppSeeder';

  @override
  List<Seeder> get seeders => const <Seeder>[
    UsersSeeder(),
    PostsSeeder(),
  ];
}
```

`DatabaseSeeder.run` calls each child's `run` directly. It applies no environment filter, no `order` sort, and no event muting to children: only the master's own `environment`, `order`, and `muteEvents` count, because the runner only sees the master. It also writes no tracking rows of its own.

## Running seeders from the CLI

`worm db:seed` runs every registered seeder that passes the environment filter and prints one `seeded  <name>` line per run. When nothing applies, it prints `No seeders applicable to <env> environment.` and still exits `0`.

The CLI reads seeders from the `CliContext(seeders: [...])` list your app's CLI entrypoint constructs. See [CLI commands](../reference/cli-commands.md) for the wiring.

| Flag | Effect |
| --- | --- |
| `--class=<Name>` | Run only the seeder whose `Seeder.name` matches. Skips the environment filter. An unknown name throws `ArgumentError`. |
| `--force` | Skip the environment filter for every seeder. |
| `--env=<name>` | Override the environment used for filtering. Parsing is case insensitive; an unrecognized value silently falls back to the context environment. |
| `--only=<Name>` | Deprecated alias for `--class`. |

Without `--env`, the environment comes from `WORM_ENV`, then `WormConfig.environment`, then `Environment.development`.

:::caution[--force is not a production gate]
On `db:seed`, `--force` means "ignore the environment filter". It has nothing to do with the production safety gate that `migrate:fresh --force` and `migrate:refresh --force` implement. A production-only seeder plus `db:seed --force` runs in development, not the other way around.
:::

## Running seeders in code

`SeederRunner` is the executor behind the CLI. You can drive it yourself, for example in a bootstrap script or a test helper:

```dart
final runner = SeederRunner(
  adapter: adapter,
  seeders: const <Seeder>[UsersSeeder(), DemoAccountsSeeder()],
  environment: Environment.development,
);
final ran = await runner.run(); // names that actually ran
```

`run` returns the names of every seeder that executed. `run(seederClass: 'UsersSeeder')` targets one seeder by exact name and skips the environment filter, just like `--class`. `run(force: true)` mirrors `--force`.

## Idempotent tracking with worm_seeders

By default, seeders run every time. To make runs idempotent, pass a `SeederRecordStore` to the runner. The store keeps one row per seeder name in the `worm_seeders` table (`name` as text primary key, `executed_at` as a UTC timestamp):

```dart
final store = SeederRecordStore(adapter);
final runner = SeederRunner(
  adapter: adapter,
  seeders: const <Seeder>[UsersSeeder()],
  environment: Environment.development,
  store: store,
);

final first = await runner.run();  // ['UsersSeeder']
final second = await runner.run(); // [] - already recorded, skipped
```

With a store configured, the runner calls `ensureTable()` first (an idempotent `CREATE TABLE IF NOT EXISTS`), skips any seeder whose name already has a record, and inserts a record after each successful run. This also applies to `--class` style targeted runs: a tracked seeder is skipped even when named explicitly.

:::note[The CLI does not track runs]
This is verified against the source: `worm db:seed` constructs its `SeederRunner` without a store, and so does `worm migrate:fresh --seed`. Every CLI invocation re-runs every applicable seeder. Tracking is programmatic only. If you need run-once semantics, wire `SeederRecordStore` yourself as shown above, or write seeders that are safe to repeat.
:::

## Seeding after fresh migrations

`worm migrate:fresh --seed` drops the migration log, re-applies every migration, then runs all registered seeders through a `SeederRunner` with the active environment filter (and, as noted above, no tracking store). It prints a `seeded  <name>` line per seeder. See [migrations](./migrations.md) for the rest of the `migrate` family.

## Seeding with factories

For volume and variety, call [factories](../models/factories.md) inside `run`. `Factory.create()` persists through `Model.save()`, so hooks and validation fire, and `Worm.initialize` must have run. Call `Worm.seedRandom(42)` first when you want the same fake data on every run.

## Gotchas

- `worm db:seed` and `migrate:fresh --seed` never wire a `SeederRecordStore`. CLI seeding re-runs everything, every time.
- `db:seed --force` bypasses the environment filter, not production safety.
- `--class` (and `seederClass:`) skips the environment filter entirely; an unknown name throws `ArgumentError`.
- `DatabaseSeeder` invokes children directly: a child's own `environment`, `order`, and `muteEvents` overrides are ignored when it runs inside a master.
- `Seeder.name` has no default. Forgetting it is a compile error; giving two seeders the same name breaks `--class` targeting and tracking.
- `muteEvents` suppresses hooks and observers only. Validation still runs.
- `db:seed --env` falls back silently to the context environment when the value does not parse.
- `SeederRecordStore` is constructor injected and never reads `Worm.adapter()`. Pass it the same adapter the runner uses.

## API summary

| Symbol | Signature sketch | One-liner |
| --- | --- | --- |
| `Seeder` | `abstract base class`, `const Seeder()` | Base class every user seeder extends. |
| `Seeder.name` | `String get name` | Required identifier; used by `--class` and tracking. |
| `Seeder.environment` | `Environment get environment => Environment.all` | Environment gate; exact match or `all`. |
| `Seeder.order` | `int get order => 0` | Ascending sort key; stable ties. |
| `Seeder.muteEvents` | `bool get muteEvents => false` | Wraps `run` in `Worm.withoutEvents` when `true`. |
| `Seeder.run` | `Future<void> run(DatabaseAdapter adapter)` | The seed work. |
| `DatabaseSeeder` | `abstract base class DatabaseSeeder extends Seeder` | Master seeder; runs `seeders` sequentially, no tracking of its own. |
| `DatabaseSeeder.seeders` | `List<Seeder> get seeders` | Children, executed in declared order. |
| `Environment` | `enum { development, staging, production, testing, all }` | Runtime environments for filtering. |
| `SeederRunner` | `const SeederRunner({required adapter, required seeders, required environment, SeederRecordStore? store})` | Sorts, filters, tracks, and executes seeders. |
| `SeederRunner.run` | `Future<List<String>> run({String? seederClass, bool force = false})` | Runs applicable seeders; returns the names that ran. |
| `SeederRunner.shouldRun` | `bool shouldRun(Seeder seeder)` | Environment check for one seeder. |
| `SeederRunner.runOne` | `Future<void> runOne(String name)` | Legacy alias for `run(seederClass: name)`. |
| `SeederRecord` | `const SeederRecord({required String name, required DateTime executedAt})` | One tracking row; `toMap()`, `fromRow()` (throws `FormatException` on a bad shape). |
| `SeederRecord.tableName` | `static const String tableName = 'worm_seeders'` | The tracking table name. |
| `SeederRecordStore` | `const SeederRecordStore(DatabaseAdapter adapter)` | Adapter-backed CRUD over `worm_seeders`. |
| `SeederRecordStore.ensureTable` | `Future<void> ensureTable()` | Idempotent `CREATE TABLE IF NOT EXISTS`. |
| `SeederRecordStore.hasRun` | `Future<bool> hasRun(String name)` | Whether a seeder name is already recorded. |
| `SeederRecordStore.record` | `Future<void> record(String name, {DateTime? executedAt})` | Persist a run record; defaults to UTC now. |
| `SeederRecordStore.all` | `Future<List<SeederRecord>> all()` | Every stored record. |

## Continue reading

- [Factories](../models/factories.md): generate realistic model data for seeders and tests.
- [Migrations](./migrations.md): the schema those seed rows land in, plus `migrate:fresh --seed`.
- [CLI commands](../reference/cli-commands.md): the full `worm db:seed` flag reference and `CliContext` wiring.
- [Production guide](../guides/production.md): what to seed (and not seed) outside development.
