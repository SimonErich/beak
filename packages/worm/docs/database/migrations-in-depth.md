---
title: Migrations in depth
description: Dependency ordering, pretend mode, auto-generated migrations, squashing, and the exact failure semantics of the migration runner.
---

This page covers the advanced migration machinery: what runs when, what can fail, and what the tooling generates for you. It builds on [migrations](./migrations.md) and the [schema builder](./schema-builder.md).

## Ordering with dependsOn

By default, migrations run in registration order. When that is not enough (for example, a foreign key that needs its parent table first regardless of file naming), declare prerequisites by name:

```dart
final class CreatePostsTable extends Migration {
  const CreatePostsTable();

  @override
  String get name => '20260102_000000_create_posts_table';

  @override
  List<String> get dependsOn => ['20260101_000000_create_users_table'];

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create('posts', (table) {
      table.idUuid();
      table.uuid('user_id');
      table.string('title');
    });
  }

  @override
  Future<void> downSchema(Schema schema) async {
    await schema.drop('posts', ifExists: true);
  }
}
```

The `MigrationRunner` constructor sorts the registered list with a stable Kahn topological sort:

- A migration always runs after every entry in its `dependsOn`, regardless of registration order.
- Migrations with an empty `dependsOn` keep their registration order exactly. If you never use `dependsOn`, nothing changes.
- Ties among ready migrations resolve by registration position, so the sort is deterministic.

Two errors surface at construction time, before anything touches the database:

- An unknown name in `dependsOn` throws `MigrationException` with the message `declares unknown dependency "<name>"`.
- A cycle throws `MigrationException` naming every migration that participates: `Dependency cycle detected among migrations: '<a>', '<b>'. Break the cycle by removing one of the dependsOn entries.`

## Pretend mode

`worm migrate --pretend` (or `runner.pretend()`) shows you what every pending migration would execute, without executing it:

```dart
final runner = MigrationRunner(adapter: adapter, migrations: migrations);
final captured = await runner.pretend(); // Map<String, List<String>>
for (final entry in captured.entries) {
  print('-- ${entry.key}');
  entry.value.forEach(print);
}
```

The result maps each pending migration's name to the list of compiled statements it would run, in execution order. Already-applied migrations are skipped.

Under the hood, the runner wraps your real adapter in a `PretendAdapter` and runs each `upSchema` against it. The wrapper records every descriptor call (writes, DDL, and reads alike) by delegating to the real adapter's `compileToString`, so the captured statements match your target backend's syntax. Reads still return empty results, `transaction` just invokes its callback, and `rawQuery`/`rawExecute` are recorded as `RAW QUERY: ...` / `RAW EXECUTE: ...` entries.

:::caution[Pretend runs your Dart code]
Pretend mode intercepts adapter calls, nothing else. Your `upSchema` body executes for real, so file writes, HTTP calls, or any other side effects inside a migration happen during a dry run too. Legacy `up(adapter)` migrations receive the `PretendAdapter` through `schema.adapter`, so their database calls are captured the same way, but their non-database code also runs. Keep migrations free of side effects that are not adapter calls.
:::

`MigrationPretendLog` and `MigrationPretendEntry` are exported value types for structured dry-run logs, but note that `runner.pretend()` currently returns a plain `Map<String, List<String>>`, not a `MigrationPretendLog`.

## Auto-generated migrations

`worm make:migration <name> --auto` generates the migration body for you by diffing a declared target schema against the live database:

```bash
dart run worm make:migration sync_schema --auto
```

The command connects via your `CliContext.adapterFactory`, builds a `MigrationAutoGenerator` with the project root, and writes the rendered source to `migrations/<timestamp>_<name>.dart`. It refuses to overwrite an existing file (exit code 65).

### The target schema file

The generator reads `schema/schema.json` from your project root. Its shape:

```json title="schema/schema.json"
{
  "tables": [
    {
      "name": "users",
      "columns": [
        { "name": "id", "type": "uuid", "isPrimaryKey": true },
        { "name": "email", "type": "string" },
        { "name": "age", "type": "integer", "nullable": true }
      ]
    }
  ]
}
```

`type` must be a `ColumnType` enum name. `nullable` and `isPrimaryKey` default to `false`. A missing file throws `MigrationException`; malformed JSON or an unknown type name throws `FormatException`.

### What the generator emits

