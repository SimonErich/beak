# CLI commands

> Look up every beak command, its flags, the files it writes and its exit codes.

`beak` drives a project end to end: it scaffolds one, regenerates its wiring,
serves it, migrates it, and diagnoses it. This page lists every command, what
it writes, and its exit codes.

## Running the CLI

The CLI lives in `packages/beak_cli`; its entry point is `bin/beak.dart`, which
forwards to `createBeakRunner(BeakCliEnvironment.production())`. Install it with
`dart pub global activate` (see [Installation](../start-here/installation.md))
or invoke it as `dart run beak_cli:beak …`.

## Command summary

| Command | Argument | What it does |
| --- | --- | --- |
| `create` | `<name>` | Scaffolds a new project. |
| `prepare` | (none) | Regenerates the wiring from what the project declares. |
| `dev` | (none) | Regenerates, then serves the API. |
| `introspect` | `<database-url>` | Writes schema classes for the tables a database already has. |
| `eject` | `<target> [table]` | Writes a Beak default out as a file you own. |
| `migrate` | `[subcommand]` | Applies pending migrations. |
| `seed` | (none) | Runs the project seeders. |
| `make:resource` | `Name` | One `@Resource` schema class, then `prepare`. |
| `make:migration` | `Name` | An empty, correctly-named migration. `--from-drift` fills it in. |
| `doctor` | (none) | Diagnoses the project. `--json` for CI. |

Every command exits `0` on success, `1` on a failed check or a generation
error, and `64` (`EX_USAGE`) on bad input.

> **Note: Two commands that no longer exist**
>
> `make:model` and `make:columns` are gone, and so is `make:migration
> --from-model`. A resource is one annotated class now; `beak prepare` derives
> the columns, the model, both sides of every relationship and the migration
> from it. There is nothing left for a second generator to write.

## `beak create <name>`

Scaffolds a project whose visible content is only what you own. The name must
be a valid Dart package name (`^[a-z][a-z0-9_]*$`).

```console
$ beak create acme_admin
  created acme_admin/pubspec.yaml
  created acme_admin/beak.yaml
  created acme_admin/lib/models/note.dart
  created acme_admin/.gitignore
  created acme_admin/analysis_options.yaml
  created acme_admin/AGENTS.md
  created acme_admin/test/widget_test.dart
  created acme_admin/README.md
  1 model · 0 screens · 0 overrides
  generated  9 of 9 files

  cd acme_admin && beak dev
```

Six files are the scaffold, two more replace what `flutter create` leaves
behind, and the rest is generation: `create` finishes by running `prepare`
inside the new project, so it is runnable as created rather than one command
short of it.

`--beak-path <path>` points the generated pubspec at a local Beak checkout
instead of git; use it when developing Beak itself.

`web/` is delegated to `flutter create --platforms=web --no-pub`, because its
contents (index.html, the manifest, the icon set) change between Flutter
releases and a vendored copy would rot. If that fails, the command warns and
still produces a working project.

The one dependency in the generated pubspec is `beak`. See
[Libraries](libraries.md) for the eight libraries it exposes.

## `beak prepare`

Scans `lib/models/`, `lib/screens/`, `lib/migrations/`, `lib/seeders/` and
`lib/resources/`, reads `beak.yaml`, and writes three kinds of file.

**One part file per schema class**, beside the class that declares it:

| File | Committed? | What it is |
| --- | --- | --- |
| `lib/models/<name>.beak.dart` | yes | `<Name>Columns`, `<Name>Relations` (both sides), `<Name>Model`, and a typed `<Name>Record` view. |

**The wiring**, seven files:

| File | Committed? | What it is |
| --- | --- | --- |
| `lib/beak/registry.g.dart` | yes | `beakModels` and `buildBeakRegistry()`. |
| `lib/beak/panel.g.dart` | yes | The panel config: title, resources, screens. |
| `lib/beak/app.g.dart` | yes | The root widget, keeping the `dataSource` test seam. |
| `lib/beak/server.g.dart` | yes | The `BeakServeHost` wiring registry, migrations and seeders. |
| `lib/main.dart` | no | Four lines: `runApp(const BeakApp())`. |
| `bin/serve.dart` | no | One statement: serve the API. |
| `bin/migrate.dart` | no | One statement: run the worm CLI. |

**The migration a new resource needs**, written once into
`lib/migrations/create_<table>_table.dart` and never rewritten. It is yours from
the moment it exists: Beak derives its *contents* from the model
(`BeakBlueprint.defineColumns`), never the decision to apply it. Change a
shipped table with `schema.alter` in a migration of your own, from
`beak make:migration`.

The generated Dart is committed so a fresh clone analyzes before any `beak`
command runs. The three entrypoints are git-ignored: they sit at the canonical
paths so `flutter run`, `flutter build web`, IDE run buttons and
`dart compile exe` all work with no flags, but nothing about them is worth
reviewing. `beak doctor` reports when they are missing or stale.

