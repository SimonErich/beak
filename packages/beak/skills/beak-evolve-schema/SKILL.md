---
name: beak-evolve-schema
description: >-
  Change a table that already shipped in a Beak app: add, rename, retype or
  remove a field or relationship, then write, guard and apply the migration
  that existing databases need. Use when asked to add a column, make a field
  required, rename or drop something, add a relation to an existing @Resource
  schema class, or when beak doctor warns that the database differs from the
  schema classes. Never edits a migration that already ran. Not for a
  brand-new resource (beak-add-resource), a database Beak did not create
  (beak-adopt-database) or a Serverpod-backed panel, where Serverpod owns the
  migrations.
---

# Evolve a shipped schema

The schema class is the truth, but a database only changes through a migration.
`create_<table>_table.dart` reads the model when it runs, so a fresh database
gets your new field from it, and an existing database gets nothing until an
`alter` migration adds it. Both paths must end identical.

Read first, by path: `.dart_tool/beak/docs/backend/migrations.md` and
`.dart_tool/beak/docs/models/defining-models.md`. Search with
`grep -rn "<term>" .dart_tool/beak/docs`.

## Steps

1. Never edit a migration that has run anywhere, `create_<table>_table.dart`
   included. `dart run bin/migrate.dart migrate:status` lists the applied ones.
2. Decide what the existing rows get. A new required column needs
   `@Column(defaultValue: ...)`, or make it nullable and backfill. A unique
   column cannot be added to an existing SQLite table in one step: add it
   without `unique: true`, backfill, and add the unique index in a later
   migration. Removing a field leaves its column in the database until a
   migration drops it, and a leftover `NOT NULL` column breaks inserts.
3. Edit the schema class. A field's column name is its snake-cased name, so
   renaming the Dart field reads as drop plus add. To rename only in Dart, keep
   the column: `@Column(columnName: 'old_name')`.
4. Run `beak prepare`, then `beak doctor`. Its WARN lines are the drift the
   migration has to close ("declared by ... but missing from the database",
   "in the database but ... does not declare it").
5. For added columns run `beak make:migration <Verb><Thing>To<Table> --from-drift`.
   It writes `lib/migrations/<snake>.dart` for every declared column the
   database lacks. Read every `!` line it prints: those columns were refused,
   not written. Fix the schema (default or nullable), delete the unapplied file
   and run it once more. Everything else (renames, retypes, drops, backfills,
   foreign-key constraints) is hand-written: `beak make:migration <Name>` gives
   an empty, correctly named scaffold. Patterns: `references/migration-patterns.md`.
6. Make the migration safe on a fresh database. The generated `alter` adds the
   column unconditionally, and a fresh database already has it from the create
   migration, so it fails with a "duplicate column" error. Wrap every add and
   drop in a check against `schema.adapter.introspectSchema()`.
7. Write `downSchema`, or throw `IrreversibleMigrationException` when rolling
   back would destroy data.
8. Run `beak migrate` (back up a production database first). If it exits
   non-zero without saying why, run `dart run bin/migrate.dart migrate` to read
   the error.
9. Prove both paths. Existing database: `beak doctor` reports "the database
   matches the schema classes". Fresh database: point `DATABASE_URL` at an empty
   one and migrate, for example
   `rm -f fresh.db && DATABASE_URL=sqlite:fresh.db dart run bin/migrate.dart migrate`;
   every migration must apply.
10. Fix what the analyzer now flags. Typed references make a removed or
    retyped field a compile error in resources, filters, screens, seeders and
    tests: repair each one instead of restoring the old field.

## Gate

`beak doctor` has no drift WARN left that you did not intend, `dart format .`,
`flutter analyze` and `flutter test` are clean, and the fresh-database run in
step 9 passed.

## Example prompt

```text
Use the beak-evolve-schema skill: products get a required unique sku (backfill existing rows from their id first) and the legacy_code column goes away.
```
