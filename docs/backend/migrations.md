---
title: Migrations
description: Create schemas from model metadata and evolve existing data with explicit migrations.
type: guide
audience: [beginner, expert]
status: draft
---

# Migrations

Beak uses Worm migrations. A migration extends `Migration`, provides a stable
ordered `name`, and implements `upSchema(Schema)` and `downSchema(Schema)`.
Import these contracts through `package:beak/migrations.dart`.

`beak prepare` discovers migrations in `lib/migrations/` and lists them in the
generated server host. Initial resource migrations use `BeakBlueprint` to translate
shared column metadata into SQL columns, defaults, nullability, indexes and
relationships. The canonical shop's `create_*_table.dart` files show that pattern.

```sh
dart run bin/migrate.dart migrate
```

## Existing databases need additive changes

Generating a new model field does not re-run an already applied migration.
Create an explicit migration for a schema change and inspect existing data before
adding a constraint. Preserve migrations that have already shipped.

The shop has two upgrade examples:

- `expand_shop_catalog.dart` adds category, tax, variant and fulfillment fields to
  the earlier catalog without dropping its products or orders. It handles SQLite's
  inline foreign-key requirements when adding nullable references.
- `add_variant_combinations.dart` adds a nullable canonical combination key and a
  scoped uniqueness index to existing variant tables. Existing catalog records
  remain intact; authoritative saves calculate keys from final attribute rows.

These migrations check the current schema before adding columns. Their downward
migration throws an explicit irreversible-migration exception, because removing
business data requires a deliberate data migration rather than an automatic reset.

## Shared metadata and constraints

`BeakBlueprint.defineColumns` derives scalar defaults and requiredness from the
model. Nullable three-state booleans remain nullable. Exact decimals and money
use scaled integers; calendar dates and wall-clock times have stable physical
representations. Scoped `BeakUnique` rules also declare database indexes, while
preflight validation provides earlier field errors. Database constraints remain
the authority for concurrent writes.

Beak supports all four relationship metadata kinds. Generated pivot migrations use
`BeakBlueprint.createPivot`; a pivot needs foreign keys and a composite uniqueness
constraint so membership cannot be duplicated. Use the relationship's actual
foreign-key names rather than guessing from the class name.

## Validate upgrades

Run migrations against an empty database and against a representative previous
schema. Assert both the resulting schema and preserved records. The shop's
`test/shop_migration_test.dart` covers this with real SQLite, and its API suite
then exercises querying and graph writes against the migrated database.

A fresh/reset command is useful in isolated tests. It is not the normal production
upgrade path. Back up deployment data and run migrations before serving code that
requires the new fields.

## Continue reading

- [Seeding](seeding.md).
- [Running the server](running-the-server.md).