`prepare` is idempotent (a file whose contents are unchanged is not rewritten)
and every other command runs it first.

```console
$ beak prepare
  7 models · 1 screen · 2 overrides
  generated  up to date (7 files)
```

> **Note: What discovery can and cannot see**
>
> Discovery is an unresolved parse, which is what makes it take milliseconds.
> It finds a class extending `BeakSchema` with `@Resource`, or a hand-written
> `BeakModel` one local hop away. A model it cannot instantiate is
> **reported**, not skipped: a missing sidebar entry is a bad way to learn
> about a missing `const` constructor. A `beak.yaml` key naming no discovered
> table is reported too, with a did-you-mean.

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

`-d, --device` selects the device in the printed line (default `chrome`);
`--no-serve` regenerates and prints, without starting the API. The panel is
deliberately not spawned here: proxying `flutter run`'s interactive console is
the fiddliest part of a dev server and the least testable.

## `beak migrate` / `beak seed`

Regenerate, then delegate to the project's generated `bin/migrate.dart`, which
runs the worm CLI over the same host the server uses, so the schema and the API
can never come from different registries.

```console
$ beak migrate            # apply pending migrations
$ beak migrate status     # what has run, what has not
$ beak migrate fresh      # drop everything and re-run
$ beak seed               # run the project seeders (db:seed)
```

`beak migrate` passes its argument straight through (`status`, `up`, `down`,
`fresh`, `refresh`, …) and defaults to `migrate`. Migrations are never applied
on boot; running them stays a decision you make.

## `beak make:resource Name --fields ...`

Writes one file: the `@Resource` schema class at `lib/models/<snake>.dart`. Then
it runs `prepare`, which derives everything else.

```console
$ beak make:resource Product --fields name:string!,price:decimal!,in_stock:bool
  created lib/models/product.dart
  2 models · 0 screens · 0 overrides
  generated  5 of 9 files
```

The generated class is ordinary Dart you now edit:

```dart
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'product.beak.dart';

/// A product.
@Resource(timestamps: true)
final class Product extends BeakSchema {
  /// Name.
  @Display()
  @Column(searchable: true)
  late final String name;

  /// Price.
  @Column(sortable: true)
  late final double price;

  /// In stock.
  @Column(filterable: true)
  late final bool? inStock;
}
```

`Name` is validated against `^[A-Z][A-Za-z0-9]*$`. The first string field gets
`@Display()`, which is right far more often than not; move it when it is not.
The `@Column` options are chosen from the kind (text is worth searching, numbers
and instants are worth sorting, a boolean is worth filtering), each one word to
delete.

### The `--fields` grammar

`--fields` takes a comma-separated list of `name:kind` pairs, optionally with a
trailing `!`. The `name` is the lower_snake_case column name (validated against
`^[a-z][a-z0-9_]*$`) and is rewritten to a camelCase Dart identifier:
`placed_at` becomes `placedAt`. Whitespace around a pair is trimmed and empty
pairs are skipped, so a trailing comma is harmless.

```console
$ beak make:resource Order \
    --fields reference:string!,total:decimal!,placed_at:datetime,paid:bool
```

A trailing `!` means **required**, and it lands in the schema class as Dart's
own non-nullable type. That one mark drives the form validator, the API's
validation and the column's `NOT NULL`.

| Token (aliases) | Field is written as | Column it becomes |
| --- | --- | --- |
| `string` | `String` | `BeakStringColumn` (searchable) |
| `text` | `BeakText` | `BeakTextColumn` (searchable) |
| `int` (`integer`) | `int` | `BeakIntColumn` (sortable) |
| `decimal` (`double`) | `double` | `BeakDecimalColumn` (sortable) |
| `bool` (`boolean`) | `bool` | `BeakBoolColumn` (filterable) |
| `datetime` (`date`) | `DateTime` | `BeakDateTimeColumn` (sortable) |

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

An unknown kind or a malformed pair throws a `FormatException` whose message
names the offending token, which the command surfaces as a usage error
(exit `64`). `--fields` covers the six kinds worth typing at a prompt; the rest
of the [authoring types](annotations.md#authoring-types) (`BeakRichText`,
`BeakJson`, `BeakHexColor`, `BeakImageRef`, `BeakFileRef`, any enum) and every
relationship you add by editing the class.

> **Note: What just happened**
>
> `--fields` is written once and has nowhere to drift. `total:decimal!`
> becomes a `late final double total` field, which `beak prepare` turns into
> `OrderColumns.total`, a `BeakDecimalColumn` with `BeakRequired()`, a
> `table.decimal('total')` in the migration, a `double get total` on the
> typed record view, and a required form field. One declaration, six
> consumers.