The generator introspects the live database, runs `DiffEngine.diff(from: live, to: target)`, and renders one `Migration` subclass:

- A new table becomes a `schema.create(...)` block with one column call per column (`..primary()` on the primary key, `..makeNullable()` on nullable columns).
- A new column on an existing table becomes a `schema.alter(...)` block adding it.
- A removed column becomes a `schema.alter(...)` block with `table.dropColumn(...)`.
- A removed table becomes `schema.drop('<table>');`.
- Type and nullability changes become `// TODO: ... requires manual review.` comments. The generator never guesses at data-rewriting DDL.
- The generated `downSchema` drops every added table with `ifExists: true` and leaves a `// TODO:` stub asking you to recreate each dropped table.

When the diff is empty, the body is `// No schema changes detected.`

### Limits

- Live introspection returns table and column names only, no types. Every live column is assumed to be `ColumnType.text`, so on existing tables the diff reports a type change for nearly every non-text column in your target. Those all land as TODO comments. Structural changes (added or dropped tables and columns) are the reliable part.
- `enumType` and `array` columns render as `table.text(...)` calls in generated code. Adjust them by hand.
- Generated `schema.alter(...)` blocks currently fail at execution time on every shipped adapter (see [what reaches your database](./schema-builder.md#what-reaches-your-database)). Rewrite them as raw DDL before running the migration.
- Review every `--auto` migration before applying it. It is a starting point, not a finished artifact.

## Diff semantics

`DiffEngine.diff` compares two `List<TableSchema>` snapshots and returns a `SchemaDiff` whose `changes` are `SchemaChange` values. Each change carries a `destructive` flag:

| Change | `SchemaChangeKind` | Destructive? |
| --- | --- | --- |
| New table | `addTable` (plus one `addColumn` per column) | No |
| Dropped table | `dropTable` | Yes |
| New nullable column on an existing table | `addColumn` | No |
| New NOT NULL column on an existing table | `addColumn` | Yes |
| Column type changed | `changeColumnType` | Yes |
| Column went nullable to NOT NULL | `changeColumnNullable` | Yes |
| Column went NOT NULL to nullable | `changeColumnNullable` | No |
| Dropped column | `dropColumn` | Yes |

`SchemaDiff` exposes `hasDestructive`, `isEmpty`, and `destructiveChanges` so tooling can gate on data loss. Do not use `SchemaDiff.tablesIn(kind)`: it is a stub that always returns an empty list.

## Squashing with schema:dump

Once a project has hundreds of migrations, you can snapshot the live schema and delete the history:

```bash
dart run worm schema:dump                  # write the snapshot only
dart run worm schema:dump --prune --force  # snapshot, then delete migrations/*.dart
```

The dump introspects the live database and writes `schema/schema_dump.dart`, a generated Dart file containing a single `const Map<String, List<String>> schemaDump` constant mapping each table to its column names, with tables sorted for reproducible output. The file is overwritten on every run.

`--prune` then deletes every `.dart` file directly under `migrations/`. Because that is irreversible, `--prune` requires `--force` in every environment, not just production. Without it, the command writes an explanatory error to stderr and exits with code 1. On success it prints `pruned  N migration file(s).`

Note that `schema_dump.dart` and `schema/schema.json` are different files with different formats. The dump is a names-only snapshot for inspection and squash bookkeeping; it is not read back by `make:migration --auto`.

## Irreversible migrations

Some migrations cannot be undone (a data backfill that rewrote rows in place, for example). Signal that by throwing from the down path:

```dart
@override
Future<void> downSchema(Schema schema) async {
  throw const IrreversibleMigrationException(
    migration: '20260103_000000_backfill_emails',
    message: 'cannot roll back',
    reason: 'source column was dropped after the backfill',
  );
}
```

`IrreversibleMigrationException` extends `WormException` directly and carries the migration name plus an optional `reason`. Be aware that the runner wraps every failure from `downSchema` in a `MigrationException` whose message starts with `down() failed:`, so callers of `runner.rollback()` catch a `MigrationException` that embeds the irreversible exception's text rather than the original exception type.

## isDestructive

`Migration` declares `bool get isDestructive => false` so migrations can mark themselves as data-destroying, with the stated intent that runners gate such migrations behind `--force`. Today, `MigrationRunner` does not read this flag anywhere. Overriding it changes nothing at execution time. Destructive-run protection currently lives one level up, at the CLI (next section). Treat `isDestructive` as documentation plus forward compatibility, not as a safety net.

## Production gating

The CLI decides the active environment from `WORM_ENV` (trimmed, case-insensitive; only the exact word `production` counts). Two commands refuse to run in production without `--force`:

- `worm migrate:fresh`
- `worm migrate:refresh`

On refusal they write `error: refusing to run destructive command in production without --force` to stderr and exit with code 1. The check is implemented by `ensureForceForProduction` (returns `false` on refusal) and `ProductionGuard.enforceForce` (calls an injectable `exit(1)`), both exported for your own tooling; each consults `CliContext.isProduction`. `isProductionWormEnv(String?)` is also exported, a pure predicate for testing a raw `WORM_ENV` string.

Two gaps to know about:

- `worm migrate:rollback` has no production gate. Rolling back drops schema via your `downSchema` code, so guard deployment scripts accordingly.
- `worm schema:dump --prune` is gated by `--force` in every environment, as covered above; that gate is about file deletion, not the database.

See [production](../guides/production.md) for the full deployment checklist.

## Failure semantics

The runner keeps its bookkeeping honest but does not make migrations atomic:

- Migrations are not wrapped in a transaction. Each statement executes individually against the adapter.
- The `worm_migrations` tracking row is inserted only after a migration's `upSchema` completes. A failure mid-migration leaves no tracking row, so the next `migrate` retries the whole migration against whatever partial DDL the failure left behind. Write migrations so a partial re-run can succeed (`ifExists:`/`ifNotExists:` where available), or clean up manually before retrying.
- Any exception from `upSchema`/`downSchema` is wrapped in `MigrationException` with the prefix `up() failed:` or `down() failed:` and the migration's name attached.
- Rollback resolves recorded names against the registered list. A recorded migration that is no longer registered throws `MigrationException` with the message `Recorded migration not present in registered list`.
- A malformed tracking row (wrong column types) throws `MigrationException` with a `Corrupt worm_migrations row:` message.

## Alternate history stores

`MigrationRunner` persists history through `MigrationRecordStore`, adapter-backed CRUD over `worm_migrations` (`ensureTable`, `dropTable`, `all`, `appliedNames`, `maxBatch`, `namesInBatch`, `insert`, `remove`). The package also exports a separate `MigrationRepository` contract (`initialize`, `all`, `record`, `forget`, `latestBatch`) with an `InMemoryMigrationRepository` implementation for tests and CI. The repository is an alternate persistence interface for custom tooling; the runner itself always uses `MigrationRecordStore`. `InMemoryMigrationRepository` throws `StateError` if used before `initialize()`.

## Gotchas

- `Migration.isDestructive` is not consulted by the runner. Do not rely on it to block anything.
- `SchemaDiff.tablesIn(kind)` always returns an empty list. Use `changes` and filter by `SchemaChangeKind` instead.
- Pretend mode executes non-adapter side effects in your migration code.
- `runner.pretend()` returns a plain map; `MigrationPretendLog` exists but is not what the runner returns.
- `--auto` reports spurious type changes on existing tables because live columns are introspected without types and assumed `text`.
- `--auto` generated `schema.alter` blocks throw on all shipped adapters until alter support lands.
- `IrreversibleMigrationException` reaches you wrapped inside a `MigrationException` when thrown during `runner.rollback()`.
- `worm migrate:rollback` has no production `--force` gate.
- Dependency errors (`dependsOn` unknown name or cycle) throw when `MigrationRunner` is constructed, not when `migrate()` runs.
- `MigrationAutoGenerator` and `MigrationDependencySorter` are internal: they are not exported from `package:worm/worm.dart`. Reach them through `worm make:migration --auto` and the `MigrationRunner` constructor respectively.

## API summary

### Migration and runner

| Symbol | Signature sketch | One-liner |
| --- | --- | --- |
| `Migration` | abstract base; `name`, `isDestructive`, `dependsOn`, `up(adapter)`, `down(adapter)`, `upSchema(schema)`, `downSchema(schema)` | Base class every migration extends; override the `upSchema`/`downSchema` pair |
| `MigrationRunner` | `MigrationRunner({required adapter, required migrations, seeders = const [], environment = Environment.development})` | Orchestrator; constructor toposorts by `dependsOn` |
| `MigrationRunner.migrate` | `Future<List<String>> migrate({int? step})` | Apply pending migrations as one batch; returns applied names |
| `MigrationRunner.run` | `Future<List<String>> run({int? step})` | Alias for `migrate`, matching CLI naming |
| `MigrationRunner.pretend` | `Future<Map<String, List<String>>> pretend()` | Capture compiled statements per pending migration; executes nothing |
| `MigrationRunner.rollback` | `Future<List<String>> rollback({int steps = 1})` | Revert the last N batches; descending name order within a batch |
| `MigrationRunner.refresh` | `Future<void> refresh()` | Roll back every batch, then re-apply all |
| `MigrationRunner.fresh` | `Future<List<String>> fresh({bool seed = false})` | Drop the tracking table, re-apply all as batch 1; optionally seed; returns seeder names run |
| `MigrationRunner.status` | `Future<List<MigrationStatus>> status()` | Applied/pending report for every registered migration |

### Records and stores

| Symbol | Signature sketch | One-liner |
| --- | --- | --- |
| `migrationsTable` | `const String` = `'worm_migrations'` | Name of the tracking table |
| `MigrationRecord` | `{name, batch, appliedAt}`; `toMap()` | One tracking-table row |
| `MigrationStatus` | `{name, state, batch?}`; `toMap()`, `toString()` | One `migrate:status` row; renders `[x] name (batch N)` or `[ ] name` |
| `MigrationState` | `pending`, `applied` | Migration lifecycle state |
| `MigrationRecordStore` | `const MigrationRecordStore(adapter)`; `ensureTable`, `dropTable`, `all`, `appliedNames`, `maxBatch`, `namesInBatch`, `insert`, `remove` | Adapter-backed CRUD over `worm_migrations`; runner plumbing |
| `MigrationRepository` | abstract; `initialize`, `all`, `record`, `forget`, `latestBatch` | Alternate persistence contract for migration history |
| `InMemoryMigrationRepository` | `InMemoryMigrationRepository()` | In-memory `MigrationRepository` for tests; `StateError` before `initialize()` |

### Diffing

| Symbol | Signature sketch | One-liner |
| --- | --- | --- |
| `DiffEngine` | static `diff({required List<TableSchema> from, required List<TableSchema> to})` | Diff two schema snapshots; flags destructive changes |
| `SchemaDiff` | `changes`, `hasDestructive`, `isEmpty`, `destructiveChanges`; `SchemaDiff.empty()` | Aggregated diff result (`tablesIn` is a stub) |
| `SchemaChange` | `{kind, table, column?, previousType?, newType?, previousNullable?, newNullable?, destructive}`; `toMap()` | One detected change |
| `SchemaChangeKind` | `addTable`, `dropTable`, `addColumn`, `dropColumn`, `changeColumnType`, `changeColumnNullable` | Kind of detected change |

### Pretend-mode types

| Symbol | Signature sketch | One-liner |
| --- | --- | --- |
| `PretendAdapter` | `PretendAdapter(DatabaseAdapter delegate)`; `List<String> get statements` | Recording `DatabaseAdapter`; compiles instead of executing |
| `MigrationPretendLog` | `MigrationPretendLog(entries)`; `.empty()`, `isEmpty` | Typed dry-run log container (not returned by the runner today) |
| `MigrationPretendEntry` | `{migration, sql}`; `toMap()` | One typed dry-run entry |

### Exceptions

| Symbol | Signature sketch | One-liner |
| --- | --- | --- |
| `MigrationException` | `MigrationException({required migration, required message})` extends `AdapterException` | Wraps any up/down failure, unknown or cyclic `dependsOn`, unregistered recorded migration, corrupt tracking row, missing `schema/schema.json` |
| `IrreversibleMigrationException` | `IrreversibleMigrationException({required migration, required message, String? reason})` extends `WormException` | Throw from `downSchema` when a migration cannot be reversed |

## Continue reading

- [Production](../guides/production.md): deploy patterns, environment semantics, and the full destructive-command checklist.
- [CLI commands](../reference/cli-commands.md): every `worm` command, flag, and exit code in one place.
- [Schema builder](./schema-builder.md): the DSL these tools generate and execute, including the alter caveat.
- [Exceptions](../reference/exceptions.md): where `MigrationException` and `IrreversibleMigrationException` sit in the hierarchy.
