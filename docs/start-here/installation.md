---
title: Installation
description: Install the beak command and create a project, including the two pre-release workarounds for the missing v0.9.0 tag and the obers_ui pin.
type: guide
audience: [beginner]
status: stable
---

# Installation

After this page you have the `beak` command on your path and a project it created, resolved and generated. The [Quickstart](quickstart.md) picks up from there.

Two things are not finished yet, and this page says so where they bite: Beak `0.9.0` is not tagged, and the obers_ui commit Beak pins is older than the code. Both go away at release. Until then the steps below are the ones that work.

## At a glance

| You need | Version | Why |
| --- | --- | --- |
| Dart SDK | `^3.11` | The CLI and the server half. |
| Flutter | `3.41` or newer | The panel. `beak create` calls `flutter pub get` and `flutter create`. |
| git | any | The CLI and the obers_ui pin come from git. |

That is the whole list. A new project's database is a SQLite file Beak creates on first run, so there is nothing to install or start before you see a panel. Docker and Postgres show up later, and only if you want them.

| Step | Command |
| --- | --- |
| Get the code | `git clone https://github.com/SimonErich/beak.git` |
| Install the CLI | `dart pub global activate --source path beak/packages/beak_cli` |
| Create a project | `beak create acme_admin --beak-path "$PWD/beak"` |
| Point the panel at a working obers_ui | `pubspec_overrides.yaml`, [below](#link-obers_ui-until-the-pin-moves) |

## Install the CLI

Clone the repository once, then activate the `beak_cli` package from the checkout:

```bash
git clone https://github.com/SimonErich/beak.git
dart pub global activate --source path beak/packages/beak_cli
```

The pubspec declares `beak` as an executable, so activation puts a `beak` command on your `PATH`. If the shell cannot find it, add pub's bin directory (`$HOME/.pub-cache/bin` on macOS and Linux, `%LOCALAPPDATA%\Pub\Cache\bin` on Windows).

```console
$ beak --version
beak 0.9.0
```

A project never depends on `beak_cli`. The CLI is a tool you install once; the project depends on the `beak` package.

Once a release is tagged you can skip the clone and activate straight from git:

```bash
dart pub global activate --source git https://github.com/SimonErich/beak.git \
  --git-path packages/beak_cli --git-ref v0.9.0
```

That form needs a ref that exists. `v0.9.0` does not yet, which is the next section.

## The release is not tagged yet

A plain `beak create` writes a pubspec that depends on Beak by git, at the tag that matches the CLI version:

```yaml title="acme_admin/pubspec.yaml (default beak create)"
dependencies:
  beak:
    git:
      url: https://github.com/SimonErich/beak.git
      ref: v0.9.0
      path: packages/beak
```

`v0.9.0` does not exist until the release is cut, so today `flutter pub get` fails:

```console
$ beak create demo
  created demo/pubspec.yaml
  ...
Resolving dependencies...
Because demo depends on beak from git which doesn't exist (Could not find git ref 'v0.9.0' ...), version solving failed.
  `flutter pub get` failed (exit 69). Fix what it reports, then run `flutter pub get` and `beak prepare` in demo.
```

The files are written, so nothing is lost, but the project is not resolved. Tell `create` where Beak is instead. The two flags are alternatives, and passing both is a usage error.

| Flag | What it does | Use it when |
| --- | --- | --- |
| `--beak-path <repo root>` | Writes a `path:` dependency on `<repo root>/packages/beak`. | You have a checkout, which is the case after the clone above. |
| `--beak-ref <ref>` | Keeps the git dependency, pinned to a branch, tag or commit. | The ref exists on `github.com/SimonErich/beak`. |

The argument of `--beak-path` is the root of the checkout. The CLI appends `/packages/beak` itself, so pointing it at `beak/packages/beak` writes a path that does not exist and `flutter pub get` fails. It also writes the path exactly as you typed it, and pub reads a relative one relative to the new project, so pass an absolute path:

```bash
beak create acme_admin --beak-path "$PWD/beak"
```

Move the checkout and `flutter pub get` breaks, which is one more reason to switch to the tag when it exists.

## Link obers_ui until the pin moves

Beak's panel is built on obers_ui, and `beak` pins it by git commit, not by version. Two consequences follow.

- **The pinned commit has to be fetchable.** Every `flutter pub get`, and every `melos bootstrap` in a clone of Beak, downloads it from `github.com/SimonErich/obers_ui`. It exists today. If that repository or the commit ever disappears, resolution fails and nothing on this page helps.
- **The pinned commit is older than the code.** `beak_frontend` uses obers_ui APIs the pinned commit does not have. A project resolved from the pin fails when it compiles the panel:

```console
$ flutter test
.../beak_frontend/lib/src/blocks/beak_block_host.dart:241:5: Error: No named parameter with the name 'headerGap'.
.../beak_frontend/lib/src/blocks/views/beak_summary_block_view.dart:226:38: Error: Member not found: 'OiIcon.raw'.
```

Until the pin catches up, give the project a checkout of obers_ui to resolve against. Clone [obers_ui](https://github.com/SimonErich/obers_ui) next to the project and add a `pubspec_overrides.yaml` beside `pubspec.yaml`:

```yaml title="acme_admin/pubspec_overrides.yaml"
dependency_overrides:
  obers_ui:
    path: ../obers_ui
  obers_ui_autoforms:
    path: ../obers_ui/packages/obers_ui_autoforms
  obers_ui_charts:
    path: ../obers_ui/packages/obers_ui_charts
```

Then run `flutter pub get` again. With that file a freshly created project passes its own `flutter test`. The API half (`beak migrate`, `beak dev`) never touches obers_ui, so it works without the file.

Inside a clone of the Beak repository `melos run link-obers-ui` does the same for every package and example. [Working with obers_ui](../contributing/working-with-obers-ui.md) covers it.

## Create a project

```bash
beak create acme_admin --beak-path "$PWD/beak"
cd acme_admin
```

`beak create` runs in this order: it writes the files you own, lets `flutter create --platforms=web` write `web/`, runs `flutter pub get`, runs `beak prepare` to generate the wiring, and installs the agent files and workflow skills. What you own is small:

```text
acme_admin/
├── pubspec.yaml                          one dependency: beak
├── beak.yaml                             title, API origin, per-table icon and section
├── analysis_options.yaml
├── AGENTS.md  CLAUDE.md                  what a coding agent needs to know about the layout
├── README.md  .gitignore
├── lib/resources/notes/models/note.dart  one @Resource class, the example to replace
├── test/widget_test.dart                 boots the panel against an in-memory data source
└── web/                                  Flutter's own web scaffold
```

`beak prepare` adds the generated half: the model's part file (`note.beak.dart`), the create-table migration, four wiring files under `lib/beak/`, and the entrypoints `lib/main.dart`, `bin/serve.dart` and `bin/migrate.dart`. [Project structure](project-structure.md) says which of those you may edit (none of the generated ones) and how to take a default over.

The flags of `beak create` are in the [Reference](#reference) below. Two are worth knowing on day one:

- `--authored` writes a `lib/main.dart` you own instead of the generated one. [Two ways to boot a panel](generated-or-authored.md) explains the choice.
- `--no-pub` writes the files and prints the commands to run, for a machine without a network.

## One dependency

The generated `pubspec.yaml` names Beak once. The `beak` package re-exports each layer as its own library, so you import the one a file needs and never keep five version constraints in step:

| Library | What it holds |
| --- | --- |
| `package:beak/beak.dart` | Columns, models, relationships, the query spec, `BeakClient`, the storage abstraction. Shared by the panel and the server. |
| `package:beak/schema.dart` | The annotations a schema class carries: `@Resource`, `@Column`, `@BelongsTo`. |
| `package:beak/panel.dart` | The panel: `BeakPanel`, resources, blocks, tables, forms. |
| `package:beak/server.dart` | The Shelf host, its config, storage wiring, auth, policy. |
| `package:beak/migrations.dart` | The migration and seeder DSL. |
| `package:beak/testing.dart` | `InMemoryBeakDataSource`, fixtures and the data-source contract suite. |
| `package:beak/ui.dart` | obers_ui and obers_ui_autoforms, for a screen that draws its own widgets. |
| `package:beak/charts.dart` | obers_ui_charts. |

A schema class imports `beak.dart` and `schema.dart` and nothing else. `beak.dart` carries no widgets on purpose: `bin/serve.dart` reaches your schema classes, and a server that pulled in `dart:ui` would stop compiling ahead of time. [Libraries](../reference/libraries.md) has the full split.

## Rules and limits

- **No database step.** With no `DATABASE_URL`, the database is `beak.db` beside the project, and `beak doctor` counts that as a pass. Put `DATABASE_URL=postgres://...` in a `.env` when you want Postgres. [Databases](../backend/databases.md) covers it.
- **Beak never changes a database on boot.** `beak migrate` applies migrations, and you run it on purpose, once per schema change.
- **`beak create` refuses a directory that already has files.** It exits `1` and writes nothing; an empty directory is fine. To add Beak to a Flutter app you already have, use [`beak init`](paths/existing-flutter-app.md) instead.
- **`beak prepare`, `dev` and `migrate` run from the project root.** Elsewhere they stop with `no Beak dependency here; run beak init` and write nothing.
- **A `--beak-path` dependency is local.** The scaffold records the checkout's path, so it is a convenience for your machine and not something to commit for a team.
- **The panel does not compile against the pinned obers_ui yet.** See [Link obers_ui](#link-obers_ui-until-the-pin-moves) above; the API and the migrations are unaffected.

## Verify it

```console
$ beak --version
beak 0.9.0
$ cd acme_admin
$ beak doctor
  OK   project depends on Beak
  OK   beak.yaml parses
  OK   discovered 1 model · 0 resource classes · 0 screens · 0 overrides
  OK   generated files up to date
  OK   every model has a migration
  OK   web/ scaffold present
  OK   no panel file imports the server
  ...
All checks passed.
```

Then run the project's own test, which boots the panel against an in-memory data source:

```bash
flutter test
```

It passes once obers_ui resolves against a checkout that has the newer APIs, and fails to compile the panel before that.

## Reference

`beak create <name>` takes exactly one argument, a `lower_snake_case` package name.

| Flag | Default | Effect |
| --- | --- | --- |
| `--beak-path <repo root>` | none | Depend on a local checkout. The CLI appends `packages/beak`. |
| `--beak-ref <ref>` | `v0.9.0` (derived from the CLI version) | The git ref of the git dependency. Mutually exclusive with `--beak-path`. |
| `--authored` | off | Write a `lib/main.dart` the project owns, listing a `NoteResource`. |
| `--[no-]example` | on | Write the `Note` schema class. `--no-example` starts empty; add the first resource with `beak make:resource`. |
| `--[no-]pub` | on | Run `flutter pub get`, `beak prepare` and the agent files. `--no-pub` stops after writing files. |
| `--skills claude,agents,cursor\|none` | the agent folders the project has, then `claude` and `agents` | Where to install the workflow skills. |

The full command list is in [CLI commands](../reference/cli-commands.md).

## Continue reading

- [Quickstart](quickstart.md): migrate, serve and open the panel of the project you just created.
- [Project structure](project-structure.md): what every file in it is for, and which ones you may edit.
- [Choose your path](paths/index.md): start from a database, a Flutter app, a Serverpod workspace or a backend you already have.
- [CLI commands](../reference/cli-commands.md): every command and flag.
