---
title: Project structure
description: Where every file of a Beak project lives, which ones you write, which ones beak prepare writes, and how the layout grows from one model to a shop.
type: guide
audience: [beginner, agent]
status: stable
---

# Project structure

A Beak project is a normal Flutter package with one rule of thumb: you write the schema, the resource and the screens that differ from the default, and `beak prepare` writes everything that only connects them. This page shows the layout on day one, how it grows, and where each kind of decision lives.

## At a glance

What `beak create acme_admin` plus `beak prepare` leaves on disk, generated bootstrap (files marked `*` are the ones you author):

```text
acme_admin/
├── pubspec.yaml               *  one dependency: beak
├── beak.yaml                  *  title, API origin, per-table icon and section
├── analysis_options.yaml
├── AGENTS.md  CLAUDE.md          managed block for coding agents, plus your notes
├── lib/
│   ├── main.dart                 generated, git-ignored: runApp(const BeakApp())
│   ├── resources/
│   │   └── notes/
│   │       └── models/
│   │           ├── note.dart     *  the @Resource class
│   │           └── note.beak.dart   generated part: fields, model, record view
│   ├── migrations/
│   │   └── create_notes_table.dart  written once by prepare, then yours
│   └── beak/                     generated wiring, committed, never edited
│       ├── registry.g.dart       every model
│       ├── panel.g.dart          the panel configuration (generated bootstrap only)
│       ├── app.g.dart            the BeakApp widget (generated bootstrap only)
│       └── server.g.dart         beakHost(): database, migrations, storage
├── bin/
│   ├── serve.dart                generated, git-ignored: serves the API
│   └── migrate.dart              generated, git-ignored: migrations and seeders
├── test/widget_test.dart         boots the panel against an in-memory source
└── web/                          Flutter's own web scaffold
```

The same project, authored (`beak create --authored`, or `beak eject main` later), differs in two places:

| | Generated | Authored |
| --- | --- | --- |
| `lib/main.dart` | Generated, git-ignored. | Yours, committed: `BeakPanel(resources: [...])`. |
| `lib/resources/notes/` | The schema only. | The schema plus `note_resource.dart`, a `BeakResource` listed in `main.dart`. |

Everything else is identical. [Two ways to boot a panel](generated-or-authored.md) explains the choice.

## How the layout grows

The layout is a convention, not a requirement: `beak prepare` scans every `.dart` file under `lib/`, except `*.beak.dart`, `*.g.dart`, `*.freezed.dart` and names starting with `_`. `beak create`, `beak make:resource` and `beak introspect` all use the same one, a folder per resource:

```text
lib/resources/<plural>/
├── models/<name>.dart        the @Resource schema class (and its generated <name>.beak.dart)
├── <name>_resource.dart      a BeakResource subclass: title, navigation, filters, screens
└── screens/                  forms, tables and reusable sections for this resource
```

The shop (`examples/clean_beak_config`) is that layout at eleven resources, with the rest of a real application around it:

```text
lib/main.dart                   authored: the panel and its resource list
lib/resources/<resource>/       models/, <resource>_resource.dart, screens/
lib/domain/                     pure calculations shared by screens and the server
lib/server.dart                 beakServer(...): policy, graph rules, graphOnly
lib/migrations/                 create-table migrations, plus the ones you wrote
lib/seeders/                    repeatable example data
lib/widgets/                    custom widgets used by screens
lib/overview.dart, operations.dart   custom pages, passed to BeakPanel(pages: [...])
lib/beak/                       generated registry, panel and server wiring
bin/                            generated serve.dart and migrate.dart
test/                           model, API, form and widget tests
```

There is no file per field and no file per operation. A small resource is a schema class and, when you want to shape it, a resource class. Add a `screens/` folder when a form or table earns its own file. A folder per resource keeps the diff of one feature in one place, which matters more the day a coding agent works on it.

## Where each decision lives

| You want to change | Edit | Then run |
| --- | --- | --- |
| A field, its type, validation, label or visibility | The schema class in `models/` | `beak prepare` |
| A relationship | The schema class (`@BelongsTo`, `@HasMany`, `@BelongsToMany`) | `beak prepare` |
| The database columns | A migration in `lib/migrations/` (start from `beak make:migration Name --from-drift`) | `beak migrate` |
| Title, icon, sidebar group, filters, which screens a resource has | The `<name>_resource.dart` (`beak eject resource <table>` writes the starter) | `beak prepare` |
| Table columns, form layout, wizard steps | A `BeakTableScreen` or `BeakFormScreen` in the resource | hot restart the panel (`R`) |
| Panel title, API origin, sidebar behaviour | `beak.yaml` (generated), or `BeakPanel(...)` in `main.dart` (authored) | `beak prepare` (generated) |
| A custom page | A top-level `BeakScreen` in `lib/screens/` (generated), or in any file you pass to `pages:` (authored) | `beak prepare` (generated) |
| Theme, auth, whole panel config | `beak eject theme\|auth\|panel` (generated), or `BeakPanel` arguments (authored) | `beak prepare` |
| Who may read and write what | `lib/server.dart` (`beak eject server`) and the model's policies | restart `beak dev` |
| Seed data | A `Seeder` in `lib/seeders/` | `beak seed` |
| Port, host | `beak.yaml` `server:`, or `PORT` and `HOST` in the environment | restart `beak dev` |

