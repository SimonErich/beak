---
title: Quickstart scaffold
description: Tour the project that beak create writes, file by file, and see which files you author, which Beak generates and which Beak writes once.
type: example
audience: [beginner]
status: stable
---

# Quickstart scaffold

`beak create` writes a small project and `beak prepare` fills in the wiring. This page walks that project in `examples/quickstart` so you know which files are yours, which Beak rewrites on every run and which it writes once and then leaves alone.

The committed example is the scaffold with nothing added. It matches what `beak create quickstart` plus `beak prepare` write today, file for file, except the dependency line in `pubspec.yaml` and the timestamp in the migration's name.

## At a glance

| | |
| --- | --- |
| Domain | A notepad |
| Models | 1: `Note` (`title`, `body`, `pinned`, and timestamps) |
| Resource classes | None. Beak builds the default resource for `Note` from `beak.yaml` |
| Panel bootstrap | Generated: `lib/main.dart` runs `BeakApp` from `lib/beak/app.g.dart` |
| API port | 8080 |
| Auth | None |
| Database | SQLite file `beak.db` beside the README. Set `DATABASE_URL` for Postgres |
| Tests | 1 widget test |
| Read it if | You have never seen a Beak project |

## Run it

From a checkout of the Beak repository:

```console
cd examples/quickstart
flutter pub get
beak migrate
beak dev
```

`beak migrate` applies three migrations. Two are the framework's own tables (save receipts and the outbox), the third is yours:

```console
$ beak migrate
  1 model · 0 resource classes · 0 screens · 0 overrides
  generated  up to date (8 files)
migrated  20260926_000000_beak_commit_receipts
migrated  20260927_000000_beak_outbox
migrated  20260727_160744_create_notes_table
```

`beak dev` regenerates the wiring, prints the line that starts the panel, and serves the API:

```console
$ beak dev
  1 model · 0 resource classes · 0 screens · 0 overrides
  generated  up to date (8 files)
  panel      run this in another terminal:
               flutter run -d chrome
  api        starting…
listening on http://0.0.0.0:8080
```

Run that `flutter run` line in a second terminal and the panel opens in Chrome, with a Notes entry under Content. Nothing here starts the panel for you, on purpose: `beak dev` owns the API, Flutter owns the window.

You can also talk to the API directly. There is one route per operation, and a list is a `POST` to `/query` because the filter travels as a body:

```console
$ curl -s -X POST localhost:8080/api/notes -H 'content-type: application/json' \
    -d '{"title":"First note","pinned":true}'
{"values":{"id":"421eced2-4302-4b17-b783-8668fd29736b","title":"First note","body":null,"pinned":true,"created_at":{"type":"dateTime","value":"2026-09-29T10:20:50.038Z"},"updated_at":{"type":"dateTime","value":"2026-09-29T10:20:50.038Z"}},"relations":{}}

$ curl -s -X POST localhost:8080/api/notes -H 'content-type: application/json' -d '{"body":"no title"}'
{"code":"validation","message":"Validation failed for \"notes\".","fieldErrors":{"title":["This field is required."],"pinned":["This field is required."]},"requestId":"1baff821933dd8be"}
```

The second call is the one to read twice. Nobody wrote a required rule for `title` or `pinned`. The field types did: `String title` and `bool pinned` are not nullable, so they are required, in the form, in the API and in the table. `BeakText? body` has a question mark, so it is optional.

!!! note "What just happened"
    - `beak migrate` created the SQLite file and three tables.
    - `beak dev` served a generated REST API for `Note` and nothing else. No route was written by hand.
    - The API is open. Anyone who can reach the port can read and write notes. Keep it on your machine until you add [auth and policies](../backend/auth-and-policies.md).

!!! question "What this skipped"
    Starting a project of your own instead of reading this one: [Quickstart](../start-here/quickstart.md) runs `beak create`, and `beak create --help` lists the flags (`--authored`, `--no-example`, `--no-pub`, `--beak-ref`, `--beak-path`).

## Tour

### The one file you write

