---
title: Installation
description: Install the Beak CLI and scaffold your first admin panel.
---

# Installation

After this page you have the `beak` command on your path and a project it
created. The [Quickstart](quickstart.md) picks up from here.

## Prerequisites

| Tool | Version | Why you need it |
| --- | --- | --- |
| Dart SDK | `^3.11` | The CLI and the server half. |
| Flutter | stable, `3.41` or newer | The panel. |
| Docker | any recent release | Only if you want Postgres and MinIO locally. SQLite needs nothing. |

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

That writes six files and generates eight more. The whole project is:

```
acme_admin/
├── pubspec.yaml          one dependency: beak
├── beak.yaml             title, icons, sections — every key optional
├── lib/models/note.dart  one @Resource class, the example to replace
├── analysis_options.yaml
├── AGENTS.md             what an AI coding agent needs to know about the layout
└── .gitignore
```

Everything else — the panel, the router, the REST API, the entrypoints — comes
from the `beak` package and is generated into `lib/beak/` on demand. You never
edit it, and you can take any of it over with `beak eject` when you want to.

## One dependency

A generated `pubspec.yaml` names Beak once:

```yaml title="pubspec.yaml"
dependencies:
  beak:
    git:
      url: https://github.com/SimonErich/beak.git
      path: packages/beak
  flutter:
    sdk: flutter
```

The `beak` package re-exports each layer as its own library, so you import the
one you need and never keep five version constraints in step:

| Library | What it carries |
| --- | --- |
| `package:beak/beak.dart` | Columns, models, query specs — shared by the panel and the server. |
| `package:beak/panel.dart` | The Flutter widgets. Re-exports `beak.dart`. |
| `package:beak/schema.dart` | `@Resource`, `@Column`, `@BelongsTo` — what a model file uses. |
| `package:beak/server.dart` | The Shelf host, its config, storage. |
| `package:beak/migrations.dart` | The schema DSL for migrations and seeders. |
| `package:beak/testing.dart` | The in-memory data source and the adapter contract. |
| `package:beak/ui.dart` | obers_ui, for screens you compose yourself. |
| `package:beak/charts.dart` | obers_ui_charts. |

!!! note "Why `beak.dart` carries no widgets"
    `bin/serve.dart` reaches the generated registry, and the registry reaches
    your models. If any of those pulled in `dart:ui`, the server would stop
    compiling ahead of time. Keeping the widgets in `panel.dart` makes that
    mistake impossible, and `beak doctor` catches it if a panel file imports
    the server by hand.

## Resolve and run

```bash
flutter pub get
beak dev
```

`beak dev` regenerates, starts the API, and runs the panel. With no
`DATABASE_URL` it uses a SQLite file (`beak.db`, git-ignored) beside the
project, so there is nothing to install and nothing to start.

## A real database

When you want Postgres, put a `DATABASE_URL` in a `.env` beside your
`pubspec.yaml`:

```bash title=".env"
DATABASE_URL=postgres://user:pass@localhost:5432/acme
```

Uploads need a storage driver; leave `BEAK_STORAGE_DRIVER` unset to keep files
on local disk:

```bash title=".env"
BEAK_STORAGE_DRIVER=s3
BEAK_S3_ENDPOINT=http://localhost:9000
BEAK_S3_BUCKET=acme-uploads
BEAK_S3_ACCESS_KEY=...
BEAK_S3_SECRET_KEY=...
BEAK_S3_USE_PATH_STYLE=true
```

`.env` is git-ignored by the generated `.gitignore`. Check the whole setup at
any time:

```bash
beak doctor
```

## Already have a database?

Point Beak at it and it writes the models for you:

```bash
beak introspect postgres://user:pass@localhost:5432/existing_app
beak prepare
```

It reads types, nullability, defaults, foreign keys and enum labels, and writes
the same annotated classes you would have written by hand — an ordinary Beak
project whose first draft happened to come from a database.

## Working on Beak itself

Contributors clone the monorepo instead. See
[Contributing](../contributing/index.md) for the Melos workspace, the
four-command gate, and the Docker stack the integration tests use.

## Continue reading

- [Quickstart](quickstart.md) — a resource, a migration, and a running panel.
- [Project structure](project-structure.md) — what each folder is for.
