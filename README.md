# Beak

[![CI](https://github.com/SimonErich/beak/actions/workflows/ci.yaml/badge.svg)](https://github.com/SimonErich/beak/actions/workflows/ci.yaml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
![Dart](https://img.shields.io/badge/Dart-%5E3.11-0175C2?logo=dart)
![Flutter](https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter)

A **low-code, configuration-driven admin-panel framework** for Dart/Flutter.
Define a model once — columns, validation, relationships, storage — and compose
obers_ui widgets that auto-wire to a Shelf backend: no hand-written endpoints,
no client/server plumbing, fully type-safe, zero Material.

```dart
abstract final class ProductColumns {
  static const name = BeakStringColumn(
    key: 'name', label: 'Name',
    searchable: true, sortable: true,
    rules: [BeakRequired(), BeakMaxLength(255)],
  );
  static const price = BeakDecimalColumn(
    key: 'price', label: 'Price', prefix: '€', rules: [BeakMin(0)],
  );
  static const List<BeakColumn> values = [name, price];
}
```

That one definition drives the table cell, the form input (with client-side
validation mirroring the server byte-for-byte), the detail row, the filter,
the REST validation, and the CSV export column.

## Packages

| Package | What it is |
|---------|------------|
| `packages/beak_core` | Pure Dart: typed columns + rules, relationships, the serializable `BeakQuerySpec` wire contract, storage abstraction + file rules, the `BeakDataSource` seam, and the raw `BeakClient` escape hatch |
| `packages/beak_backend` | Shelf server: generated CRUD/query/batch/relations/aggregate endpoints, validated uploads with image transforms, auth, global search, CSV export — all from a `BeakModelRegistry` over worm |
| `packages/beak_storage_s3` / `beak_storage_ftp` / `beak_image` | Pluggable storage drivers + the image transform runner |
| `packages/beak_frontend` | Flutter: `BeakPanel` (shell + router), generated tables/forms/detail/actions/filters/dashboard on obers_ui — HookWidget + Signals + GetIt + go_router |
| `packages/beak_cli` | Scaffolding: `beak make:resource` and friends, `beak doctor` |
| `apps/reference_admin*` | The reference admin (Products/Categories/Tags/Users/Orders) — shared models, server binary, Flutter panel, and the E2E acceptance suite |

## Quickstart

```bash
dart pub global activate --source path packages/beak_cli   # until Beak is published
beak create acme_admin
cd acme_admin && beak dev
```

That is the whole setup. `beak create` writes six files — a pubspec, a
`beak.yaml`, one example model, a `.gitignore`, analysis options, and an
`AGENTS.md` — and generates everything else.

## What a Beak project contains

```
acme_admin/
├── pubspec.yaml          one dependency line per Beak package
├── beak.yaml             optional: title, icons, sections, API origin
├── lib/
│   ├── models/           ← you write these
│   ├── screens/          ← optional custom pages
│   ├── {theme,auth,dashboard,server,panel}.dart   ← optional overrides
│   ├── beak/*.g.dart     generated wiring (committed)
│   └── main.dart         generated entrypoint (git-ignored)
└── bin/{serve,migrate}.dart                       generated (git-ignored)
```

Nothing needs registering. `beak prepare` — which every other command runs
first — discovers what you declare and writes the registry, the panel config,
the app widget, the server host, and the three entrypoints. The entrypoints sit
at their canonical paths so `flutter run`, `flutter build web`, IDE run buttons
and `dart compile exe` all work with no flags.

| Command | What it does |
| --- | --- |
| `beak create <name>` | Scaffold a project. |
| `beak dev` | Regenerate, then serve the API. |
| `beak prepare` | Regenerate the wiring only. |
| `beak migrate` / `beak seed` | Apply migrations / run seeders. |
| `beak doctor` | Diagnose the project. |

## Running the demos

The two example apps in this repo run the traditional way:

```bash
# 0. One-time: Dart ^3.11, Flutter stable, Docker, melos 6.3.3
dart pub global activate melos 6.3.3
melos bootstrap

# 1. Services (Postgres :25432, MinIO :29000 — see docker-compose.yml)
melos run up
cp .env.example .env

# 2. Schema + sample data
cd apps/reference_admin_server
dart run bin/worm.dart migrate
dart run bin/worm.dart db:seed

# 3. The backend (serves the generated API on :8080)
dart run bin/reference_admin_server.dart

# 4. The panel
cd ../reference_admin
flutter run -d chrome
```

## Defining a resource

1. **Columns + model** — a namespaced `XxxColumns` class of `const` column
   definitions and an `XxxModel extends BeakModel` naming the table, display
   column, and relationships. Drop it in `lib/models/`.
2. **Schema** — a worm migration in `lib/migrations/`. `BeakBlueprint.defineColumns`
   derives the DDL from the model, so a migration cannot drift from it.

That is it. Discovery finds both; the API, the panel pages, the filters and the
dashboard cards follow. `beak make:resource Widget --fields name:string,price:decimal`
scaffolds all of it.

## Storage drivers & file rules

Storage is configured at startup, never hard-wired: `BeakStorageConfig`
selects a driver (`memory` and `local` ship in core; `s3` and `ftp` plug in
via the driver packages — see `BEAK_STORAGE_DRIVER` in `.env.example`).
File rules live on the column, Filament-style, and are enforced on upload
(client-side too, for fast feedback):

```dart
static const image = BeakImageColumn(
  key: 'image', label: 'Image', storagePath: 'products',
  maxSizeInBytes: 5 * 1024 * 1024,
  allowedTypes: [BeakFileType.jpeg, BeakFileType.png, BeakFileType.webp],
  transforms: [
    BeakThumbnailTransform(size: BeakDimensions(widthInPixels: 160, heightInPixels: 160)),
    BeakFormatTransform.webp(),
  ],
);
```

The upload endpoint validates, runs the pipeline, stores via the configured
driver, and returns a typed `BeakStoredFile` with its variants.

## The `beak_serverpod` seam

`BeakDataSource` is an interface and `BeakModel` is ORM-neutral metadata —
worm never leaks into `beak_core`. A future `beak_serverpod` package will
implement `ServerpodDataSource` and adapt generated Serverpod classes as
Beak models **without changing beak_core or beak_backend**: supply the same
column/relationship metadata for your generated classes and hand Beak the
data source.

## Development

```bash
melos run analyze       # 0 issues, Material imports banned
melos run test          # all packages (unit + integration + e2e when services are up)
melos run coverage      # per-package thresholds (beak_core at 100%)
melos run format-check
```

The end-to-end acceptance suite
(`apps/reference_admin_server/test/e2e/full_flow_test.dart`) drives the real
server over HTTP with the real client against live Postgres + MinIO: paged
and searched queries with eager-loaded relations, validated creates, a real
PNG upload with a retrievable thumbnail variant, soft/force deletes, pivot
attach/detach, global search, CSV export, and aggregates.

## Documentation

The full documentation lives in [`docs/`](docs/) and is published as a
searchable site (MkDocs Material, deployed to GitHub Pages). Good places to start:

- [**Start here**](docs/start-here/index.md): what Beak is, why it exists, and a
  quickstart.
- [**Tutorial: First Flight**](docs/tutorial/index.md): build the reference store
  admin one concept at a time.
- [**Core concepts**](docs/concepts/index.md): the one-definition promise, the
  four layers, the block system.
- [**Reference**](docs/reference/index.md): every column, rule, block, config
  field, REST route, and CLI command, plus a [cheatsheet](docs/reference/cheatsheet.md).
- [**Architecture deep dive**](docs/architecture/index.md): the package graph,
  the layer flows, and the `BeakDataSource` seam.
- [**Deployment**](docs/deployment/index.md): the real Docker setup under
  [`deploy/`](deploy/).

Preview the site locally with
`pip install mkdocs-material mkdocs-minify-plugin && mkdocs serve`. Every public
API also carries dartdoc; run `dart doc` in any package to browse it.

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, the
four-command gate, and the code guardrails, and
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). Report vulnerabilities privately per
[SECURITY.md](SECURITY.md).

## License

[Apache-2.0](LICENSE) © Marqably GmbH.

---

*Built autonomously, test-first, by the Beak Build Kit (`PROMPT.md`,
`PLAN/`, `run_beak_build.sh`) — one green-gated phase per invocation; the
ledger with every phase's decisions lives in `PLAN/STATE.md`.*
