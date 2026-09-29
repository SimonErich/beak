---
name: beak-adopt-database
description: >-
  Put a Beak admin panel on a database that already exists (Postgres or
  SQLite): introspect its tables into @Resource schema classes, decide whether
  Beak owns the schema from now on (adopt: a baseline migration records the
  tables) or another system keeps migrating it (external: managesSchema
  false), wire it up, and verify there is no drift. Use when the user has a
  legacy or production database, a DATABASE_URL or a .db file, or asks for an
  admin for existing data. Never use it on a Serverpod database (tables named
  serverpod_*); use beak-serverpod-setup there. Not for new tables
  (beak-add-resource).
---

# Adopt an existing database

`beak introspect` reads tables, columns, foreign keys and enum labels and writes
the schema classes you would have written. One decision matters: who migrates
the database afterwards.

| Ownership | Meaning | Writes |
| --- | --- | --- |
| `adopt` (default) | Beak owns the schema from now on. | Schema classes and `lib/migrations/<stamp>_adopt_existing_schema.dart`, a baseline that changes nothing on this database and builds the tables on an empty one. |
| `external` | Rails, Prisma, Django, Flyway, Alembic, Knex or another app keeps migrating. | Schema classes marked `managesSchema: false`, no migration. |

Read first, by path: `.dart_tool/beak/docs/backend/migrations.md`,
`.dart_tool/beak/docs/start-here/paths/existing-database.md` and
`.dart_tool/beak/docs/reference/cli-commands.md`.

## Steps

1. Work on a copy first (`pg_dump` and restore, or copy the `.db` file). Adopting
   changes no table, but `beak migrate` adds Beak's own tables to the database:
   `worm_migrations`, `_beak_commit_receipts` and `_beak_outbox`.
2. Start from a project without the `Note` example that `beak create` writes. If
   it is still there, delete `lib/resources/notes/`,
   `lib/migrations/create_notes_table.dart` and the `resources: notes:` block in
   `beak.yaml`. Otherwise `beak prepare` fails, and `beak migrate` would create a
   `notes` table in this database.
3. Decide ownership. Foreign bookkeeping (`schema_migrations`,
   `_prisma_migrations`, `django_migrations`, `flyway_schema_history`,
   `alembic_version`, `__EFMigrationsHistory`, `knex_migrations`) or the user
   saying another app migrates it means `external`; `beak introspect` then
   defaults to external and says so. Otherwise use `adopt` and state the choice.
4. Run `beak introspect <url> --dry-run`. The URL is
   `postgres://user:pass@host:5432/db` or `sqlite:path/to/file.db`. Relay every
   `!` note to the user: omitted secret columns (`password`, `token`,
   `api_key`, ...), unsupported types, enum labels. Narrow with `--only a,b` or
   `--except a,b`; `--schema` picks a Postgres schema.
5. Run it for real: `beak introspect <url> --ownership adopt --save-url` (or
   `external`). `--save-url` writes `DATABASE_URL=<url>` into `.env`, which must
   stay git-ignored because the URL can hold a password. A table with only a key
   pair becomes a many-to-many, not a resource.
6. Review each generated schema class. Introspection marks `@Display()` on the
   best-named text column (`name`, then `title`, `label`, `email`, `code`,
   `subject`), as a `String` or a `BeakText` (SQLite declares nearly every
   string as `TEXT`, which comes out as `BeakText`). Where none is marked, pickers and
   titles show ids: add `@Display()` to the field that names a record. Change
   short names from `BeakText` to `String` (with
   `@Column(rules: [BeakMaxLength(n)])`) where a single line is right.
7. Run `beak prepare` and fix every issue it lists.
8. Adopt: `beak migrate` records the baseline and creates nothing that
   exists. Confirm with `beak migrate status` (the baseline is `applied`).
   External: run `beak migrate` once, for Beak's own tables only
   (`_beak_commit_receipts`, `_beak_outbox`, `worm_migrations`); it touches none
   of yours, and saves fail without the receipts table. Never run
   `migrate:fresh` or `migrate:refresh` against either kind of database, and
   never run `beak migrate` against production without a backup.
9. Run `beak doctor` and read its drift lines. Expect one "in the database but
   ... does not declare it" WARN per omitted secret column; anything else is a
   real difference to fix in the schema class or, for adopt, with
   `beak-evolve-schema`.
10. Give each table the panel needs a resource: `beak eject resource <table>`
    writes a `BeakResource` class for the model, then follow `beak-add-resource`
    steps 6 and 7 to add its table, filters and form. Leave the folder layout
    `introspect` chose (`lib/resources/<table>/models/`) unless asked; when you
    move a schema file, move its `.beak.dart` part with it and fix the imports
    in the baseline migration and in `lib/`.
11. Start it: `beak dev` serves the API against `DATABASE_URL`; run the panel
    with `flutter run -d chrome` in a second terminal.

## Gate

`beak doctor` reports no failure and no unexplained drift, `dart format .`,
`flutter analyze` and `flutter test` are clean. For adopt, a fresh empty
database migrates completely
(`DATABASE_URL=sqlite:fresh.db beak migrate`).

## Example prompt

```text
Use the beak-adopt-database skill on postgres://me@localhost:5432/shop with Beak owning the schema from now on. Show me every column it skipped and why before wiring resources.
```
