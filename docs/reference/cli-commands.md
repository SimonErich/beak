---
title: CLI commands
description: Every beak CLI command, its flags, the files it writes, and its exit codes.
---

# CLI commands

`beak` drives a Beak project end to end: it scaffolds one, regenerates its
wiring, serves it, migrates it, and diagnoses it. This page lists every command,
what it writes, and its exit codes.

## Running the CLI

The CLI lives in `packages/beak_cli`; its entry point is `bin/beak.dart`, which
forwards to `createBeakRunner(BeakCliEnvironment.production())`. Invoke it
however your setup exposes it (`dart run beak_cli:beak …`, or a compiled `beak`
on your `PATH`).

## Command summary

| Command | Argument | What it does |
| --- | --- | --- |
| `create` | `<name>` | Scaffolds a new project. |
| `prepare` | (none) | Regenerates the wiring from what the project declares. |
| `dev` | (none) | Regenerates, then serves the API. |
| `introspect` | `<database-url>` | Writes models for the tables a database already has. |
| `eject` | `<target>` | Writes a Beak default out as a file you own. |
| `migrate` | `[subcommand]` | Applies pending migrations. |
| `seed` | (none) | Runs the project seeders. |
| `doctor` | (none) | Diagnoses the project. `--json` for CI. |
| `make:resource` | `Name` | worm model + Beak columns/model + migration. |
| `make:model` | `Name` | worm model only. |
| `make:columns` | `Name` | Beak columns + `BeakModel` only. |
| `make:migration` | `Name` | create-table migration only. |

Every command exits `0` on success, `1` on a failed check or a generation
error, and `64` (`EX_USAGE`) on bad input.

## `beak create <name>`

Scaffolds a project whose visible content is only what you own:

```console
$ beak create acme_admin
  created acme_admin/pubspec.yaml
  created acme_admin/beak.yaml
  created acme_admin/lib/models/note.dart
  created acme_admin/.gitignore
  created acme_admin/analysis_options.yaml
  created acme_admin/AGENTS.md
  1 model · 0 screens · 0 overrides
  generated  7 of 7 files

  cd acme_admin && beak dev
```

`--beak-path <path>` points the generated pubspec at a local Beak checkout
instead of git; use it when developing Beak itself.

`web/` is delegated to `flutter create --platforms=web`, because its contents
(index.html, the manifest, the icon set) change between Flutter releases and a
vendored copy would rot. If that fails, the command warns and still produces a
working project.

## `beak prepare`

Scans `lib/models/`, `lib/screens/`, `lib/migrations/` and `lib/seeders/`, reads
`beak.yaml`, and writes seven files:

| File | Committed? | What it is |
| --- | --- | --- |
| `lib/beak/registry.g.dart` | yes | Every discovered model, and the registry over them. |
| `lib/beak/panel.g.dart` | yes | The panel config: title, resources, screens. |
| `lib/beak/app.g.dart` | yes | The root widget, keeping the `dataSource` test seam. |
| `lib/beak/server.g.dart` | yes | The `BeakServeHost` wiring registry, migrations and seeders. |
| `lib/main.dart` | no | Four lines: `runApp(const BeakApp())`. |
| `bin/serve.dart` | no | One statement: serve the API. |
| `bin/migrate.dart` | no | One statement: run the worm CLI. |

The `lib/beak/*.g.dart` wiring is committed so a fresh clone analyzes before any
`beak` command runs. The three entrypoints are git-ignored: they sit at the
canonical paths so `flutter run`, `flutter build web`, IDE run buttons and
`dart compile exe` all work with no flags, but nothing about them is worth
reviewing. `beak doctor` reports when they are missing or stale.

`prepare` is idempotent — a file whose contents are unchanged is not rewritten —
and every other command runs it first.

!!! note "What discovery can and cannot see"
    Discovery is an unresolved parse, which is what makes it take milliseconds.
    It finds a class extending `BeakModel` directly or one local hop away (the
    shared-base pattern). A model it cannot instantiate is **reported**, not
    skipped: a missing sidebar entry is a bad way to learn about a missing
    `const` constructor.