```dart title="examples/quickstart/lib/resources/notes/models/note.dart"
--8<-- "examples/quickstart/lib/resources/notes/models/note.dart"
```

Three fields, three lines of meaning each. `@Resource(timestamps: true)` adds `created_at` and `updated_at`, which is why they showed up in the JSON above. `@Display()` says a `Note` is called by its title when another screen has to name one. `@Column(searchable: true, sortable: true, rules: [BeakMaxLength(255)])` feeds the search box, the sort arrow, the form validator and the API validator from a single line. Every schema class is described in [Defining models](../models/defining-models.md).

### What Beak generates from it

`beak prepare` reads the schema class and writes `note.beak.dart` next to it. That file holds the typed handles the rest of your code uses instead of strings: `NoteModel.title`, `NoteModel.pinned`, `NoteColumns.body`. You never open it and never edit it. [Generated code](../models/generated-code.md) lists what it contains.

The same run writes the wiring under `lib/beak/`:

| File | What it wires |
| --- | --- |
| `registry.g.dart` | Every discovered model, as `beakModels` and `buildBeakRegistry()` |
| `panel.g.dart` | The panel's configuration, built from `beak.yaml` and your resource classes |
| `app.g.dart` | `BeakApp`, the widget that mounts the panel |
| `server.g.dart` | `beakHost()`, the configured backend: migrations, seeders, storage, database |

### The migration

Beak writes the first migration for you, once. After that it is yours and Beak never rewrites it:

```dart title="examples/quickstart/lib/migrations/create_notes_table.dart"
--8<-- "examples/quickstart/lib/migrations/create_notes_table.dart"
```

The table is read from `NoteModel`, so adding a field to the schema class changes the DDL for any database that has not run this migration yet. A database that already ran it needs a new migration: `beak make:migration <Name> --from-drift` writes one from the difference. [Migrations](../backend/migrations.md) has the workflow.

### The configuration file

```yaml title="examples/quickstart/beak.yaml"
--8<-- "examples/quickstart/beak.yaml"
```

Every key is optional. The `resources.notes` entry gives the default resource an icon and a sidebar group, and it ends up in `panel.g.dart` as a `BeakResource`:

```dart title="examples/quickstart/lib/beak/panel.g.dart"
--8<-- "examples/quickstart/lib/beak/panel.g.dart"
```

`section: Content` became `navigationGroup: 'Content'`. When you need more than an icon and a group, you write a `BeakResource` subclass and Beak uses yours in place of the default. [Resources](../panel/resources.md) shows how.

### The entrypoints

`lib/main.dart` is two lines, and the scaffold's `.gitignore` lists it because Beak rewrites it on every `beak prepare`. This repository keeps the file in git so the example compiles from a clean checkout.

```dart title="examples/quickstart/lib/main.dart"
--8<-- "examples/quickstart/lib/main.dart"
```

`bin/serve.dart` and `bin/migrate.dart` are the same kind of file, generated for the server side. `beak dev` and `beak migrate` run them. You can also run them yourself:

```console
dart run bin/serve.dart
dart run bin/migrate.dart migrate
```

To own the panel instead of letting Beak generate it, run `beak eject main`. It rewrites `lib/main.dart` as a `BeakPanel(resources: [...])` you commit, and `beak prepare` leaves it alone from then on. `beak create --authored` starts that way. [Two ways to boot a panel](../start-here/generated-or-authored.md) compares both.

### The test

```dart title="examples/quickstart/test/widget_test.dart"
--8<-- "examples/quickstart/test/widget_test.dart"
```

It pumps the whole panel against `InMemoryBeakDataSource`, so no server and no database are involved. The loop at the end fails when a model exists but is not registered, which is the mistake you make right after adding a schema class and forgetting `beak prepare`.

### The agent file

`AGENTS.md` and `CLAUDE.md` are for the coding agent in your editor. Beak only edits the block between the `BEGIN:beak-agent-rules` and `END:beak-agent-rules` comments, and `beak prepare` keeps it in step with your Beak version. Everything under `## This project` is yours. `beak agents` installs the workflow skills and `beak docs` copies the docs of your Beak version to `.dart_tool/beak/docs`. [Set up your agent](../ai/setup.md) covers both.

