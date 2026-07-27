---
title: 3. The panel comes alive
description: Serve the categories model through a generated backend on port 8080 and open a working list, create, show, and edit panel in Chrome.
---

# 3. The panel comes alive

By the end of this chapter the one model from Chapter 2 is a running admin: a
Shelf backend serving a generated REST API on port 8080, and a Flutter panel in
Chrome that lists categories, creates them, shows them, and edits them. You will
not write a single endpoint or a single page. Both come from the model you
already have.

This is the moment the egg cracks.

## The backend is generated

The server does not have per-resource handlers. `buildReferenceServer` takes the
model registry, wraps it in a `WormDataSource` (the worm-backed implementation of
Beak's data-source interface), and hands both to a `BeakServer`, which mounts the
full CRUD API for every registered model.

```dart title="examples/store/lib/server.dart"
BeakServer buildReferenceServer({
  required BeakBackendConfig config,
  required DatabaseAdapter adapter,
  BeakStorageDriver? storage,
}) {
  final BeakModelRegistry registry = buildBeakRegistry();
  return BeakServer(
    config: config,
    registry: registry,
    dataSource: WormDataSource(registry, adapter: adapter),
    storage: storage,
  );
}
```

That registry is the same `buildBeakRegistry()` you registered
`CategoryModel` in. Every model in it gets a set of routes: list, read, create,
update, delete. The `WormDataSource` is the only thing that knows about worm or
Postgres; nothing above it does, which is the seam that lets a different backing
store slot in later.

The `bin/` entry point loads `.env`, connects worm to Postgres, resolves the
storage driver, and starts the server:

```dart title="examples/store/bin/serve.dart"
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
    'store listening on '
    'http://${httpServer.address.host}:${httpServer.port}',
  );
}
```

Start it from the server folder, with the services from Chapter 1 still up:

```bash
cd examples/store
dart run bin/store.dart
```

You should see the listen line, on port `8080`:

```text
store listening on http://0.0.0.0:8080
```

Leave this terminal running. The backend is live. Open a second terminal for the
panel.

## The panel is configuration

The Flutter app has no page code either. Its `main.dart` builds a
`BeakPanelConfig` and hands it to a `BeakPanel`. A `BeakResource` names a model
and an icon; from that, Beak renders the list page, the detail page, the create
form, and the edit form. For now the panel has one resource, `CategoryModel`:

```dart
import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';
import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:store/store.dart';

BeakPanelConfig buildReferencePanelConfig({
  String apiBaseUrl = 'http://localhost:8080',
}) => BeakPanelConfig(
  title: 'Beak Admin',
  apiBaseUrl: apiBaseUrl,
  resources: const [
    BeakResource(
      model: CategoryModel(),
      icon: BeakIconToken(OiIcons.folderTree),
    ),
  ],
);

/// The store example app: one [BeakPanel] over the shared models.
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

A few things are load-bearing here.

- **`apiBaseUrl` defaults to `http://localhost:8080`.** That is why the panel
  finds the backend you just started with no extra wiring, and why Chapter 1 left
  `PORT` out of the server's `.env`.
- **`BeakResource(model, icon)`** is the entire declaration for a resource. The
  `icon` is a `BeakIconToken` over an `obers_ui` icon; `folderTree` suits a
  category tree.
- **There is no `package:flutter/material.dart` anywhere.** `BeakPanel` renders
  the navigation shell, the table, the detail view, and the form on `obers_ui`.
  The `dataSource` parameter is a test seam that stays `null` in the real app,
  where the panel talks to the server over HTTP.

## Run the panel

From a second terminal:

```bash
cd examples/store
flutter run -d chrome
```

Flutter builds the web app and opens Chrome:

```text
Launching lib/main.dart on Chrome in debug mode...
This app is linked to the debug service...
Debug service listening on ws://127.0.0.1:.../ws
```

Chrome opens on the panel: a navigation shell with a single **Categories** entry
in the rail. Click it and you land on an empty table (the `categories` table has
no rows yet). Click **Create**, and the form Beak generated from
`CategoryColumns` appears: a single **Name** field that refuses to submit empty
or longer than 120 characters, exactly the `BeakRequired()` and
`BeakMaxLength(120)` rules you declared. Type `Single Origin` and save.

The row appears in the table. Click it to open the detail view, which now also
shows the `Id` column (the one marked `visibleOn: {BeakContext.detail}`). Hit
**Edit**, change the name, and save again. Create, read, update, delete, all from
one `BeakResource`.

!!! note "What just happened"
    - `buildReferenceServer` mounted a full CRUD API for every registered model.
      With one model registered, that is the `categories` routes, served on
      `8080`.
    - `buildReferencePanelConfig` declared one `BeakResource`, and `BeakPanel`
      turned it into a list page, a detail page, and create and edit forms.
    - The form validated your input against the same column rules the server
      enforces, because both read the one `CategoryColumns` definition.
    - You created, read, and edited a category through a panel nobody wrote page
      code for.

One model, one resource, a whole CRUD panel. The next chapter is where the store
gets interesting: tags, then a rich `ProductModel` with an enum status, a euro
price, an image upload, and relationships to both.

## Continue reading

- [4. Relationships and rich columns](04-relationships-and-rich-columns.md) add
  tags and a full product model.
- [Resources](../panel/resources.md) everything a `BeakResource` configures.
- [Running the server](../backend/running-the-server.md) how `BeakServer` boots
  and binds.
- [The generated API](../backend/the-generated-api.md) the routes Beak mounts for
  each model.