## `beak dev`

Regenerates, prints the `flutter run` line for the panel, and serves the API.

```console
$ beak dev
  1 model · 0 screens · 0 overrides
  generated  up to date (7 files)
  panel      run this in another terminal:
               flutter run -d chrome
  api        starting…
```

`-d, --device` selects the device in the printed line; `--no-serve` regenerates
only. The panel is deliberately not spawned here — see the command's dartdoc for
why.

## `beak migrate` / `beak seed`

Regenerate, then delegate to the project's generated `bin/migrate.dart`, which
runs the worm CLI over the same host the server uses. `beak migrate` passes a
subcommand through (`status`, `fresh`, `refresh`, …); `beak seed` runs
`db:seed`.

## `beak doctor`

Diagnoses the project it is run in and exits `1` if any check failed. Warnings
do not fail the command:

```console
$ beak doctor
  OK   project depends on Beak
  OK   beak.yaml parses
  OK   discovered 4 models · 1 screen · 2 overrides
  FAIL generated files out of date (1 missing, 0 stale)
       → beak prepare
  WARN database unreachable at localhost:25432
       → start it, or correct DATABASE_URL in .env
  Some checks failed.
```

## The `make:*` commands

The four `make:*` generators write a single file each and register nothing —
with convention-based discovery there is nothing to register. They share the
`--fields` option, and validate `Name` against `^[A-Z][A-Za-z0-9]*$`.

## The `--fields` grammar

`--fields` takes a comma-separated list of `name:kind` pairs. The `name` is the lower_snake_case column name (validated against `^[a-z][a-z0-9_]*$`); the `kind` is one of six tokens. Whitespace around a pair is trimmed and empty pairs are skipped, so a trailing comma is harmless.

```console
$ beak make:resource Order \
    --fields reference:string,total:decimal,placed_at:datetime,paid:bool
```

Each kind maps to a Dart type, a worm blueprint column in the migration, and a `BeakColumn` in the generated columns file:

| Token (aliases) | Dart type | worm blueprint | Beak column |
| --- | --- | --- | --- |
| `string` | `String` | `table.string('x')` | `BeakStringColumn` (searchable, sortable) |
| `text` | `String` | `table.text('x')` | `BeakTextColumn` |
| `int` (`integer`) | `int` | `table.integer('x')` | `BeakIntColumn` (sortable) |
| `decimal` (`double`) | `double` | `table.decimal('x')` | `BeakDecimalColumn` (sortable) |
| `bool` (`boolean`) | `bool` | `table.boolean('x')` | `BeakBoolColumn` (filterable) |
| `datetime` (`date`) | `DateTime` | `table.dateTime('x').makeNullable()` | `BeakDateTimeColumn` (sortable) |

The parser is the source of truth for the accepted tokens:

```dart title="packages/beak_cli/lib/src/field_spec.dart"
static BeakFieldKind? parse(String token) => switch (token) {
  'string' => string,
  'text' => text,
  'int' || 'integer' => integer,
  'decimal' || 'double' => decimal,
  'bool' || 'boolean' => boolean,
  'datetime' || 'date' => dateTime,
  _ => null,
};
```

An unknown kind or a malformed pair throws a `FormatException` whose message names the offending token, which the command surfaces as a usage error (exit `64`). Snake-case field names are rewritten to camelCase Dart identifiers for you: `placed_at` becomes the getter `placedAt`.

!!! note "What just happened"
    One `--fields` list drives three files at once. `total:decimal` becomes a `double total` getter on the worm model, a `table.decimal('total')` column in the migration, and a `BeakDecimalColumn(key: 'total', …)` in the columns file. Define the field once; every layer agrees.

## `make:resource`

The full scaffold. Writes all three files and prints the manual registration steps.

```console
$ beak make:resource Product --fields name:string,price:decimal,active:bool
Scaffolding Product:
  created lib/src/models/product.dart
  created lib/src/models/product_columns.dart
  created lib/src/migrations/create_products_table.dart
Next: register the migration in bin/migrate.dart and the model in your BeakModelRegistry / BeakPanelConfig.
```

