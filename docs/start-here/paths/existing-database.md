---
title: An existing database
description: Point beak introspect at a Postgres or SQLite database you already have, review the schema classes it writes and choose who migrates from here on.
type: guide
audience: [beginner, expert]
status: stable
---

# An existing database

You have a database with tables and rows, and you want an admin panel over it. After this page you have a Beak project whose schema classes were read from that database, an API that serves them, and a decision recorded about who owns the schema from now on.

`beak introspect` does the reading. It writes the same annotated classes you would have written by hand, so the result is an ordinary Beak project whose first draft came from a database. Edit the classes and they stay yours.

## At a glance

| | |
| --- | --- |
| Command | `beak introspect <database-url>` |
| Databases | Postgres (`postgres://...`, `postgresql://...`) and SQLite (`sqlite:path/to/file.db`) |
| Reads | Tables, columns and types, nullability, foreign keys, unique constraints, column lengths, enum types |
| Writes | One schema class per table into `lib/resources/<table>/models/`, an enum file per database enum, and (adopt only) a baseline migration |
| Two modes | `--ownership adopt` (Beak owns the schema from here) or `--ownership external` (another tool keeps it) |
| Never | Changes your database. It only reads. |

```bash
beak create legacy_admin --no-example --beak-path "$PWD/beak"
cd legacy_admin
beak introspect postgres://legacy:legacy@localhost:5432/legacy_shop --dry-run
beak introspect postgres://legacy:legacy@localhost:5432/legacy_shop --save-url
beak prepare
```

## Choose who owns the schema

Decide this first, because it changes what `introspect` writes and what `beak migrate` is allowed to mean.

| | `adopt` | `external` |
| --- | --- | --- |
| Who changes the tables later | Beak, through migrations you review | Another tool: Django, Rails, Prisma, Flyway, a DBA |
| Schema classes are marked | `managesSchema: true` (the default) | `managesSchema: false` |
| Migration written | A baseline (`AdoptExistingSchema`) listing every model | None |
| On this database | The baseline changes nothing except its own record | Nothing of yours is ever created or altered |
| On an empty database (a laptop, CI) | The baseline builds all the tables from the models | Nothing; the tables are not Beak's to build |
| Rolling it back | Refused: the baseline adopted tables it did not create | Not applicable |

You rarely have to choose by hand. `beak introspect` reads the database first: if it finds another tool's migration table (`schema_migrations`, `_prisma_migrations`, `django_migrations`, `flyway_schema_history`, `alembic_version`, `__EFMigrationsHistory`, `knex_migrations`) it defaults to `external` and says so. Otherwise it defaults to `adopt`. Pass `--ownership adopt|external` to override.

```console
$ beak introspect postgres://legacy:legacy@localhost:5432/legacy_shop --dry-run
  note: this database has django_migrations, so another tool migrates it. Beak reads it as external: the classes are marked `managesSchema: false` and no migration is written. Pass `--ownership adopt` to have Beak take the schema over instead.
  read 3 tables, 15 columns, 1 foreign keys
  would create lib/resources/orders/models/order_status.dart  (OrderStatus over order_status)
  would create lib/resources/customers/models/customer.dart  (Customer over customers)
  would create lib/resources/orders/models/order.dart  (Order over orders)
  would create lib/resources/products/models/product.dart  (Product over products)
  ! products.price is numeric(10,2), read as a double, which can round. An exact amount is a BeakDecimal, which Beak stores as integer units, so switching means converting the column in a migration
  skipped django_migrations (migration bookkeeping)
  external   Beak does not migrate your tables. Run `beak migrate` once for its own
             (`_beak_commit_receipts`, `_beak_outbox`, `worm_migrations`): saves fail without
             them, and it touches none of yours.
```

`--dry-run` writes nothing, so run it first. A Serverpod database is refused (exit `1`, "This database belongs to a Serverpod server"); [An existing Serverpod project](existing-serverpod-project.md) has the path for that.

## Read what it wrote

The three tables became three schema classes and one Dart enum. This is the output for `orders`, unedited:

```dart title="lib/resources/orders/models/order.dart"
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

import '../../customers/models/customer.dart';
import 'order_status.dart';

part 'order.beak.dart';

/// The orders resource, read from the database.
@Resource(managesSchema: false, timestamps: true)
final class Order extends BeakSchema {
  /// Total Cents.
  @Column(sortable: true)
  late final int totalCents;

  /// Status.
  @Column(filterable: true)
  late final OrderStatus? status;

  /// Note.
  @Column(searchable: true)
  late final BeakText? note;

  /// The Customers this belongs to.
  @BelongsTo()
  late final Customer customer;
}
```

The foreign key `customer_id` became a `@BelongsTo()` relationship, `created_at` and `updated_at` became `timestamps: true`, and the text `note` became a `BeakText`. What to review, in this order:

1. **The display column.** Each class gets one `@Display()` field, preferring a column named `name`, then `title`, `label`, `email`, `code` and `subject`. It is what a picker shows for a record. A table with none has no `@Display()`; add one.
2. **Types.** Read every `late final` line. A `numeric(10,2)` price arrives as a `double`, so money can round, and the command notes each such column. An exact `BeakDecimal` with `BeakSemantic.money` ([A money field](../../recipes/a-money-field.md)) is stored as integer units, so an existing `numeric` column has to be converted by a migration of your own before the class can change type.
3. **Nullability.** `?` follows the database's nullability, and a column with a database default is optional too (`status` above is `NOT NULL DEFAULT 'open'`), because the database fills it in. A mismatch between a class and the database fails on save, not at compile time.
4. **Rules.** Column lengths arrive as `BeakMaxLength` rules and an email-shaped column as `BeakEmail()`. Add the rules your business needs; the form and the API both apply them.
5. **What was left out.** A column with `password`, `secret` or `token` as a word in its name (`password_hash`, `card_token`) or an api or private key (`api_key`) is omitted with a warning, and a pure join table becomes a relationship and no class of its own.
6. **Names.** A column the field name does not give back (`firstName`, `address_line_1`, `Email`) keeps its stored name with `@Column(columnName:)`, and a column Dart cannot spell as a field (`class`, `2fa`) gets a field name such as `classValue` under the same option. Beak keys a record by a column called `id`: a table without one is noted, and cannot be read or written until it has one.

## Prepare, migrate, serve

```bash
beak prepare
beak migrate
beak dev
```

What `beak migrate` does depends on the mode you chose.

**Adopt.** The baseline migration is applied and recorded, and the two tables Beak keeps for itself appear next to yours. Your rows survive:

```console
$ beak migrate
migrated  20260926_000000_beak_commit_receipts
migrated  20260927_000000_beak_outbox
migrated  20260929_164522_adopt_existing_schema
```

**External.** No migration of yours exists to run. One thing still needs to happen: every panel save is a graph commit that writes a receipt, and without `_beak_commit_receipts` it answers `500`. On an external database `beak migrate` applies only Beak's two framework migrations, `_beak_commit_receipts` and `_beak_outbox`, plus the `worm_migrations` bookkeeping table. It touches none of your tables. Run it once, and read `beak migrate up --pretend` first if you want to see the SQL.

`beak dev` then serves the API on `:8080`, and the panel is `flutter run -d chrome`, exactly as in the [Quickstart](../quickstart.md). Put `DATABASE_URL` in `.env` (`--save-url` does that for you) or the server opens an empty `beak.db` instead of your database.

## Rules and limits

- **Integer keys work.** A table whose key is a serial integer is written with `late final int? id;`. The server mints a string id only for a string key, leaves an integer one to the database and returns what it assigned, and takes numeric ids on get, update and delete. This is tested on SQLite and on a real Postgres, where the created row's key comes back through `RETURNING`.
- **Native Postgres enums read and write as text.** A query returns the enum label as a string, and a label sent on create, update or in a graph commit is stored in the enum column. Both are tested against a real Postgres.
- **Names are mapped, not translated.** A `total_cents` column becomes `totalCents` in Dart and stays `total_cents` in SQL and in the API. The panel label comes from the field name; set `@Column(label:)` where it reads badly.
- **Schema drift is your call.** `beak doctor` compares the classes to the live database and reports each difference. In adopt mode you close a gap with `beak make:migration Name --from-drift`; in external mode you fix the class or the other tool's migration.
- **`--only` and `--except` take comma-separated table names** (`--only customers,products`), and `--schema` picks a Postgres schema other than `public`. Without them every table is read.
- **Running introspect again never takes your edits back.** A schema file that already holds exactly what would be written is reported as `unchanged`. One you edited stops the run, which names the file and writes nothing; `--force` replaces it, and `--only` or `--except` leaves the table out. A baseline migration that already exists is left alone.

## Verify it

```console
$ beak doctor
  OK   beak.yaml parses
  OK   discovered 3 models · 0 resource classes · 0 screens · 0 overrides
  OK   generated files up to date
  OK   every model has a migration
  OK   database reachable at localhost:5432
  OK   the database matches the schema classes
  ...
All checks passed.
```

Then ask the API for a row:

```console
$ curl -s -X POST localhost:8080/api/customers/query -H 'content-type: application/json' -d '{"table":"customers"}'
{"items":[{"values":{"id":1,"name":"Ada Lovelace","email":"ada@example.com",...},"relations":{}}, ...],"total":2,"page":1,"perPage":25}
```

## Reference

| Flag | Default | Effect |
| --- | --- | --- |
| `<database-url>` | required | `postgres://user:pass@host:port/db`, `postgresql://...` or `sqlite:path`. |
| `--ownership adopt\|external` | `adopt`, or `external` when another tool's migration table exists | Who owns the schema from here. |
| `--out <dir>` | `lib/resources/<table>/models/` per table | Write every class flat into one directory. |
| `--schema <name>` | `public` | Postgres schema to read. |
| `--only <tables>` | all | Only these tables, comma-separated. |
| `--except <tables>` | none | Every table but these, comma-separated. |
| `--save-url` | off | Write `DATABASE_URL=<url>` into `.env`, where the server reads it. |
| `--dry-run` | off | Report what would be written and write nothing. |

Tables Beak never surfaces: the migration tables of other tools (listed above), `migrations`, `worm_migrations`, `ar_internal_metadata` and `knex_migrations_lock`.

## Continue reading

- [Migrations](../../backend/migrations.md): the baseline, drift migrations and the ones only you can write.
- [Databases](../../backend/databases.md): connection settings for Postgres and SQLite.
- [Defining models](../../models/defining-models.md): edit the classes introspection wrote.
- [Quickstart](../quickstart.md): run the panel over the project you just built.
