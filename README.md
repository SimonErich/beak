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

## Configure the screen, let Beak run it

Register resources directly; each resource owns navigation, search, and optional
screen layouts. Omit a layout to derive the table and form from the model.

```dart
void main() => runApp(BeakPanel(
  resources: [OrderResource(), UserResource()],
));
```

Generated model fields are typed configuration values:
`OrderModel.customer.inputCombobox()`,
`OrderItemModel.quantity.inputNumber()`, and
`OrderModel.customer.email`. One `BeakFormScreen` layout can serve read, create,
and edit; `BeakWizardScreen` presents the same draft runtime in steps.
Relationship edits remain local until Finish, with atomic Shelf/Worm graph
saving and explicit recovery for sources that save in stages.

Start with [examples/clean_beak_config](examples/clean_beak_config) and the
[declarative resource guide](docs/concepts/declarative-resources.md).

## Packages

| Package | What it is |
|---------|------------|
| `packages/beak_core` | Pure Dart: typed columns + rules, relationships, the serializable `BeakQuerySpec` wire contract, storage abstraction + file rules, the `BeakDataSource` seam, and the raw `BeakClient` escape hatch |
| `packages/beak_backend` | Shelf server: generated CRUD/query/batch/relations/aggregate endpoints, validated uploads with image transforms, auth, global search, CSV export — all from a `BeakModelRegistry` over worm |
| `packages/beak_storage_s3` / `beak_storage_ftp` / `beak_image` | Pluggable storage drivers + the image transform runner |
| `packages/beak_frontend` | Flutter: `BeakPanel` (shell + router), generated tables/forms/detail/actions/filters/dashboard on obers_ui — HookWidget + Signals + GetIt + go_router |
| `packages/beak_cli` | The `beak` command: `create`, `prepare`, `dev`, `introspect`, `eject`, `doctor`, `make:*` |
| `packages/beak_test` | `InMemoryBeakDataSource`, `BeakRecordingDataSource`, the data-source contract |
| `examples/clean_beak_config` | Canonical shop: declarative forms, named invoice actions, custom dashboard/operations widgets, variants, imports, semantic fields and staged graph saving |
| `examples/foodio-adminpanel` | Gabel food-ordering admin: 48,213 persisted demo orders, catalog wizard, operational charts, budgets, capacity, invoice snapshots and durable demo effects |
| `examples/quickstart` | Exactly what `beak create` produces, checked in |

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
│   └── main.dart         your BeakPanel, or a generated default
└── bin/{serve,migrate}.dart                       generated (git-ignored)
```

Schema and host wiring need no manual registry. `beak prepare` — which every other command runs
first — discovers schemas throughout `lib/` and writes the registry, the panel config,
the app widget, the server host, and the three entrypoints. The entrypoints sit
at their canonical paths so `flutter run`, `flutter build web`, IDE run buttons
and `dart compile exe` all work with no flags. Authored entrypoints are preserved
by generation; commit your own `main.dart` when it contains resource configuration.

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

cd examples/clean_beak_config
dart run ../../packages/beak_cli/bin/beak.dart prepare
dart run bin/migrate.dart migrate     # create the tables
dart run bin/migrate.dart db:seed     # a small, fixed catalog
dart run bin/serve.dart               # API on :8080
# In a second terminal:
flutter run -d chrome --web-port=3000
```

The canonical shop is an unauthenticated local demo. Its repeatable seed preserves
existing records; migrations upgrade the schema without resetting the database.
`examples/quickstart` remains the minimal generated project. PostgreSQL and object
storage services are needed only for the corresponding service-backed tests.

The [Gabel Foodio admin](examples/foodio-adminpanel/README.md) is a second complete
application, preserving the food-ordering prototype’s branding. It runs its API
on port 8081, alongside the canonical shop, and uses real seeded records for
operational counts, a catalog order wizard, company budgets, delivery capacity
and persistent demo payment/message effects. Its [domain contract](examples/foodio-adminpanel/DOMAIN.md)
documents the exact fixture figures and transactional rules. Both examples use
the same declarative Beak configuration APIs.

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

## Existing Serverpod projects

[`beak_serverpod`](packages/beak_serverpod/README.md) adapts existing typed
Serverpod models and client calls to Beak. Select read models in
[`beak_serverpod_generator`](packages/beak_serverpod_generator/README.md), then
configure the generated resource's columns, labels, permissions and exceptional
operations. Endpoint discovery generates supported CRUD/query transport and
command form metadata. The panel discovers each model's data source automatically;
standard resources need no application repository or binding registry.

Serverpod remains responsible for authentication, authorization, persistence and
domain commands. Neither Beak's Worm backend nor a duplicate entity model sits
between the panel and those operations. Framework auth screens consume the
[`beak_serverpod_flutter`](packages/beak_serverpod_flutter/README.md) auth adapter
separately from resource transport. That adapter reuses the existing authenticated
client/session; generating a model does not provision accounts or authorize access.

The same [model transport and permission contract](docs/extending/model-transports.md)
serves standalone Worm models, generated Serverpod resources and custom sources.
See the generator guide for exact endpoint conventions and typed escape hatches.

## Development

```bash
melos run analyze       # 0 issues; Material imports, web-unsafe imports and
                        # stale docs all fail here
melos run test          # every package, e2e excluded
melos run test-e2e      # the service-backed suites (needs `melos run up`)
melos run coverage      # per-package thresholds (beak_core at 100%)
melos run format-check
```

The canonical shop's [API tests](examples/clean_beak_config/test/shop_api_test.dart)
exercise real SQLite graph saves, rollback, named actions, snapshot immutability,
relationship search and variant uniqueness. Its [custom-widget tests](examples/clean_beak_config/test/custom_shop_test.dart)
cover shared refresh, explicit errors and staged combination generation. Framework
packages cover transport contracts, policies, uploads and the optional
service-backed database/storage integrations.

## Documentation

The full documentation lives in [`docs/`](docs/) and is published as a
searchable site (MkDocs Material, deployed to GitHub Pages). Good places to start:

- [**Start here**](docs/index.md): what Beak is, why it exists, and a
  quickstart.
- [**Tutorial: First Flight**](docs/tutorial/index.md): build the store example
  one concept at a time.
- [**Core concepts**](docs/concepts/index.md): the one-definition promise, the
  four layers, the block system.
- [**Reference**](docs/reference/index.md): every column, rule, block, config
  field, REST route, and CLI command, plus a [cheatsheet](docs/reference/cheatsheet.md).
- [**Architecture deep dive**](docs/architecture/index.md): the package graph,
  the layer flows, and the `BeakDataSource` seam.
- [**Deployment**](docs/shipping/index.md): the real Docker setup under
  [`deploy/`](deploy/).

Preview the site locally with
`pip install -r docs/requirements.txt && mkdocs serve`.
Every public API also carries dartdoc; run `dart doc` in any package to browse
it.

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, the
four-command gate, and the code guardrails, and
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). Report vulnerabilities privately per
[SECURITY.md](SECURITY.md).

## License

[Apache-2.0](LICENSE) © Marqably GmbH.