## `beak make:migration Name`

Writes an empty, correctly-named migration at `lib/migrations/<snake>.dart`.

```console
$ beak make:migration AddStatusToProducts
  created lib/migrations/add_status_to_products.dart
```

`prepare` writes the create-table migration for any model whose table nothing
creates, so this is for everything else: adding a column to a shipped table,
backfilling data, dropping something. The scaffold gives the timestamped name
(`20260727_143012_add_status_to_products`) and leaves the body to you:

```dart
@override
Future<void> upSchema(Schema schema) async {
  // e.g. await schema.alter('products', (table) {
  //   table.string('status', length: 20).makeNullable();
  // });
}
```

The timestamp matters: `beak prepare` lists discovered migrations on the
generated host ordered by their declared `name`, and worm runs them in that
order. There is nothing to register, and nothing is ever applied automatically.

### `--from-drift`

Adding a field to a resource that is already live is the common case, and it
is the one the scaffold above leaves most work for. `--from-drift` reads the
database, compares it against the schema classes, and writes the body:

```console
$ beak make:migration AddStockToProducts --from-drift
  created lib/migrations/add_stock_to_products.dart
  run `beak migrate` to apply it
```

```dart
@override
Future<void> upSchema(Schema schema) async {
  await schema.alter('products', (table) {
    BeakBlueprint.defineColumn(table, ProductColumns.stock);
  });
}
```

It reads the database rather than the migrations because a Beak migration
never names its columns: a generated one calls
`BeakBlueprint.defineColumns(table, const ProductModel())`, so the DDL follows
the model and the two cannot drift on a fresh database. The generated `alter`
adds the column through the same mapping, so a column added here and a column
created there cannot become different columns.

It writes only the columns a **field** declares and a live table can gain. A
missing table means the resource was never migrated, which `beak prepare`
already writes a create migration for; a missing `deleted_at` means
`softDeletes` was turned on, which changes more than the table; and a column
the database has and no schema declares is a decision rather than a defect.
`beak doctor` reports all of those, and leaves them to you.

A required column with nothing to fill the existing rows, or a `unique: true`
column, is refused with a `!` line naming the edit that would let it through:

```console
$ beak make:migration AddFields --from-drift
  ! products.stock: a required column needs a value for the rows already there, and only an enum can declare one; make it nullable and backfill
  created lib/migrations/add_fields.dart
  run `beak migrate` to apply it
```

When *every* missing column needs a decision, nothing is written and the
command exits `1`, so a CI job cannot mistake "drift no migration can express"
for "the schema is applied". It also refuses to run before the first
`beak migrate` (opening a SQLite file creates it, so looking would leave an
empty database behind) and against an in-memory database, which belongs to
the serving process.

## `beak eject <target>`

Writes a Beak default out as a file this project owns, pre-filled so it compiles
and changes nothing until your first edit.

```console
$ beak eject theme
  created lib/theme.dart

  run `beak prepare` to wire it up
```

| Target | Writes |
| --- | --- |
| `main` | Nothing new: it stops `.gitignore` ignoring `lib/main.dart`, `bin/serve.dart` and `bin/migrate.dart`. |
| `panel` | `lib/panel.dart`, holding `BeakPanelConfig beakPanel(BeakPanelConfig defaults)`: the last word on the panel. |
| `resource` | `lib/resources/<table>.dart`, holding `BeakResource beakResource(BeakResource generated)`: one resource only. Takes a table name. |
| `theme` | `lib/theme.dart`, holding `beakLightTheme()` and `beakDarkTheme()`. |
| `auth` | `lib/auth.dart`, holding `BeakAuthConfig beakAuth()`. |
| `dashboard` | `lib/dashboard.dart`, holding the `BeakScreen` mounted at `/`. |
| `server` | `lib/server.dart`, holding `BeakServer beakServer(BeakServerDefaults defaults)`: middleware, extra routes, the policy. |

`resource` is the only target that takes an argument, and it is required:

```console
$ beak eject resource orders
  created lib/resources/orders.dart

  run `beak prepare` to wire it up
```

What it writes returns the generated resource unchanged, so the file compiles
and changes nothing until you `copyWith` something:

```dart
BeakResource beakResource(BeakResource generated) => generated;
```

Every other resource in the panel stays generated. Ejecting refuses to overwrite
an existing file (exit `1`); pass `--force` when you mean to.

## `beak introspect <database-url>`

Reads an existing schema and writes the same annotated schema classes you would
have written by hand. Postgres and SQLite are supported; any other scheme exits
`1` saying so.

```console
$ beak introspect sqlite:legacy.db
```

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
| `--out <dir>` | Where the schema classes go. Defaults to `lib/models`. An absolute path is honoured as given. |
| `--schema <name>` | The Postgres schema to read. Defaults to `public`, and is ignored for SQLite, which has one. |
| `--only a,b` | Only these tables. |
| `--except a,b` | Every table but these. |
| `--dry-run` | Report what would be written without writing it. |