## Where things are

| Path | What it is | Who edits it |
| --- | --- | --- |
| `lib/resources/notes/models/note.dart` | The schema class | You |
| `lib/resources/notes/models/note.beak.dart` | Typed columns, model, record view | Beak, every `beak prepare` |
| `lib/migrations/create_notes_table.dart` | The first migration | Beak once, then you |
| `beak.yaml` | Panel title, API origin, per-resource icon and group | You |
| `lib/beak/*.g.dart` | Registry, panel config, app widget, server host | Beak, every `beak prepare` |
| `lib/main.dart` | Panel entrypoint | Beak, until you run `beak eject main` |
| `bin/serve.dart`, `bin/migrate.dart` | Server entrypoints | Beak, every `beak prepare` |
| `test/widget_test.dart` | Boot test | You |
| `AGENTS.md`, `CLAUDE.md` | Agent rules | Beak in the marked block, you elsewhere |
| `beak.db` | SQLite database, created by `beak migrate` | Git-ignored |

## Features shown

| Feature | File | Docs page |
| --- | --- | --- |
| One schema class as the only definition | `lib/resources/notes/models/note.dart` | [Defining models](../models/defining-models.md) |
| Required and optional from the Dart type | `lib/resources/notes/models/note.dart` | [Fields](../models/fields.md) |
| Column options: search, sort, filter, rules, visibility | `lib/resources/notes/models/note.dart` | [Fields](../models/fields.md) |
| Typed handles instead of strings | `lib/resources/notes/models/note.beak.dart` | [Generated code](../models/generated-code.md) |
| A default resource configured in `beak.yaml` | `lib/beak/panel.g.dart` | [Resources](../panel/resources.md) |
| A migration derived from the model | `lib/migrations/create_notes_table.dart` | [Migrations](../backend/migrations.md) |
| A generated API host | `lib/beak/server.g.dart`, `bin/serve.dart` | [Running the server](../backend/running-the-server.md) |
| The generated panel bootstrap | `lib/main.dart`, `lib/beak/app.g.dart` | [Two ways to boot a panel](../start-here/generated-or-authored.md) |
| A widget test on an in-memory data source | `test/widget_test.dart` | [Testing](../shipping/testing.md) |
| Agent instructions for your Beak version | `AGENTS.md` | [Set up your agent](../ai/setup.md) |

## Tests

```console
cd examples/quickstart
flutter test
```

One test: `the panel boots with every declared model registered`. The gate for the whole repository also runs `beak doctor` in every example, which fails when generated files are stale or a model has no migration:

```console
$ beak doctor
  OK   project depends on Beak
  OK   beak.yaml parses
  OK   discovered 1 model · 0 resource classes · 0 screens · 0 overrides
  OK   generated files up to date
  OK   every model has a migration
  OK   web/ scaffold present
  OK   no panel file imports the server
  OK   AGENTS.md has the Beak 0.9.0 block
  OK   CLAUDE.md reads AGENTS.md
  OK   docs bundle for Beak 0.9.0 is in .dart_tool/beak/docs
  OK   CLI 0.9.0 matches project Beak 0.9.0
All checks passed.
```

(The listing drops the lines about the database and the optional skills.)

## Limits

- One model, no relationships, no seed data, no custom screen. The [clean shop](clean-shop.md) has all of those.
- No authentication and no policy. The server accepts every request from every origin and listens on all interfaces, so treat the API as local only.
- The default database is a SQLite file in the project folder. It is fine for trying things out. Set `DATABASE_URL` before you put real data in.

## Continue reading

- [Clean shop](clean-shop.md): the same ideas with 20 models, relationships, invoices and a custom operations page.
- [Two ways to boot a panel](../start-here/generated-or-authored.md): the generated bootstrap you saw here and the authored one the shop uses.
- [Generated files and symbols](../reference/generated-files.md): every file `beak prepare` writes and what is in it.
- [Your first resource](../tutorial/01-your-first-resource.md): build a resource of your own, step by step.
