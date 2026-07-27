---
title: Project structure
description: What a Beak project contains, which folders are discovered, which files are generated, and which optional files override a default.
---

# Project structure

After this page you know what every folder in your project is for, which files
Beak writes, and which ones you can create to take a default over.

## What `beak create` gives you

```text
acme_admin/
  pubspec.yaml          REQUIRED   one dependency: beak
  beak.yaml             optional   title, api origin, icons, sections
  lib/
    models/             DISCOVERED one @Resource class per file
    screens/            optional   a top-level BeakScreen per file
    migrations/         GENERATED first, then yours; discovered and registered
    resources/          optional   one file per resource you want to adjust
    seeders/            optional   discovered and registered
    beak/*.g.dart       GENERATED, committed
    main.dart           GENERATED, git-ignored
  bin/
    serve.dart          GENERATED, git-ignored
    migrate.dart        GENERATED, git-ignored
  test/
  web/
  assets/               optional
```

The smallest working project is a `pubspec.yaml` and one model file. Everything
else is optional or generated.

## Discovered folders

You never register anything. `beak prepare` scans these and wires up what it
finds, reporting a one-line summary (`4 models · 1 screen · 2 overrides`) so a
miss is visible rather than silent.

| Folder | What Beak looks for |
| --- | --- |
| `lib/models/` | A class extending `BeakSchema` with `@Resource`, or a hand-written `BeakModel`. Becomes a resource: pages, routes, REST endpoints. |
| `lib/screens/` | A top-level `BeakScreen`, or a zero-argument function returning one. Becomes a page in the sidebar. |
| `lib/migrations/` | A class extending `Migration` with a `const` constructor. Registered on the host in **declared-name order**, so a timestamp prefix controls when it runs. |
| `lib/seeders/` | A class extending `Seeder`. Registered for `beak seed`. |
| `lib/resources/` | `BeakResource beakResource(BeakResource generated)`, in a file named after the table. Adjusts that one resource. |

A class that cannot be used is reported by name and file — a model with no
`const` constructor, a screen of the wrong type — rather than skipped.

## Generated files

Two policies, deliberately different.

**`lib/models/*.beak.dart` and `lib/beak/*.g.dart` are committed.** A
path-dependency consumer cannot generate its dependency's sources, and a fresh
clone must analyze before any `beak` command runs. They carry a
`GENERATED — DO NOT EDIT` header; `beak doctor` fails when they are stale.

| File | What it is |
| --- | --- |
| `lib/models/<name>.beak.dart` | The typed column constants and their `values` list, the relationship constants on **both** sides, the `BeakModel`, and a typed record view. |
| `lib/beak/registry.g.dart` | `beakModels` and `buildBeakRegistry()`. |
| `lib/beak/panel.g.dart` | The `BeakPanelConfig`: resources, icons, sections, screens. |
| `lib/beak/app.g.dart` | The root widget, with the `dataSource` seam widget tests use. |
| `lib/beak/server.g.dart` | The `BeakServeHost`: registry, migrations, seeders. |

**`lib/main.dart`, `bin/serve.dart` and `bin/migrate.dart` are git-ignored.**
They sit at the canonical paths so `flutter run`, IDE run buttons, hot reload
and `dart compile exe` work with no flags, and nothing about them is a decision
worth reviewing. Every `beak` command regenerates them first, which is what
makes ignoring them safe. If your team would rather commit them, run
`beak eject main` once.

## Optional override files

Each is presence-based: create the file and Beak uses it; delete it and the
default comes back. Each receives Beak's own defaults, so overriding is
additive rather than a rewrite.

| Path | Symbol | Overrides |
| --- | --- | --- |
| `lib/panel.dart` | `BeakPanelConfig beakPanel(BeakPanelConfig defaults)` | Everything — the last word on the panel. |
| `lib/theme.dart` | `OiThemeData beakLightTheme()` / `beakDarkTheme()` | The light and dark themes. |
| `lib/auth.dart` | `BeakAuthConfig beakAuth()` | Which auth routes exist and what they call. |
| `lib/dashboard.dart` | `BeakScreen beakDashboard()` | The screen at `/`. |
| `lib/server.dart` | `BeakServer beakServer(BeakServerDefaults defaults)` | Middleware, extra routes, the policy. |

`beak eject <target>` writes any of them out, pre-filled with the default:

```bash
beak eject theme
```

Precedence runs library default → `beak.yaml` → `lib/panel.dart`.

## `beak.yaml`

YAML for scalars, enums, ordering and infrastructure; Dart for anything holding
a symbol or a closure. Every key is optional — delete the file and Beak still
boots, titling the panel after the package.

```yaml title="beak.yaml"
name: Acme Admin

api:
  # `auto` calls the origin the panel was served from — what a
  # single-host deployment wants.
  baseUrl: auto

theme:
  sidebar:
    collapsible: true
    startCollapsed: false

resources:
  products:
    icon: package
    section: Catalog
```

It is decoded at generate time into a typed config and emitted as Dart
literals, so no `Map<String, Object?>` ever reaches your runtime. An unknown key
is an error naming the line, an icon has to be a lowerCamelCase `OiIcons` name,
and a `resources` key naming no discovered table is reported with a
did-you-mean.

## The layers, and why `beak.dart` has no widgets

`bin/serve.dart` reaches `lib/beak/server.g.dart`, which reaches
`registry.g.dart`, which reaches your models. If any of those pulled in
`dart:ui`, the server would stop compiling ahead of time. So:

```text
bin/serve.dart ──► server.dart ──► registry.g.dart ──► models/ ──► beak.dart
lib/main.dart  ──► app.g.dart  ──► panel.g.dart    ──► panel.dart ──► beak.dart
```

`package:beak/beak.dart` is the shared vocabulary — columns, models, query
specs — with no Flutter and no `dart:io`. `panel.dart` adds the widgets and
re-exports it, so a screen needs one import. `beak doctor` fails when a panel
file imports the server half by hand.

## Where common things live

| I want to… | Go here |
| --- | --- |
| Add a resource | A new file in `lib/models/`, then `beak prepare`. |
| Change a column's label, rules or visibility | The `@Column` annotation on the field. |
| Add a page that is not a resource | `lib/screens/`. |
| Change an icon or a sidebar section | `beak.yaml`, under `resources:`. |
| Restyle the panel | `beak eject theme`. |
| Add middleware or a policy | `beak eject server`. |
| Change the schema | Edit the schema class, `beak prepare`, then `beak migrate`. Beak writes the first migration for a resource; changing a table later is a migration you write. |
| See what Beak sees | `beak doctor`. |

## Continue reading

- [Quickstart](quickstart.md) — the whole loop in one page.
- [CLI commands](../reference/cli-commands.md) — every command and flag.
- [Contributing](../contributing/index.md) — the Beak monorepo's own layout,
  which is a different thing from your project's.