| File written | Contents |
| --- | --- |
| `lib/src/models/<snake>.dart` | The canonical worm model: `tableName`, typed getters, `toRow`, `static query()`, and a `$`-suffixed field companion. |
| `lib/src/models/<snake>_columns.dart` | The Beak columns class (a `BeakColumn` per field plus a detail-only `id`) and the `<Name>Model extends BeakModel`. |
| `lib/src/migrations/create_<table>_table.dart` | A `Migration` that creates the table with a UUID key, one column per field, and `timestamps()`. |

`<snake>` is the resource name in lower_snake_case (`OrderItem` becomes `order_item`); `<table>` is the naive plural (`Product` becomes `products`, `Category` becomes `categories`). The migration file name uses that plural, but the generated migration **class** name is `Create<Name>sTable`, so irregular plurals scaffold a slightly-off class name. Rename it when a resource does not pluralize by appending `s`.

The columns file even embeds the snippet to register the model in a panel:

```dart title="generated <snake>_columns.dart"
/// Register it in the panel:
/// ```dart
/// BeakResource(
///   model: ProductModel(),
///   icon: BeakIconToken(OiIcons.box),
/// )
/// ```
```

!!! warning "Registration is manual"
    The generators never touch `bin/migrate.dart`, your `BeakModelRegistry`, or your `BeakPanelConfig`. Migrations are never auto-applied. Wire the new migration and model in yourself, then run migrations. See [Migrations](../backend/migrations.md) and [The model registry](../models/the-registry.md).

## `make:model`

The narrow counterpart. Writes only the worm model.

```console
$ beak make:model Tag --fields name:string
  created lib/src/models/tag.dart
```

Writes `lib/src/models/<snake>.dart` and nothing else. Use it when you already have columns and a migration, or want to hand-write the Beak layer.

## `make:columns`

Writes only the Beak columns class and `BeakModel`, the define-once definition both the server and the Flutter panel consume.

```console
$ beak make:columns Tag --fields name:string
  created lib/src/models/tag_columns.dart
```

Writes `lib/src/models/<snake>_columns.dart`. The first field becomes the model's `displayColumnKey` (or `id` when `--fields` is empty).

## `make:migration`

Writes only the create-table migration, its `name` prefixed with a timestamp.

```console
$ beak make:migration Tag --fields name:string
  created lib/migrations/create_tags_table.dart
```

There is nothing to register: `beak prepare` discovers `lib/migrations/` and lists what it finds on the generated host, ordered by each migration's declared `name` — which is why the timestamp prefix matters. Migrations are still never auto-applied; run `beak migrate`.

### `--from-model`

Derives the columns from the model of the same name instead of restating them:

```console
$ beak make:migration Product --from-model
  created lib/migrations/create_products_table.dart
```

```dart title="lib/migrations/create_products_table.dart"
await schema.create('products', (table) {
  BeakBlueprint.defineColumns(table, const ProductModel());
  BeakBlueprint.defineForeignKeys(table, const ProductModel());
});
```

`BeakBlueprint` reads the same `BeakModel` the API and the panel read, so the table and the resource cannot drift: adding a column to the schema class changes the DDL with no second edit. Nullability, string lengths, enum defaults and the `ON DELETE` of every belongs-to come across with it.

## `beak introspect <database-url>`

Reads an existing Postgres schema and writes the same annotated model classes you would have written by hand.

```console
$ beak introspect postgres://user:pass@localhost:5432/shop
  read 7 tables, 32 columns, 6 foreign keys
  created lib/models/product.dart
  created lib/models/category.dart
  ! users.password_hash looks like a secret and was omitted
  skipped worm_migrations (migration bookkeeping)

  run `beak prepare` to wire them up
