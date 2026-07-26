---
title: Quickstart
description: Boot the reference admin end to end: migrate, seed, serve the generated API on port 8080, and open the Flutter panel.
---

# Quickstart

## The fastest path: a new project

If you want your *own* panel rather than a tour of this repo's demo, skip
straight to the CLI. It needs no Docker, no `.env`, and no monorepo:

```bash
dart pub global activate --source path packages/beak_cli
beak create acme_admin
cd acme_admin && beak dev
```

`beak create` writes six files you own — a pubspec, a `beak.yaml`, one example
model, a `.gitignore`, analysis options, and an `AGENTS.md` — and generates the
registry, the panel config, the app widget, the server host and the three
entrypoints. Add a `BeakModel` subclass under `lib/models/` and it appears in
the panel; there is nothing to register.

See [CLI commands](../reference/cli-commands.md) for the full surface.

The rest of this page runs the **reference admin** demo that ships in this
repository, which is what the tutorial and the feature pages refer to.


After this page you have the reference admin running on your machine: a Shelf
backend serving a generated API on port `8080`, seeded with sample data, and a
Flutter panel in Chrome talking to it. Roughly five minutes of copy-paste.

This page assumes you finished [Installation](installation.md): Melos `6.3.3`,
`melos bootstrap`, and the ability to run the
Docker services. It uses the **reference admin** (a small coffee-roastery store:
products, categories, tags, users, orders), whose server runs on port `8080`.

## 1. Start the services

From the repo root:

```bash
melos run up
```

Postgres comes up on `25432` and MinIO on `29000`, both waited-for and healthy,
with the `beak-uploads` bucket created. See
[Installation](installation.md#start-the-local-services) for the full port map.

## 2. Give the reference server its `.env`

The server binary and the worm CLI both read a `.env` from the directory you run
them in. Create one next to the reference server's `bin/`:

```bash title="apps/reference_admin_server/.env"
DATABASE_URL=postgres://beak:beak@localhost:25432/beak
BEAK_STORAGE_DRIVER=s3
BEAK_S3_ENDPOINT=http://localhost:29000
BEAK_S3_BUCKET=beak-uploads
BEAK_S3_ACCESS_KEY=beak
BEAK_S3_SECRET_KEY=beaksecret
BEAK_S3_REGION=us-east-1
BEAK_S3_USE_PATH_STYLE=true
```

!!! note "Why no `PORT` line here"
    The backend defaults to `8080` when `PORT` is unset, and the panel's default
    `apiBaseUrl` is `http://localhost:8080`. Leaving `PORT` out of this file is
    what keeps the two in agreement. (The repo-root `.env.example` sets
    `PORT=8180`, which is the *showcase* app's port, not this one.)

## 3. Migrate and seed the database

```bash
cd apps/reference_admin_server
dart run bin/worm.dart migrate
dart run bin/worm.dart db:seed
```

`bin/worm.dart` is the project-aware worm CLI: it registers the reference
migrations and seeder, then connects to the Postgres `DATABASE_URL` points at.

```dart title="apps/reference_admin_server/bin/worm.dart"
/// Run e.g. `dart run bin/worm.dart migrate` or
/// `dart run bin/worm.dart db:seed`.
Future<void> main(List<String> args) async {
  final config = BeakBackendConfig.fromEnv(environment: BeakEnv.resolve());
  final context = CliContext(
    // ...
    migrations: referenceMigrations,
    seeders: const [ReferenceSeeder()],
  );
  exit(await WormCommandRunner(context).run(args) ?? 0);
}
```

!!! note "What just happened"
    `migrate` created the tables for every reference model. `db:seed` filled them
    with sample products, categories, tags, users, and orders so the panel has
    something to show. Run them once; re-seeding is not needed on later boots.

## 4. Start the backend

Still in `apps/reference_admin_server`:

```bash
dart run bin/reference_admin_server.dart
```

The binary loads `.env`, connects worm to Postgres, resolves the storage driver,
and serves the generated API for every model:

```dart title="apps/reference_admin_server/bin/reference_admin_server.dart"
Future<void> main() async {
  final Map<String, String> environment = BeakEnv.resolve();
  final config = BeakBackendConfig.fromEnv(environment: environment);
  await initializeWormPostgres(config);
  final storageConfig = referenceStorageConfig(environment);
  final server = buildReferenceServer(
    config: config,
    adapter: Worm.adapter(),
    storage: storageConfig == null ? null : resolveStorage(storageConfig),
  );
  final HttpServer httpServer = await server.start();
  stderr.writeln(
    'reference_admin_server listening on '
    'http://${httpServer.address.host}:${httpServer.port}',
  );
}
```

You should see a line like:

```text
reference_admin_server listening on http://0.0.0.0:8080
```

Leave this terminal running and open a second one for the panel.

## 5. Run the panel

```bash
cd ../reference_admin
flutter run -d chrome
```

Chrome opens on the panel: a navigation shell with a page per resource
(list, detail, create, edit) and a dashboard. It is already pointed at the
backend you just started.

## The whole app is one `BeakPanel`

The reference app has no per-page code. Its `main.dart` builds a
`BeakPanelConfig` from the shared models and hands it to a `BeakPanel`. Trimmed
to its shape:

```dart title="apps/reference_admin/lib/main.dart"
import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:reference_admin_models/reference_admin_models.dart';

BeakPanelConfig buildReferencePanelConfig({
  String apiBaseUrl = 'http://localhost:8080',
}) => BeakPanelConfig(
  title: 'Beak Admin',
  apiBaseUrl: apiBaseUrl,
  resources: const [
    BeakResource(
      model: ProductModel(),
      icon: BeakIconToken(OiIcons.package),
    ),
    BeakResource(
      model: CategoryModel(),
      icon: BeakIconToken(OiIcons.folderTree),
    ),
    // ... Tag, User, Order, OrderItem, plus filters, actions,
    // dashboardStats, and dashboardCharts.
  ],
);

/// The reference admin app: one [BeakPanel] over the shared models.
final class ReferenceAdminApp extends StatelessWidget {
  /// Creates the app; [dataSource] injects a fake in widget tests.
  const ReferenceAdminApp({this.dataSource, super.key});

  /// Test seam replacing the HTTP-backed data source.
  final BeakDataSource? dataSource;

  @override
  Widget build(BuildContext context) =>
      BeakPanel(config: buildReferencePanelConfig(), dataSource: dataSource);
}

/// Boots the Flutter reference admin against the default local backend.
void main() => runApp(const ReferenceAdminApp());
```

That is the entire entry point. There is no `package:flutter/material.dart` in
sight: `BeakPanel` renders the shell, the tables, the forms, and the detail
views on obers_ui. The `apiBaseUrl` default (`http://localhost:8080`) is why the
panel found the backend without any wiring.

!!! note "What just happened"
    Each `BeakResource` names a shared model and an icon. From that, Beak
    generated a list page, a detail page, a create form, and an edit form, all
    validated against the same column definitions the server enforces. The
    dashboard, filters, and row actions in the real file are more of the same
    config.

## Where to go next

You just ran a panel someone else configured. To build your own from an empty
folder, one concept at a time, work through the tutorial. It uses this same
reference store, so the models and ports match what you saw here.

## Continue reading

- [Tutorial: First Flight](../tutorial/index.md) build the coffee-roastery admin
  from scratch, ten short chapters.
- [Hatch the project](../tutorial/01-hatch-the-project.md) the tutorial's first
  chapter: the server, the models package, and the panel.
- [Project structure](project-structure.md) what each folder you just touched is
  for.
- [Resources](../panel/resources.md) the `BeakResource` config that turns a model
  into pages.
