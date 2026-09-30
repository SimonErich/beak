---
title: Migrations
description: Let Beak write the migration that creates a table, write or generate the ones that change it, and apply them as an explicit step.
type: guide
audience: [beginner, expert]
status: stable
---

# Migrations

Beak writes the migration that creates a table. You write, or generate, the ones that change it. After this page you can add a column to a table that already holds data, adopt a database Beak did not create, and test an upgrade against a snapshot of the old schema.

Migrations are ordinary files under `lib/migrations/`, and they run only when you say so. Nothing applies one at boot (a `sqlite::memory:` database is the single exception), and nothing rewrites one after Beak has written it. You never register one by hand: `beak prepare` finds them and lists them in `lib/beak/server.g.dart`.

## At a glance

| You did | Beak does | You run |
| --- | --- | --- |
| Added a new schema class | `beak prepare` writes `lib/migrations/create_<table>_table.dart`, once | `beak migrate` |
| Added a field to a schema class whose table exists | `beak doctor` warns about the missing column | `beak make:migration AddX --from-drift`, review it, `beak migrate` |
| Need a rename, a backfill or a drop | Nothing derivable | `beak make:migration Name`, write the body, `beak migrate` |
| Have a database Beak did not create | `beak introspect` writes classes and a baseline migration | `beak migrate` |

```bash
beak migrate status   # what is applied and what is pending
beak migrate          # apply everything pending, in one batch
```

The verbs and flags (`--pretend`, `--step`, `down`, `fresh`, `refresh`) are in [CLI commands](../reference/cli-commands.md#beak-migrate). This page is about what to put in the files.

## What a migration is

A migration extends worm's `Migration`, declares a `name`, and implements `upSchema(Schema)` and `downSchema(Schema)`. Import it through `package:beak/migrations.dart`, which also brings `BeakBlueprint`. (Worm's `Migration` has a raw `up(adapter)` and `down(adapter)` pair as well, for SQL you want to write yourself.)

The `name` is what orders migrations. Beak's generated names are `yyyymmdd_hhmmss_snake_case`, and `beak prepare` lists the migrations sorted by that name. The two tables Beak needs for itself come first, because their names are older than yours:

```console
$ beak migrate status
Migration                             | Batch | Status
------------------------------------------------------
[ ] 20260926_000000_beak_commit_receipts  | -     | pending
[ ] 20260927_000000_beak_outbox           | -     | pending
[ ] 20260929_162002_create_products_table | -     | pending
```

