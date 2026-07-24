---
title: CLI commands
description: Every beak CLI command, its flags, the files it writes, and its exit codes.
---

# CLI commands

`beak` is the scaffolding CLI. It writes convention-following worm models, migrations, and Beak column definitions so you define a resource once and get every layer wired. This page lists every command, the `--fields` grammar they share, the files each one writes, and the exit codes.

## Running the CLI

The CLI lives in `packages/beak_cli`. Its entry point is `bin/beak.dart`, which forwards to `createBeakRunner(BeakCliEnvironment.production())`. From a project root you invoke it however your setup exposes it (`dart run beak_cli:beak …` or a compiled `beak` on your `PATH`), then pass a command and its arguments:

```console
$ beak make:resource Product --fields name:string,price:decimal,active:bool
```

Every generator writes under the current directory and prints one `created` line per file. `beak doctor` writes nothing; it only reports.

## Command summary

| Command | Argument | Writes |
| --- | --- | --- |
| `make:resource` | `Name` (UpperCamelCase) | worm model + Beak columns/model + migration (three files) |
| `make:model` | `Name` | worm model only |
| `make:columns` | `Name` | Beak columns + `BeakModel` only |
| `make:migration` | `Name` | create-table migration only |
| `doctor` | (none) | nothing; prints one `OK`/`FAIL` line per check |

The four `make:*` commands all accept the same `--fields` option. The resource `Name` is validated against `^[A-Z][A-Za-z0-9]*$`: pass exactly one UpperCamelCase word or the command exits with a usage error.

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
Next: register the migration in bin/worm.dart and the model in your BeakModelRegistry / BeakPanelConfig.
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
    The generators never touch `bin/worm.dart`, your `BeakModelRegistry`, or your `BeakPanelConfig`. Migrations are never auto-applied. Wire the new migration and model in yourself, then run migrations. See [Migrations](../backend/migrations.md) and [The model registry](../models/the-registry.md).

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

Writes only the create-table worm migration, its `name` prefixed with a timestamp so worm applies migrations in order.

```console
$ beak make:migration Tag --fields name:string
  created lib/src/migrations/create_tags_table.dart
```

Writes `lib/src/migrations/create_<table>_table.dart`. The timestamp prefix comes from the clock (`20260703_120000_create_tags_table`). Register the class in `bin/worm.dart`; migrations are never auto-applied.

## `doctor`

Checks the local dev setup this repo expects and prints one line per check. It probes Postgres on `:25432` and MinIO on `:29000` with a 2-second TCP connect.

```console
$ beak doctor
  OK   worm vendored
  OK   obers_ui reachable
  FAIL .env present (.env.example to copy)
  OK   postgres :25432
  OK   minio :29000
Some checks failed.
```

| Check | Passes when |
| --- | --- |
| `worm vendored` | `packages/worm` exists under the root. |
| `obers_ui reachable` | `../obers_ui` or `packages/obers_ui` exists. |
| `.env present` | An `.env` file exists at the root (copy `.env.example`). |
| `postgres :25432` | A TCP connect to `localhost:25432` succeeds. |
| `minio :29000` | A TCP connect to `localhost:29000` succeeds. |

The two service ports are the remapped Docker Compose ports Beak uses locally; bring them up with `docker compose up -d`. `doctor` exits `0` only when every check passes and `1` when any fails, so it is safe to gate a script on it.

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
