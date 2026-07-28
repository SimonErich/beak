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
@Resource(softDeletes: true, timestamps: true)
final class Product extends BeakSchema {
  /// What the product is called.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(255)])
  late final String name;

  /// Sale price in euros.
  @Column(prefix: '€', sortable: true, filterable: true, rules: [BeakMin(0)])
  late final double price;

  /// The category this product is filed under.
  @BelongsTo()
  late final Category? category;
}
```

The field's type picks the column kind; its nullability decides required-ness,
once, for the form validator, the API and the database alike. From that one
class `beak prepare` generates the typed columns, the model, both sides of
every relationship, a typed record view, the migration, and the wiring. Each
column then drives the table cell, the form input (validating exactly as the
server does), the detail row, the filter, the API's validation, and the CSV
column.

## Packages

| Package | What it is |
|---------|------------|
| `packages/beak_core` | Pure Dart: typed columns + rules, relationships, the serializable `BeakQuerySpec` wire contract, storage abstraction + file rules, the `BeakDataSource` seam, and the raw `BeakClient` escape hatch |
| `packages/beak_backend` | Shelf server: generated CRUD/query/batch/relations/aggregate endpoints, validated uploads with image transforms, auth, global search, CSV export — all from a `BeakModelRegistry` over worm |
| `packages/beak_storage_s3` / `beak_storage_ftp` / `beak_image` | Pluggable storage drivers + the image transform runner |
| `packages/beak_frontend` | Flutter: `BeakPanel` (shell + router), generated tables/forms/detail/actions/filters/dashboard on obers_ui — HookWidget + Signals + GetIt + go_router |
| `packages/beak_cli` | The `beak` command: `create`, `prepare`, `dev`, `introspect`, `eject`, `doctor`, `make:*` |
| `packages/beak_test` | `InMemoryBeakDataSource`, `BeakRecordingDataSource`, the data-source contract |
| `examples/quickstart` | Exactly what `beak create` produces, checked in |
| `examples/store` | The teaching example: every column kind, all four relationship kinds, auth with a row policy, uploads, a wizard, a dashboard |
| `examples/superdashboard` | 49 models at scale: 17 navigable resources, 37 block types, charts, maps |
| `examples/embedded` | Beak mounted inside an application that already exists |

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
│   ├── resources/        ← optional: <table>.dart adjusting one resource
│   ├── migrations/       generated once, then yours
│   ├── {theme,auth,dashboard,server,panel}.dart   ← optional overrides
│   ├── beak/*.g.dart     generated wiring (committed)
│   ├── models/*.beak.dart generated per model (committed)
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

## Running the examples

Each example is a single package that needs nothing but Dart and Flutter. The
database is a SQLite file created on first run.

```bash
# 0. One-time: Dart ^3.11, Flutter stable, melos 6.3.3
dart pub global activate melos 6.3.3
melos bootstrap

cd examples/store
dart run bin/migrate.dart migrate     # create the tables
dart run bin/migrate.dart db:seed     # a small, fixed catalog
beak dev                              # API on :8080, panel on :3000
```

Sign in as `ada@example.com` / `espresso` (staff) or `linus@example.com` /
`grinder` (a customer, who sees only their own orders). `examples/superdashboard`
runs the same way on port 8180. Postgres and MinIO (`melos run up`) are only
needed for the `e2e`-tagged suites.

## Defining a resource

One file: an `@Resource` class under `lib/models/`. `beak prepare` derives the
typed columns, the model, both sides of every relationship, a typed record
view, the migration and the wiring from it. Nothing is registered.

```bash
beak make:resource Widget --fields name:string!,price:decimal!
dart run bin/migrate.dart migrate
```

A resource's presentation (icon, label, section, or hiding it) is `beak.yaml`;
its filters, actions, view modes and layouts are `lib/resources/<table>.dart`,
scaffolded by `beak eject resource <table>`.

## Storage drivers & file rules

Storage is configured at startup, never hard-wired: `BeakStorageConfig`
selects a driver (`memory` and `local` ship in core; `s3` and `ftp` plug in
via the driver packages, registered by a `beakStorageRegistry()` in
`lib/server.dart`). The local driver's files are served by the Beak server
itself, so uploads work in development with nothing else running.
File rules live on the column, Filament-style, and are enforced on upload
(client-side too, for fast feedback):

```dart
@Image(
  storagePath: 'products',
  maxSizeInBytes: 5 * 1024 * 1024,
  allowedTypes: [BeakFileType.jpeg, BeakFileType.png, BeakFileType.webp],
  transforms: [
    BeakThumbnailTransform(
      size: BeakDimensions(widthInPixels: 160, heightInPixels: 160),
    ),
    BeakFormatTransform.webp(),
  ],
)
late final BeakImageRef? image;
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
melos run analyze       # 0 issues; Material imports, web-unsafe imports and
                        # stale docs all fail here
melos run test          # every package, e2e excluded
melos run test-e2e      # the service-backed suites (needs `melos run up`)
melos run coverage      # per-package thresholds (beak_core at 100%)
melos run format-check
```

The store's API assertions live once, in
[`examples/store/test/api_scenario.dart`](examples/store/test/api_scenario.dart),
and run twice: on `sqlite::memory:` with local-disk uploads on every push, and
against Postgres under `melos run test-e2e`. Between them they cover paged,
sorted and searched queries with eager-loaded relations, validated creates, a
real PNG upload with a retrievable thumbnail variant, soft delete with restore
and force delete, pivot attach/detach, global search, CSV export, aggregates,
optimistic concurrency, and the row policy.

## Documentation

The full documentation lives in [`docs/`](docs/) and is published as a
searchable site (MkDocs Material, deployed to GitHub Pages). Good places to start:

- [**Start here**](docs/start-here/index.md): what Beak is, why it exists, and a
  quickstart.
- [**Tutorial: First Flight**](docs/tutorial/index.md): build the store example
  one concept at a time.
- [**Core concepts**](docs/concepts/index.md): the one-definition promise, the
  four layers, the block system.
- [**Reference**](docs/reference/index.md): every column, rule, block, config
  field, REST route, and CLI command, plus a [cheatsheet](docs/reference/cheatsheet.md).
- [**Architecture deep dive**](docs/architecture/index.md): the package graph,
  the layer flows, and the `BeakDataSource` seam.
- [**Deployment**](docs/deployment/index.md): the real Docker setup under
  [`deploy/`](deploy/).

Preview the site locally with
`pip install mkdocs-material mkdocs-minify-plugin mkdocs-redirects && mkdocs serve`.
Every public API also carries dartdoc; run `dart doc` in any package to browse
it.

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, the
four-command gate, and the code guardrails, and
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). Report vulnerabilities privately per
[SECURITY.md](SECURITY.md).

## License

[Apache-2.0](LICENSE) © Marqably GmbH.