```

| Option | Effect |
| --- | --- |
| `--out <dir>` | Where the models go. Defaults to `lib/models`. An absolute path is honoured as given. |
| `--schema <name>` | The Postgres schema to read. Defaults to `public`. |
| `--only a,b` | Only these tables. |
| `--except a,b` | Every table but these. |
| `--dry-run` | Report what would be written without writing it. |

What it infers: types, nullability, string lengths and defaults; a foreign key becomes `@BelongsTo` plus the inverse; a table whose non-id columns are exactly two foreign keys folds into a `@BelongsToMany` rather than becoming a resource; `deleted_at` sets `softDeletes`; a `name`/`title`/`label` column becomes the display column; a name matching `image`/`photo`/`avatar` becomes an upload column; `password`/`token`/`api_key` columns are omitted with a warning. A Postgres enum becomes a Dart enum in its own file — unless a label cannot be a Dart identifier (`in progress`, `class`), in which case the column is read as text and a note says so.

The output is an ordinary Beak project. Edit it and it stays yours.

## `beak eject <target>`

Writes a Beak default out as a file this project owns, pre-filled so it compiles and changes nothing until your first edit.

```console
$ beak eject theme
  created lib/theme.dart

  run `beak prepare` to wire it up
```

| Target | Writes |
| --- | --- |
| `main` | Nothing — it stops `.gitignore` ignoring `lib/main.dart` and `bin/*.dart`. |
| `panel` | `lib/panel.dart` — the last word on the panel config. |
| `theme` | `lib/theme.dart` — the light and dark themes. |
| `auth` | `lib/auth.dart` — which auth routes exist. |
| `dashboard` | `lib/dashboard.dart` — the screen at `/`. |
| `server` | `lib/server.dart` — middleware, extra routes, the policy. |

It refuses to overwrite an existing file; pass `--force` when you mean to.

## `doctor`

Diagnoses the project it is run in and prints one line per check.

```console
$ beak doctor
  OK   project depends on Beak
  OK   beak.yaml parses
  OK   discovered 6 models · 1 screen · 2 overrides
  OK   generated files up to date
  OK   web/ scaffold present
  OK   no panel file imports the server
  WARN no DATABASE_URL in .env
       → add DATABASE_URL to .env before running `beak migrate`
All checks passed.
```

| Check | Status when it fails | Why it matters |
| --- | --- | --- |
| Depends on Beak | FAIL | Nothing else can work. |
| `beak.yaml` parses | FAIL | A bad key stops generation dead. |
| Models discovered | WARN | An empty panel is legal, just probably not intended. |
| Generated files up to date | FAIL | The one failure the hidden-entrypoint design introduces. `beak prepare` fixes it. |
| `web/` scaffold present | WARN | `flutter create --platforms=web .` can fail offline, leaving a project that runs everywhere but the web. |
| No panel file imports the server | FAIL | It compiles, then fails in a browser — or takes the server's ahead-of-time build with it. |
| Database reachable | WARN | Only for a server database. No `DATABASE_URL` is the supported SQLite default and passes. |

Warnings do not fail the command; only a FAIL does. `--json` prints
`{"healthy": bool, "checks": [...]}` instead, so CI can gate on it.

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Success. A `make:*` command wrote its files, or `doctor` passed every check. |
| `1` | `doctor` ran but one or more checks failed. |
| `64` | Usage error (`EX_USAGE`): unknown command, bad option, a non-UpperCamelCase name, or a malformed `--fields` pair. The crafted usage message goes to stderr. |

The `64` mapping lives in the entry point, which catches the `UsageException` the runner throws:

```dart title="packages/beak_cli/bin/beak.dart"
Future<void> main(List<String> args) async {
  final runner = createBeakRunner(BeakCliEnvironment.production());
  try {
    exit(await runner.run(args) ?? 0);
  } on UsageException catch (error) {
    stderr.writeln(error);
    exit(64);
  }
}
```

## Continue reading

- [Defining models](../models/defining-models.md) what the generated columns file grows into by hand.
- [Migrations](../backend/migrations.md) registering and running the migration `make:*` writes.
- [Working with AI agents](../guides/working-with-ai-agents.md) why config-over-code scaffolding suits agent-driven work.
- [Reference index](index.md) the rest of the exhaustive reference.
