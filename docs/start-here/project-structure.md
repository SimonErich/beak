---
title: Project structure
description: How the Beak monorepo is laid out, what each package owns, and the two-app split between the reference admin and the superdashboard.
---

# Project structure

After this page you can find any piece of Beak by folder: which package owns the
column types, which one runs the server, and why the repo ships two demo apps
that never share models.

Beak is a Melos monorepo. Framework code lives under `packages/`, runnable demos
under `apps/`, and the whole thing is orchestrated from `melos.yaml` at the root.

## The top level

```text
beak/
  packages/                # the framework, one package per layer
    beak_core/             # pure Dart vocabulary (no Flutter, no worm)
    beak_backend/          # Shelf server; the only package that imports worm
    beak_frontend/         # the Flutter panel, built on obers_ui
    beak_cli/              # scaffolding: beak make:resource, beak doctor
    beak_storage_s3/       # S3/MinIO storage driver
    beak_storage_ftp/      # FTP storage driver
    beak_image/            # image transform runner (thumbnails, format)
    worm*/                 # the vendored ORM and its drivers (not gated here)
  apps/                    # the two demo apps
    reference_admin_models/ #   shared models for the teaching store
    reference_admin_server/ #   its Shelf backend (port 8080)
    reference_admin/        #   its Flutter panel
    beak_superdashboard/    #   the all-in-one showcase (port 8180)
  melos.yaml               # workspace scope + gate scripts
  docker-compose.yml       # Postgres + MinIO + pgweb
  pubspec.yaml             # workspace root; pins melos 6.3.3
  analysis_options.yaml    # strict, shared lints
  tool/                    # the coverage gate and the no-Material guard
  docs/                    # this documentation site
```

Melos manages everything under two globs, and deliberately ignores the vendored
worm tree:

```yaml title="melos.yaml"
packages:
  - packages/**
  - apps/**

ignore:
  - packages/worm
  - packages/worm/**
  - packages/worm_*
  - packages/worm_*/**
```

## The framework packages

Each package owns one layer, and every layer speaks the shared vocabulary that
lives in `beak_core`.

| Package | What it holds |
| --- | --- |
| `beak_core` | Pure Dart, no Flutter and no worm. Typed columns and rules, relationships, the serializable `BeakQuerySpec` wire contract, the storage abstraction with file rules, the `BeakDataSource` seam, and the raw `BeakClient`. |
| `beak_backend` | The Shelf server. Generated CRUD, query, batch, relations, and aggregate endpoints; validated uploads; auth; global search; CSV export. The only package that imports worm. |
| `beak_frontend` | The Flutter panel. `BeakPanel` plus the generated tables, forms, detail views, actions, filters, and dashboards, on obers_ui with HookWidget, Signals, GetIt, and go_router. |
| `beak_cli` | Scaffolding. `beak make:resource` and friends, and `beak doctor`. |
| `beak_storage_s3`, `beak_storage_ftp` | Pluggable storage drivers registered at startup. Memory and local disk ship inside `beak_core`. |
| `beak_image` | The image transform runner that powers thumbnail and format transforms on upload. |
| `packages/worm*` | The vendored worm ORM and its drivers. Consumed as path dependencies, not gated here; do not send Beak changes to worm code. |

The obers_ui trio (`obers_ui`, `obers_ui_autoforms`, `obers_ui_charts`) is not in
this tree at all: it is fetched from git at a
[pinned commit](installation.md#the-obers_ui-dependency) into your pub cache.
Beak never draws a Material widget of its own.

## The two-app split

Beak ships two demo apps, and they use **different model sets**. Keep them
straight: a column constant from one will not compile against the other, and
their servers listen on different ports.

### The reference admin (the teaching store)

`apps/reference_admin*` is the small coffee-roastery store the
[Quickstart](quickstart.md) and the tutorial use: products, categories, tags,
users, orders. It is split into **three packages** so the split between "define
once" and "consume everywhere" is visible in the folder layout:

```text
apps/
  reference_admin_models/  # shared BeakModel + column definitions
    lib/src/               #   product.dart, category.dart, tag.dart,
                           #   user.dart, order.dart, order_item.dart
  reference_admin_server/  # the Shelf backend (port 8080)
    bin/                   #   reference_admin_server.dart, worm.dart
    lib/src/               #   migrations/, seeders/, server_builder.dart
  reference_admin/         # the Flutter panel
    lib/main.dart          #   one BeakPanel over the shared models
```

`reference_admin_models` is the single source of truth. The server imports it to
generate its API, and the panel imports it to generate its pages, so the two can
never drift. Its server runs on port **8080**, which is the panel's default
`apiBaseUrl`.

### The superdashboard (the showcase)

`apps/beak_superdashboard` is the kitchen-sink demo: dozens of models, every
block, every view mode, custom screens. It is a **single package** that holds the
models, migrations, seeders, the server binary, and the panel all in one
deployable unit:

```text
apps/beak_superdashboard/
  bin/                     # server.dart, worm.dart
  lib/
    models/                # the showcase's BeakModels
    migrations/            # worm migrations
    seeders/               # demo data factories
    server/                # the Shelf server wiring
    panel/                 # the BeakPanelConfig (resources, dashboard, auth)
    screens/               # custom, non-resource screens
    services/              # dashboard data mappers
    main.dart              # the panel entry point
```

Its server runs on port **8180**. The feature, blocks, charts, and reference
pages draw their snippets from here. When you copy a snippet, match its
`apiBaseUrl` port to the app it came from.

!!! tip "Which app a page uses"
    Start-here and the tutorial use the reference admin (port 8080). The feature
    reference pages use the superdashboard (port 8180). If a snippet will not
    connect, check the port against the app it came from.

## Where common things live

| Looking for | It lives in |
| --- | --- |
| Column types and validation rules | `packages/beak_core/lib/src/columns/`, `.../rules/` |
| The query wire format | `packages/beak_core/lib/src/query/` |
| Generated REST routes | `packages/beak_backend/lib/src/endpoints/` |
| Migrations and seeders (reference) | `apps/reference_admin_server/lib/src/migrations/`, `.../seeders/` |
| The panel shell, tables, forms | `packages/beak_frontend/lib/src/` |
| The gate scripts and guards | `melos.yaml`, `tool/` |
| Local service config | `docker-compose.yml`, `.env.example` |

## Continue reading

- [Installation](installation.md) get the toolchain and services in place.
- [Quickstart](quickstart.md) run the reference admin end to end.
- [Packages](../reference/packages.md) the full export list for every package.
- [The four layers](../concepts/the-four-layers.md) how backend and frontend code
  is layered inside these packages.
- [Package graph](../architecture/package-graph.md) the dependency edges between
  them.
