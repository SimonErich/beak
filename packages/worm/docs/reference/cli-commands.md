---
title: CLI commands
description: Every worm CLI command with all flags, defaults, output formats, exit codes, and force-gate semantics.
---

This page documents all 15 `worm` CLI commands: synopsis, every flag with its default, output format, and exit codes. For one-line summaries see the [cheatsheet](./cheatsheet.md#cli-commands).

## Running the CLI

```bash
dart run worm <command>        # from a project that depends on worm
dart run worm:worm <command>   # explicit package:executable form
dart run worm --help           # global usage, exit 0
dart run worm help <command>   # per-command usage
```

With no arguments or `--help`, the runner prints usage to stdout and exits `0`. An unknown command or flag prints the error to stderr and exits `2`.

## Wiring your project context

The `bin/worm.dart` that ships with the package registers nothing: empty `migrations`, `seeders`, and `models` lists, and a default `adapterFactory` that builds a connected `InMemoryAdapter`. Scaffolding commands (`init`, `make:*`, `gen`) work out of the box. Database commands (`migrate*`, `db:seed`, `schema:dump`, `model:show`) only act on what you register, so create your own entrypoint:

```dart title="bin/worm.dart"
import 'dart:io';

import 'package:worm/worm.dart';

import '../migrations/20260101_120000_create_users_table.dart';
import '../seeds/user_seeder.dart';

Future<void> main(List<String> args) async {
  final context = CliContext(
    out: stdout,
    err: stderr,
    projectRoot: Directory.current,
    environment: Worm.environment, // resolves WORM_ENV
    now: DateTime.now,
    adapterFactory: () async {
      final adapter = InMemoryAdapter(); // swap in your real driver adapter
      await adapter.connect();
      return adapter;
    },
    migrations: const <Migration>[CreateUsersTable()],
    seeders: const <Seeder>[UserSeeder()],
    models: const <ModelInfo>[
      ModelInfo(
        name: 'User',
        tableName: 'users',
        fields: <ModelField>[
          ModelField(name: 'id', type: 'uuid'),
          ModelField(name: 'name', type: 'string'),
        ],
        relations: <ModelRelation>[
          ModelRelation(name: 'posts', kind: 'hasMany', target: 'Post'),
        ],
      ),
    ],
  );
  final code = await WormCommandRunner(context).run(args) ?? 0;
  if (code != 0) exit(code);
}
```

:::caution[The default adapter is in-memory]
Until you wire a real `adapterFactory`, `migrate` and `db:seed` run against a fresh `InMemoryAdapter` and change nothing in your actual database. They still exit `0`.
:::

`ModelInfo`, `ModelField`, and `ModelRelation` are CLI-side descriptors consumed by `model:show`. The `type` and `kind` values are free-form strings; populate them from your own model list. `CliContext` also exposes the directory conventions the commands write into: `migrationsDir` (`migrations/`), `seedsDir` (`seeds/`), `modelsDir` (`lib/models/`), `factoriesDir` (`lib/factories/`).

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success, including no-op runs ("Nothing to migrate.", "Already exists") |
| `1` | Force-gate refusal (`migrate:fresh`/`migrate:refresh` in production, `schema:dump --prune` without `--force`); `model:show` with an unregistered model |
| `2` | Usage error: unknown command or flag |
| `64` | Missing required positional argument (`make:*`, `model:show`) |
| `65` | Refusing to overwrite an existing file (`make:*`) |
| other | `gen` returns the exit code of the `build_runner` child process |

## Environments and force gates

The environment comes from `Worm.environment`: the `WORM_ENV` environment variable wins (matched against the `Environment` enum names `development`, `staging`, `production`, `testing`, `all`, case-insensitively), then `WormConfig.environment`, then `Environment.development`.

| Gate | Commands | Semantics |
|---|---|---|
| Production `--force` | `migrate:fresh`, `migrate:refresh` | In production without `--force`: writes `error: refusing to run destructive command in production without --force` to stderr and exits `1`. Outside production the flag is accepted but unnecessary. |
| Always `--force` | `schema:dump --prune` | Pruning deletes migration files irreversibly, so `--force` is required in every environment, not just production. |
| Not a safety gate | `db:seed --force` | Means something different: it bypasses the seeder environment filter. It has nothing to do with production protection. |

The helpers behind this are exported: `isProductionWormEnv(String?)` (pure predicate), `ensureForceForProduction({context, force})` (returns `false` and writes the diagnostic), and `ProductionGuard` (variant that calls `exit(1)` through an injectable `ExitFn`).

## Command index

| Command | Synopsis |
|---|---|
| [`init`](#init) | `worm init` |
| [`make:model`](#makemodel) | `worm make:model <ClassName> [--all]` |
| [`make:migration`](#makemigration) | `worm make:migration <snake_case_name> [--table <table>] [--auto]` |
| [`make:seeder`](#makeseeder) | `worm make:seeder <ClassName> [--table <table>]` |
| [`make:factory`](#makefactory) | `worm make:factory <ClassName> [--model <ModelClass>]` |
| [`make:observer`](#makeobserver) | `worm make:observer <ClassName> [--model <ModelClass>]` |
| [`migrate`](#migrate) | `worm migrate [--pretend] [--step=N]` |
| [`migrate:rollback`](#migraterollback) | `worm migrate:rollback [--steps=N]` |
| [`migrate:status`](#migratestatus) | `worm migrate:status` |
| [`migrate:fresh`](#migratefresh) | `worm migrate:fresh [--seed] [--force]` |
| [`migrate:refresh`](#migraterefresh) | `worm migrate:refresh [--force]` |
| [`db:seed`](#dbseed) | `worm db:seed [--class=<Name>] [--env=<name>] [--force] [--only=<Name>]` |
| [`schema:dump`](#schemadump) | `worm schema:dump [--prune] [--force]` |
| [`model:show`](#modelshow) | `worm model:show <ModelName>` |
| [`gen`](#gen) | `worm gen [--watch] [--clean] [--[no-]delete-conflicting-outputs]` |

### init

```bash
worm init
```

Scaffolds the prescribed project layout. No flags. Creates 18 `lib/src/` subdirectories (`adapter`, `cast`, `cli`, `config`, `exception`, `factory`, `logging`, `migration`, `model`, `naming`, `observer`, `predicate`, `query`, `registry`, `relation`, `schema`, `seeder`, `validation`), the root directories `migrations/`, `seeds/`, `lib/models/`, `lib/factories/`, `config/`, and writes a `config/worm_config.dart` template containing a `WormConfig` with a commented-out `ConnectionConfig` entry.

Idempotent: existing directories and files are left untouched and reported as `Already exists  <path>`. New items print `created         <path>`. Always exits `0`.

### make:model

```bash
worm make:model <ClassName> [--all]
```

| Flag | Default | Effect |
|---|---|---|
| `--all`, `-a` | off | Also generate a migration, seeder, and factory |

Writes `lib/models/<snake_case>.dart`: a `@Table(name: '<table>')` model class extending `Model` with a `late final String id`. The table name comes from `tableNameFor(ClassName)` (naive pluralizer, see [naming helpers](#naming-helpers)).

With `--all`, three siblings are planned as well:

- `migrations/<timestamp>_create_<table>_table.dart` with class `Create<ClassName>sTable`
- `seeds/<snake_case>_seeder.dart` with class `<ClassName>Seeder`
- `lib/factories/<snake_case>_factory.dart` with class `<ClassName>Factory`

All target paths are checked before anything is written: if any file exists, nothing is written and the command exits `65` (all-or-nothing). Missing class name exits `64`. Each written file prints `created  <relative path>`.

### make:migration

```bash
worm make:migration <snake_case_name> [--table <table>] [--auto]
```

| Flag | Default | Effect |
|---|---|---|
| `--table`, `-t` | the migration name | Table the migration targets (used in the skeleton body) |
| `--auto` | off | Generate the body by diffing `schema/schema.json` against the live database schema |

Writes `migrations/<timestamp>_<name>.dart`. The timestamp is `migrationTimestamp(context.now())`, a UTC `YYYYMMDD_HHMMSS` string. The class name is `snakeToPascal(name)`, and the generated `name` getter returns the full file base so the tracking table entry matches the filename. The skeleton's `upSchema` creates the table with `table.idUuid()`; `downSchema` drops it with `ifExists: true`.

With `--auto`, the command builds the adapter from `adapterFactory`, introspects the live schema, diffs it against the target snapshot in `schema/schema.json`, and writes a migration whose `upSchema` body applies the difference. A missing `schema/schema.json` throws `MigrationException`; malformed JSON throws `FormatException`. Introspection has no type information, so type and nullability changes surface as TODO comments for manual review.

Missing name exits `64`; existing target file exits `65`.

### make:seeder

```bash
worm make:seeder <ClassName> [--table <table>]
```

| Flag | Default | Effect |
|---|---|---|
| `--table`, `-t` | `pascalToSnake(ClassName)` | Table named in the skeleton's TODO comment (informational only) |

Writes `seeds/<snake_case>.dart` with a `Seeder` subclass whose `name` returns the class name and whose `run(DatabaseAdapter adapter)` body is a TODO. Missing name exits `64`; existing file exits `65`.

### make:factory

```bash
worm make:factory <ClassName> [--model <ModelClass>]
```

| Flag | Default | Effect |
|---|---|---|
| `--model`, `-m` | class name with a trailing `Factory` stripped (`UserFactory` becomes `User`; no suffix leaves it unchanged) | Model class the factory builds |

Writes `lib/factories/<snake_case>.dart` with a `Factory<Model>` subclass and a `definition()` stub. Missing name exits `64`; existing file exits `65`.

### make:observer

```bash
worm make:observer <ClassName> [--model <ModelClass>]
```

| Flag | Default | Effect |
|---|---|---|
| `--model`, `-m` | class name with a trailing `Observer` stripped | Model class the observer watches |

Writes `lib/src/observer/<snake_case>.dart` with an empty `Observer<Model>` subclass. Missing name exits `64`; existing file exits `65`.

### migrate

```bash
worm migrate [--pretend] [--step=N]
```

| Flag | Default | Effect |
|---|---|---|
| `--pretend` | off | Print compiled SQL without executing anything |
| `--step=N` | unset (apply all) | Apply at most N pending migrations |

Builds a `MigrationRunner` from `context.migrations` against `context.adapterFactory()` and applies every pending migration as one batch. Prints `migrated  <name>` per applied migration, or `Nothing to migrate.` when there is nothing pending. Exits `0` either way.

With `--pretend`, each pending migration prints a `-- <name>` header followed by its compiled statements, then a final dry-run confirmation line. No database changes and no tracking rows are written. Note that raw Dart code inside a legacy `up(adapter)` migration still executes during pretend; only adapter calls are intercepted and recorded.

### migrate:rollback

```bash
worm migrate:rollback [--steps=N]
```

| Flag | Default | Effect |
|---|---|---|
| `--steps=N` | `1` | Number of batches to roll back |

Reverts the last N batches; within a batch, migrations revert in descending name order. Prints `reverted  <name>` per migration, or `Nothing to roll back.` A recorded migration that is no longer in the registered list throws `MigrationException`.

### migrate:status

```bash
worm migrate:status
```

No flags. Prints a column-aligned table:

```text
Migration                              | Batch | Status
------------------------------------------------------
[x] 20260101_120000_create_users_table | 1     | applied
[ ] 20260102_090000_add_age_to_users   | -     | pending
```

Prints `No migrations registered.` when the context has no migrations. Always exits `0`.

### migrate:fresh

```bash
worm migrate:fresh [--seed] [--force]
```

| Flag | Default | Effect |
|---|---|---|
| `--seed` | off | Run all registered seeders after migrations re-apply |
| `--force` | off | Required when `WORM_ENV=production` |

Drops the `worm_migrations` tracking table and re-applies every registered migration as batch 1. Prints `migrate:fresh complete (N migration(s) applied).` followed by one `seeded  <name>` line per seeder that ran. In production without `--force`, writes the refusal diagnostic to stderr and exits `1`.

Seeding through `--seed` goes through the same environment filter as `db:seed`, using `context.environment`.

### migrate:refresh

```bash
worm migrate:refresh [--force]
```

| Flag | Default | Effect |
|---|---|---|
| `--force` | off | Required when `WORM_ENV=production` |

Rolls back every applied batch, then re-applies all migrations. Prints `migrate:refresh complete.` Same production gate as `migrate:fresh`: exit `1` without `--force` in production.

### db:seed

```bash
worm db:seed [--class=<SeederName>] [--env=<name>] [--force] [--only=<SeederName>]
```

| Flag | Default | Effect |
|---|---|---|
| `--class=<SeederName>` | unset | Run only the seeder whose `Seeder.name` matches exactly. Skips the environment filter for that seeder. Unknown name throws `ArgumentError`. |
| `--env=<name>` | `context.environment` | Override the environment used for filtering. Case-insensitive; an unrecognized value silently falls back to the context environment. |
| `--force` | off | Skip the environment filter and run every registered seeder |
| `--only=<SeederName>` | unset | Deprecated alias for `--class` (`--class` wins when both are given) |

Builds a `SeederRunner` over `context.seeders`, sorted by `Seeder.order` (stable sort; ties keep registration order) and filtered by environment. Prints `seeded  <name>` per seeder that ran, or `No seeders applicable to <env> environment.` when nothing matched.

:::note
The CLI wires no `SeederRecordStore`, so `db:seed` re-runs every applicable seeder on every invocation. Idempotent run tracking via the `worm_seeders` table is available only when you construct a `SeederRunner` programmatically with a store. See [seeding](../database/seeding.md).
:::

### schema:dump

```bash
worm schema:dump [--prune] [--force]
```

| Flag | Default | Effect |
|---|---|---|
| `--prune` | off | Delete every `.dart` file directly under `migrations/` after the dump |
| `--force` | off | Acknowledge that `--prune` is irreversible |

Introspects the live schema through `adapterFactory()` and writes `schema/schema_dump.dart`: a generated `const Map<String, List<String>> schemaDump` with tables sorted alphabetically. The dump file is overwritten without an exists check. Prints `wrote   schema/schema_dump.dart`.

`--prune` without `--force` writes an error to stderr and exits `1` in every environment. With both flags, pruning prints `pruned  N migration file(s).` A missing `migrations/` directory prunes zero files.

### model:show

```bash
worm model:show <ModelName>
```

No flags. Looks up the name in `context.models` and prints:

```text
Model: User
Table: users
Fields:
  id: uuid
  name: string
Relations:
  posts: hasMany Post
```

Empty field or relation lists print `  (none)`. Missing argument exits `64`. An unregistered model prints `Model not found: <name>` to stderr and exits `1`.

### gen

```bash
worm gen [--watch] [--clean] [--[no-]delete-conflicting-outputs]
```

| Flag | Default | Effect |
|---|---|---|
| `--watch` | off | Spawn `dart run build_runner watch` with streamed output |
| `--clean` | off | Run `dart run build_runner clean` before the build step; abort if it fails |
| `--[no-]delete-conflicting-outputs` | on | Forward `--delete-conflicting-outputs` to `build_runner build` |

The default invocation spawns `dart run build_runner build --delete-conflicting-outputs` in `context.projectRoot` and returns the child's exit code. `--clean` runs first and aborts with the clean step's exit code when non-zero. `--watch` streams output and stays attached; it replaces the build step rather than combining with it.

## Naming helpers

These conversion functions back the `make:*` commands and are exported from `package:worm/worm.dart`.

| Helper | Example | Notes |
|---|---|---|
| `pascalToSnake(String)` | `'BlogPost'` to `'blog_post'` | |
| `snakeToPascal(String)` | `'blog_post'` to `'BlogPost'` | |
| `tableNameFor(String)` | `'User'` to `'users'`, `'Category'` to `'categories'` | Naive pluralizer: names already ending in `s` stay unchanged (`'Status'` stays `'status'`) |
| `migrationTimestamp(DateTime)` | `'20260101_120000'` | Always UTC; the input is normalized via `toUtc()` |

## Templates

The string-returning template functions used by `make:*` are exported so you can build your own scaffolding: `modelTemplate({className, table})`, `migrationTemplate({className, table, fileName})`, `seederTemplate({className, table})`, `factoryTemplate({className, modelClass})`, `observerTemplate({className, modelClass})`, and `initReadme()`. Note that `initReadme()` exists but the current `init` command writes only `config/worm_config.dart`, not a README.

## Legacy

`CliRunner` and `CliResult` are an older minimal dispatcher (only `gen` and `--help`) that remain exported for compatibility. They are superseded by `WormCommandRunner` and not documented further.

## Continue reading

- [Cheatsheet](./cheatsheet.md): all commands in one table plus every other copy-paste block.
- [Migrations](../database/migrations.md): writing the migrations these commands run.
- [Seeding](../database/seeding.md): seeder authoring, ordering, and idempotent tracking.
- [Installation](../start-here/installation.md): first-time project setup and CLI wiring.