## Rules and limits

- **Never edit generated files.** `*.beak.dart` and `lib/beak/*.g.dart` are rewritten by `beak prepare` and byte-compared by `beak doctor`. A change belongs in the schema class, the resource class or `beak.yaml`.
- **Commit the generated wiring.** `lib/beak/*.g.dart` and the `*.beak.dart` parts are committed, so a fresh clone analyzes before any `beak` command runs. The three entrypoints (`lib/main.dart` when generated, `bin/serve.dart`, `bin/migrate.dart`) are git-ignored, because they change nothing worth reviewing.
- **Migrations are yours once written.** `beak prepare` writes a `create_<table>_table.dart` for a table without one and never touches it again. Migrations run in the order of their declared `name` (a timestamp prefix), not their file name.
- **Move a schema class before its migration exists, or fix the import.** Discovery ignores folders, but the create-table migration imports the schema by relative path. Move `note.dart` afterwards and `dart analyze` fails inside `lib/migrations/`. `beak doctor` fails too, with `lib/migrations/create_notes_table.dart imports ../resources/notes/models/note.dart, which does not exist`.
- **A resource class must be public, not abstract, and constructible with no arguments** (an unnamed constructor without required parameters). A class with only named constructors is skipped, and its model keeps the generated default.
- **The folder name is the plural of the class.** `Category` becomes `categories`, `Person` becomes `people`. It only names a folder and a table default; set `@Resource(table:)` to override the table when the pluraliser does not know the word.
- **Run every `beak` command from the project root.** `beak prepare` refuses a directory without a `pubspec.yaml` (`run beak create <name>`) or whose `pubspec.yaml` has no Beak dependency (`run beak init`), and writes nothing.
- **A package of schema classes on its own** (it depends on `beak_core` and not on `beak`) gets the `*.beak.dart` parts and `lib/beak/registry.g.dart` and nothing else. That is the shape of the shared models package in a Serverpod workspace.

## Verify it

```console
$ beak doctor
  OK   project depends on Beak
  OK   beak.yaml parses
  OK   discovered 2 models · 1 resource class · 0 screens · 0 overrides
  OK   generated files up to date
  OK   every model has a migration
  ...
All checks passed.
```

The `discovered` line is the fastest way to see what Beak found: models, resource classes, screens under `lib/screens/`, and override files. A resource class that is missing from the count is not public, is abstract, or has no usable constructor. `beak prepare` twice in a row must report `up to date`; if it does not, something rewrites a generated file behind its back.

## Reference

| Path | Written by | Committed | Rewritten |
| --- | --- | --- | --- |
| `lib/resources/<plural>/models/<name>.dart` | you (`make:resource` starts it) | yes | never |
| `lib/resources/<plural>/models/<name>.beak.dart` | `beak prepare` | yes | when the schema changes |
| `lib/resources/<plural>/<name>_resource.dart` | you (`make:resource`, `eject resource`) | yes | never |
| `lib/migrations/create_<table>_table.dart` | `beak prepare`, once | yes | never |
| `lib/beak/registry.g.dart`, `server.g.dart` | `beak prepare` | yes | when their inputs change |
| `lib/beak/panel.g.dart`, `app.g.dart` | `beak prepare`, with a generated `lib/main.dart` | yes | when their inputs change; deleted once the entrypoint is yours |
| `lib/main.dart` | `beak prepare` (generated) or you (authored) | authored only | generated only |
| `bin/serve.dart`, `bin/migrate.dart` | `beak prepare` | no | when their inputs change |
| `lib/screens/*.dart` | you | yes | never |
| `lib/server.dart`, `lib/theme.dart`, `lib/auth.dart`, `lib/panel.dart` | you (`beak eject server\|theme\|auth\|panel`) | yes | never |
| `lib/seeders/*.dart` | you | yes | never |
| `beak.db`, `.env`, `storage/` | runtime | no | n/a |

The complete list, with the symbols generated for each schema, is [Generated files and symbols](../reference/generated-files.md).

## Continue reading

- [Two ways to boot a panel](generated-or-authored.md): what `lib/main.dart` is in each, and how to switch.
- [Defining models](../models/defining-models.md): the schema classes in `models/`.
- [Resources](../panel/resources.md): the `<name>_resource.dart` files.
- [Generated files and symbols](../reference/generated-files.md): every file and symbol `beak prepare` writes.
