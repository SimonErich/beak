---
title: Installation
description: Install the Beak CLI and scaffold your first admin panel. No Docker, no database to set up.
---

# Installation

After this page you have the `beak` command on your path and a project it
created. The [Quickstart](quickstart.md) picks up from here.

## Prerequisites

| Tool | Version | Why you need it |
| --- | --- | --- |
| Dart SDK | `^3.11` | The CLI and the server half. |
| Flutter | stable, `3.41` or newer | The panel. |

That is the whole list. A new project's database is a SQLite file Beak creates
on first run, so there is nothing to install, start, or configure before you
see a panel. Docker and Postgres become relevant later, when you want a server
database or object storage, and both are opt-in.

## Install the CLI

```bash
dart pub global activate --source git https://github.com/SimonErich/beak.git \
  --git-path packages/beak_cli
```

Check it:

```bash
beak --help
```

If the command is not found, add pub's bin directory to your `PATH`
(`$HOME/.pub-cache/bin` on macOS and Linux, `%LOCALAPPDATA%\Pub\Cache\bin` on
Windows).

## Create a project

```bash
beak create acme_admin
cd acme_admin
```

`beak create` writes the files you own, delegates `web/` to
`flutter create --platforms=web`, and then runs `beak prepare` for you, so the
project is runnable as created rather than one command short of it. What you
own is small:

```text
acme_admin/
├── pubspec.yaml            one dependency: beak
├── beak.yaml               title, API origin, icons, sections (every key optional)
├── analysis_options.yaml
├── AGENTS.md               what an AI coding agent needs to know about the layout
├── README.md
├── .gitignore
├── lib/models/note.dart    one @Resource class, the example to replace
├── test/widget_test.dart   boots the panel against an in-memory data source
└── web/                    Flutter's own web scaffold
```

The `beak prepare` that follows generates nine more files: the model's part
file (`lib/models/note.beak.dart`), the migration that table needs
(`lib/migrations/create_notes_table.dart`), the four wiring files under
`lib/beak/`, and the three entrypoints (`lib/main.dart`, `bin/serve.dart`,
`bin/migrate.dart`).

Everything else (the panel, the router, the REST API, the query layer) comes
from the `beak` package itself. You never edit generated code, and you can take
any Beak default over with `beak eject` when you want to. See
[Project structure](project-structure.md) for what each of those files is.

## One dependency

A generated `pubspec.yaml` names Beak once:

```yaml
dependencies:
  beak:
    git:
      url: https://github.com/SimonErich/beak.git
      path: packages/beak
  flutter:
    sdk: flutter
```

The `beak` package re-exports each layer as its own library, so you import the
one you need and never keep five version constraints in step. Which library a
file imports says what that file is:

| Library | What it holds |
| --- | --- |
| `package:beak/beak.dart` | Columns, models, relationships, the query spec, `BeakClient`, the storage abstraction. Shared by the panel and the server. |
| `package:beak/schema.dart` | The annotations a schema class carries: `@Resource`, `@Column`, `@BelongsTo`. |
| `package:beak/panel.dart` | The panel: `BeakPanel`, resources, blocks, tables, forms. |
| `package:beak/server.dart` | The Shelf host, its config, storage wiring, auth, policy. |
| `package:beak/migrations.dart` | The schema DSL for migrations and seeders. |
| `package:beak/testing.dart` | `InMemoryBeakDataSource`, `BeakRecordingDataSource`, fixtures, and the executable data-source contract. |
| `package:beak/ui.dart` | obers_ui, for a screen that draws its own widgets. |
| `package:beak/charts.dart` | obers_ui_charts. |

A file under `lib/models/` imports `beak.dart` and `schema.dart`, and nothing
else. `panel.dart`, `server.dart` and `migrations.dart` re-export `beak.dart`,
so everything else usually needs one import.

!!! note "Why `beak.dart` carries no widgets"
    `bin/serve.dart` reaches the generated registry, and the registry reaches
    your models. If any of those pulled in `dart:ui`, the server would stop
    compiling ahead of time. Keeping the widgets in `panel.dart` makes that
    mistake impossible, and `beak doctor` catches it if a panel file imports
    the server by hand.

## Resolve and run

```bash
flutter pub get
beak migrate
beak dev
```

`beak migrate` applies the migration `beak prepare` wrote. Beak never alters a
database on boot, so this is a step you take deliberately, once per schema
change.

`beak dev` regenerates the wiring and serves the API on
`http://localhost:8080`. It prints the `flutter run` line for the panel rather
than spawning it, so paste that into a second terminal:

```console
$ beak dev
  1 model · 0 screens · 0 overrides
  generated  up to date (7 files)
  panel      run this in another terminal:
               flutter run -d chrome
  api        starting…
```

With no `DATABASE_URL`, the database is a SQLite file (`beak.db`, git-ignored)
beside the project. Nothing to install and nothing to start.

## A real database

When you want Postgres, put a `DATABASE_URL` in a `.env` beside your
`pubspec.yaml`:

```bash
DATABASE_URL=postgres://user:pass@localhost:5432/acme
```

Uploads need a storage driver. Leave `BEAK_STORAGE_DRIVER` unset to keep files
on local disk, served by the Beak server itself:

```bash
BEAK_STORAGE_DRIVER=s3
BEAK_S3_ENDPOINT=http://localhost:9000
BEAK_S3_BUCKET=acme-uploads
BEAK_S3_ACCESS_KEY=...
BEAK_S3_SECRET_KEY=...
BEAK_S3_REGION=us-east-1
BEAK_S3_USE_PATH_STYLE=true
```

The S3 driver is registered by the project, not by Beak: declare a
`beakStorageRegistry()` in `lib/server.dart` and `beak prepare` wires it into
the host. See
[Uploads and storage wiring](../backend/uploads-and-storage-wiring.md).

`.env` is git-ignored by the generated `.gitignore`. Check the whole setup at
any time:

```bash
beak doctor
```

No `DATABASE_URL` is a passing check, not a warning: it is the supported
zero-setup default.

## Already have a database?

Point Beak at it and it writes the models for you:

```bash
beak introspect postgres://user:pass@localhost:5432/existing_app
beak prepare
```

It reads types, nullability, defaults, foreign keys and enum labels, and writes
the same annotated classes you would have written by hand. The result is an
ordinary Beak project whose first draft happened to come from a database. Edit
it and it stays yours.

## Working on Beak itself

Contributors clone the monorepo instead. See
[Contributing](../contributing/index.md) for the Melos workspace, the
four-command gate, and the Docker stack the integration tests use.

## Continue reading

- [Quickstart](quickstart.md) a resource, a migration, and a running panel.
- [Project structure](project-structure.md) what each folder is for, and which
  files you can take over.
- [Libraries](../reference/libraries.md) the eight libraries in full, and why
  the split is enforced rather than trusted.
- [CLI commands](../reference/cli-commands.md) `create`, `prepare`, `dev`,
  `migrate`, `introspect`, `eject`, `doctor` and their flags.