What it infers: types, nullability, string lengths and defaults; a foreign key
becomes `@BelongsTo` plus the inverse; a table whose non-id columns are exactly
two foreign keys folds into a `@BelongsToMany` rather than becoming a resource;
`deleted_at` sets `softDeletes`; a `name`/`title`/`label` column becomes the
display column; a name matching `image`/`photo`/`avatar` becomes an upload
column; `password`/`token`/`api_key` columns are omitted with a warning. A
Postgres enum becomes a Dart enum in its own file, unless a label cannot be a
Dart identifier (`in progress`, `class`), in which case the column is read as
text and a note says so.

The output is an ordinary Beak project. Edit it and it stays yours.

## `beak doctor`

Diagnoses the project it is run in and prints one line per check.

```console
$ beak doctor
  OK   project depends on Beak
  OK   beak.yaml parses
  OK   discovered 7 models · 1 screen · 2 overrides
  OK   generated files up to date
  OK   every model has a migration
  OK   web/ scaffold present
  OK   no panel file imports the server
  OK   database is SQLite (beak.db)
  OK   the database matches the schema classes
All checks passed.
```

| Check | Status when it fails | Why it matters |
| --- | --- | --- |
| `pubspec.yaml` exists | FAIL | Not a Dart project; nothing else is worth checking. |
| Depends on Beak | FAIL | Nothing else can work. |
| `beak.yaml` parses | FAIL | A bad key stops generation dead, and the rest of the report would be guesswork. |
| Models discovered | WARN | An empty panel is legal, just probably not intended. |
| Generated files up to date | FAIL | The one failure mode the hidden-entrypoint design introduces. `beak prepare` fixes it. |
| Every model has a migration | FAIL | A model with no table is a resource whose every endpoint fails at request time. `beak prepare` writes the missing one. |
| `web/` scaffold present | WARN | `flutter create --platforms=web .` can fail offline, leaving a project that runs everywhere but the web. |
| No panel file imports the server | FAIL | `package:beak/server.dart` reaches `dart:io`: it compiles, then fails in a browser. |
| Database reachable | WARN | Only for a server database. No `DATABASE_URL` is the supported SQLite default and passes as OK, as does a `sqlite:`/`file:` URL. |
| Database matches the schema classes | WARN | Drift: the schema class is what the panel, the API and the next generated migration all read, so a database that no longer matches it is wrong in three places at once. `beak make:migration --from-drift` writes the fix. |

Warnings do not fail the command; only a FAIL does. `--json` prints
`{"healthy": bool, "checks": [...]}` instead, so CI can gate on it.

### Drift

The last check reads the database's real schema and compares it against the
schema classes. It works on SQLite, including the zero-setup default file, and
on a reachable Postgres. A file that does not exist yet reports "not created
yet, run `beak migrate`", and `sqlite::memory:` is named as in-memory and left
alone: it belongs to the serving process, so there is nothing on disk to
compare. It reports both directions, one warning per
difference:

```console
$ beak doctor
  OK   database reachable at localhost:5432
  WARN products.reserved is declared by Product.reserved but missing from the database
       → write a migration with `beak make:migration`, then `migrate`
  WARN products.legacy_sku is in the database but Product does not declare it
       → write a migration with `beak make:migration`, then `migrate`
```

It also checks the columns a schema *implies* rather than declares: a
belongs-to's foreign key, `deleted_at` under `softDeletes`, the two stamps
under `timestamps`, and the pivot table behind every `@BelongsToMany`.

Two deliberate quiets. A `@Resource(managesSchema: false)` table may carry any
number of columns Beak knows nothing about, because another system owns it;
only the columns the schema *declares* are checked there. And drift is a
warning, never a failure. The fix is a migration someone has to write and
review, so blocking on it would make `doctor` unrunnable against an
environment mid-deploy.

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Success: generation completed, or `doctor` passed every check. |
| `1` | A check failed, generation reported issues, `eject` refused to overwrite a file, or `--from-drift` found only drift that needs a decision. |
| `64` | Usage error (`EX_USAGE`): unknown command, bad option, a non-UpperCamelCase name, or a malformed `--fields` pair. The crafted usage message goes to stderr. |

The `64` mapping lives in the entry point, which catches the `UsageException`
the runner throws:

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

- [Annotations](annotations.md) what the schema class `make:resource` writes can say.
- [beak.yaml](beak-yaml.md) the file `prepare` reads for presentation.
- [Project structure](../start-here/project-structure.md) which folder every command scans.
- [Migrations](../backend/migrations.md) what `prepare` writes once and `migrate` applies.
- [Reference index](index.md) the rest of the exhaustive reference.