`_beak_commit_receipts` holds the receipts of graph saves and `_beak_outbox` the durable effects. Both are private tables, never exposed as resources, and never pruned unless you call `BeakOutbox.prune` (see [Durable effects](durable-effects.md#operate-it)). The receipts table keeps no timestamp, so Beak cannot age its rows out. Worm keeps its own log in `worm_migrations`. If a migration must run after another one that sorts later, worm honours `dependsOn` (a list of migration names) and orders them with a stable topological sort.

### Order

Migrations run in the order the generated host lists them, which is the order of their names with one correction. A create-table migration reads the model as it is now, so a table created in week one can have a foreign key to a table created in week three. A fresh database replays week one first, and Postgres rejects a `CREATE TABLE` that names a table that is not there yet. SQLite lets it pass, which is how it goes unnoticed. So `beak prepare` moves the migration that creates a table ahead of the first create-table migration whose foreign keys point at it, and leaves everything else where it was. A migration frozen to a table's first columns names no foreign key, so it stays where its name puts it, and a hand-written migration that adds a key to a later table declares `dependsOn`. `beak doctor` compares the host with the same order, so it is never called stale for it.

## The migration Beak writes

For a schema class with no migration, `beak prepare` writes one file and never touches it again. The quickstart's is the smallest real one:

```dart title="examples/quickstart/lib/migrations/create_notes_table.dart"
--8<-- "examples/quickstart/lib/migrations/create_notes_table.dart"
```

It reads the model. `BeakBlueprint.defineColumns` walks `NoteModel`'s columns and asks each one what it needs, so the table and the resource read from one declaration and cannot disagree. Tables are created in dependency order, a belongs-to target before the table that points at it.

One detail decides how you use this file: the migration reads the model *as it is now*. A database that has not run it gets every column the class declares today, including the ones you added last week. A database that has run it gets nothing new. That is why the next section exists, and why a project that has shipped often freezes its create migration. Freezing means swapping `defineColumns` for one `defineColumn` call per column the table had on day one, using the generated `ProductColumns` constants. The shop's is frozen to two columns, and later migrations add the rest:

```dart title="examples/clean_beak_config/lib/migrations/create_products_table.dart"
--8<-- "examples/clean_beak_config/lib/migrations/create_products_table.dart"
```

Freeze yours once you cannot rebuild the database from scratch. Until then, editing the class and rebuilding is faster.

### What `BeakBlueprint` derives

| Model says | Table gets |
| --- | --- |
| Primary key `id` | A `uuid` primary key |
| Column with a `BeakRequired` rule | `NOT NULL`. Every other column is nullable |
| Belongs-to relationship | A nullable `uuid` column, an index, and a foreign key honouring the relationship's `BeakOnDelete` |
| Two-state boolean | Default `false`. A nullable three-state boolean stays nullable |
| Enum with a default | That default as the schema default |
| Exact decimal, money, duration, file size | A scaled `bigInteger`, so no float touches a total |
| `column.unique`, `column.indexed` | A unique constraint, or an index |
| `BeakUnique` rule, with or without a scope | A composite unique index. Preflight validation gives the friendly error, the index wins a race |
| Soft-deleting model | `deleted_at`, emitted once even when the class declares it |

Many-to-many relationships get a pivot table from `BeakBlueprint.createPivot`: two foreign keys that cascade, a composite unique pair so membership cannot repeat, and an index on the second column so the relationship reads both ways. Beak writes `create_<pivot>_table.dart` for it too. When you write a foreign key yourself, use the relationship's real key names, not a guess from the class name.

## Changing a table that has data

Take a products table that already holds rows and add a field to its class:

```dart
  // Illustrative: a field added to a schema class after its table shipped.
  /// Units in stock.
  @Column(sortable: true)
  late final int? stock;
```

The create migration will not run again, so the database and the class now disagree. `beak doctor` says so without touching anything:

```console
$ beak doctor
  ...
  WARN products.stock is declared by Product.stock but missing from the database
       → beak make:migration AddStockToProducts --from-drift, then beak migrate
```

Beak can write that migration for you, from the difference between the classes and the live database:

```console
$ beak make:migration AddStockToProducts --from-drift
  created lib/migrations/add_stock_to_products.dart
  run `beak migrate` to apply it
```

```dart
  // Illustrative: the body of the file `--from-drift` wrote for that field.
  @override
  Future<void> upSchema(Schema schema) async {
    final live = await schema.adapter.introspectSchema();
    if (!_has(live, 'products', 'stock')) {
      await schema.alter('products', (table) {
        BeakBlueprint.defineColumn(table, ProductColumns.stock);
      });
    }
  }
```

Read the guard. A fresh database runs the create migration first, and that migration already made `stock`, so an unguarded `alter` would fail there with a duplicate column. Both `upSchema` and `downSchema` ask the database before they act, which lets the same file apply to an old database and to a new one, and roll back on either. `BeakBlueprint.defineColumn` derives the DDL from the same mapping the create migration used, so there is no second answer to what SQL a Beak column becomes. A belongs-to key comes out as an indexed foreign key with the same constraint the create migration makes.

Look at the SQL before you run it, then apply it:

```console
$ beak migrate --pretend
-- 20260929_162645_add_stock_to_products
ALTER TABLE "products" ADD COLUMN "stock" INTEGER
-- Params: []
Dry run complete — no changes made.
$ beak migrate
migrated  20260929_162645_add_stock_to_products
```

### When Beak stops and asks

Some columns cannot be added without a decision, and the command writes nothing until you have made it. Each is reported with `!` and exits `1`:

```console
$ beak make:migration AddWeight --from-drift
  ! products.weight: a required column needs a value for the rows already there; give it `@Column(defaultValue: ...)`, or make it nullable and backfill
  ! products.barcode: SQLite cannot add a unique column to an existing table; declare it without `unique: true` for now, backfill, then add the unique index in a migration of its own
  nothing written: every missing column needs a decision first
```

The first is the general case: a `NOT NULL` column has nothing to hold for the rows that exist. Give the field a `defaultValue`, or make it nullable, fill it, and tighten it in a later migration. The second is SQLite: `ALTER TABLE` cannot add a unique column, so add the column, backfill, and create the unique index by hand. On Postgres the refusal is the same and its message does not name SQLite. `beak doctor` gives the same advice for such a column, instead of pointing at `--from-drift`.

What `--from-drift` does not do, on purpose: it adds columns only. A missing table, a missing `deleted_at` and a database column that no class declares are yours to handle, and `beak doctor` reports each. It also refuses an in-memory SQLite URL (nothing on disk to compare), a URL scheme other than SQLite or Postgres, and a SQLite file that does not exist yet.

Two habits keep it safe. Run it after you have edited the class and before you apply, and treat the file it writes as yours from then on. Run it a second time for the same name and it refuses, because a migration is yours as soon as it is written; `--force` replaces the file, edits included.

## The migrations only you can write

Renames, backfills, drops and constraint changes are decisions, and Beak scaffolds an empty file for them:

```console
$ beak make:migration BackfillPrices
  created lib/migrations/backfill_prices.dart
```

The file has a correctly stamped `name`, an empty `upSchema` with a commented example, and an empty `downSchema` that says what it is for. The shop has two real upgrades worth reading. `add_variant_combinations.dart` adds a nullable key and a scoped unique index to existing variant rows, checks the live schema first, and refuses to roll back:

```dart title="examples/clean_beak_config/lib/migrations/add_variant_combinations.dart"
--8<-- "examples/clean_beak_config/lib/migrations/add_variant_combinations.dart"
```

`expand_shop_catalog.dart` adds category, tax and variant references to a catalog that already had products and orders. It declares each foreign key in the same `alter` as its column, which SQLite turns into an inline `REFERENCES` clause, so no table is rebuilt and no row is replaced.

The `IrreversibleMigrationException` in `downSchema` is a decision too. Removing a column drops business data, and an automatic rollback that does it silently is worse than one that refuses. The cost is that `beak migrate down`, `fresh` and `refresh` stop at that migration on a database that has run it.

## Adopting a database Beak did not create

`beak introspect <url>` reads the tables that exist and writes schema classes for them, plus a baseline. The baseline extends `BeakBaselineMigration` and lists the models, in foreign-key order:

```dart
// Illustrative: what `beak introspect` wrote for a two-table SQLite file.
final class AdoptExistingSchema extends BeakBaselineMigration {
  const AdoptExistingSchema();

  @override
  String get name => '20260929_164131_adopt_existing_schema';

  @override
  List<BeakModel> get models => const [CategoryModel(), ProductModel()];
}
```

Its `upSchema` creates only what is absent. On the database the classes were read from, every table is there and the migration changes nothing but its own record, which is the point: from then on the classes are the source of truth and `beak migrate` moves that database forward like any other. On an empty database (a teammate's laptop, CI) it builds all of it from the models, so the project does not depend on a dump. A table that already exists is never altered.

```console
$ beak migrate
migrated  20260926_000000_beak_commit_receipts
migrated  20260927_000000_beak_outbox
migrated  20260929_164131_adopt_existing_schema
```

The rows survive, and the two `_beak_` tables appear beside them. The baseline cannot be rolled back, because it did not create the tables and has nothing of its own to take back:

```console
$ beak migrate down
error: down() failed: BeakIrreversibleMigrationException: migration 20260929_164131_adopt_existing_schema cannot be rolled back. It adopted tables Beak did not create, and dropping them would destroy data Beak has no business removing.
```

If another tool keeps owning the schema, `beak introspect --ownership external` marks the classes `managesSchema: false` and writes no migration at all. Run `beak migrate` once against that database for Beak's own tables, `_beak_commit_receipts`, `_beak_outbox` and `worm_migrations`: saves fail without the receipts table, and none of your tables is touched. [An existing database](../start-here/paths/existing-database.md) is the walkthrough.

## Test the upgrade, not only the fresh install

A fresh database proves the create migrations. It says nothing about the database you have in production. The shop's migration test does both: it runs only the early migrations, inserts records the way an older release would have, applies the rest, and asserts that the schema changed and the records survived.

```dart title="examples/clean_beak_config/test/shop_migration_test.dart"
final legacy = host.migrations
    .takeWhile(
      (migration) => !migration.name.contains('create_categories_table'),
    )
    .toList();
await MigrationRunner(adapter: adapter, migrations: legacy).migrate();
final oldSchema = await adapter.introspectSchema();
expect(oldSchema['products'], isNot(contains('category_id')));
expect(oldSchema['orders'], isNot(contains('status')));
// ...
final runner = MigrationRunner(
  adapter: adapter,
  migrations: host.migrations,
);
final applied = await runner.migrate();
expect(applied, contains('20260926_235900_expand_shop_catalog'));
// ...
final schema = await adapter.introspectSchema();
expect(
  schema['products'],
  containsAll(['category_id', 'tax_rate_id', 'active']),
);
expect(schema['order_items'], containsAll(['variant_id', 'tax_rate_id']));
```

The trick is `host.migrations.takeWhile(...)`: the host is the real list, so a test cuts it where an old release stopped. The same test then seeds twice and asserts that edits survive, see [Seeding](seeding.md). It runs on `sqlite::memory:`, one database per test, so it never touches `beak.db`.

Repeat the check on Postgres before a release if that is your production database. `packages/beak_backend/test/e2e/postgres_integration_test.dart` shows a suite that runs against a real Postgres and skips itself when none answers.

## Rules and limits

| Rule | Consequence |
| --- | --- |
| Beak never rewrites a migration it has written | A change to a shipped table is a new migration. Editing an applied one changes nothing on databases that ran it |
| Migrations are never applied on boot | Run `beak migrate` as a release step, before traffic moves to code that needs the new columns. Only `sqlite::memory:` migrates itself |
| `--from-drift` adds columns only | Tables, `deleted_at` and extra database columns are yours. It refuses in-memory SQLite and any scheme but SQLite and Postgres |
| Both `make:migration` forms refuse a same-named file | A migration is edited by hand as soon as it is written. `--force` replaces it, edits included |
| `--from-drift` and `beak doctor` read `DATABASE_URL` from the shell first and `.env` second | The order the server uses. See [Databases](databases.md) |
| `beak migrate fresh` and `refresh` run every `downSchema` | An irreversible migration stops them. Both refuse `WORM_ENV=production` without `--force`. `beak migrate` reads `WORM_ENV` from the shell and `.env`, the way the server does; worm's own gate, reached through `dart run bin/migrate.dart`, reads the shell only |
| `down` undoes a batch, not one migration | One `beak migrate` run is one batch. `--steps N` counts batches |
| SQLite: `refresh` cannot roll back a belongs-to column made by a create-table migration | The foreign key is a table-level constraint there. Postgres rolls it back |
| A create migration reads the model as it is now | On a fresh Postgres it could declare a foreign key to a table that a later migration creates, and Postgres rejects that. The generated host orders the migrations to avoid it, see [Order](#order). A hand-written migration that does the same needs `dependsOn` |
| CLI errors print one line `error: <message>` | A bad `DATABASE_URL` or storage variable exits `78`, a failed or irreversible migration exits `1`. A failing migration leaves earlier ones applied |

## Verify it

After every change, the same three commands tell you the state, the SQL and the result:

```console
$ beak migrate status     # nothing pending after a release
$ beak migrate --pretend  # the SQL of what is pending, nothing executed
$ beak doctor             # "the database matches the schema classes"
```

`beak doctor` also compares columns, so a class that gained a field without a migration is a `WARN`, and it is the check to run in CI against a database built from your migrations. Then run the upgrade test above against the schema your last release shipped.

## Reference

- `packages/beak_backend/lib/src/data/worm/beak_blueprint.dart`: `BeakBlueprint.defineColumns`, `defineColumn`, `defineForeignKeys`, `createPivot`, `definePivot`.
- `packages/beak_backend/lib/src/data/worm/beak_baseline_migration.dart`: `BeakBaselineMigration`, `BeakIrreversibleMigrationException`.
- `packages/beak_backend/lib/src/service/beak_commit_receipts_migration.dart` and `packages/beak_backend/lib/src/service/beak_outbox.dart`: Beak's own two migrations.
- `packages/beak_cli/lib/src/schema/beak_migration_emitter.dart` and `packages/beak_cli/lib/src/schema/beak_drift_migration_emitter.dart`: what `prepare` and `--from-drift` write.
- [CLI commands](../reference/cli-commands.md#beak-makemigration) has the flags of `make:migration` and `migrate`.

## Continue reading

- [Seeding](seeding.md) filling the tables the migrations made, in a way that survives a second run.
- [Running the server](running-the-server.md) how the host lists the migrations and why it never applies them.
- [Going to production](../shipping/going-to-production.md) where the migrate step sits in a release.
- [Testing](../shipping/testing.md) more of the in-memory harness the upgrade test uses.
