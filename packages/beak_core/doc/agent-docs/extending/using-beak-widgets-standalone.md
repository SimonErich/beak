# Using Beak widgets standalone

> Add the panel to an existing Flutter app with beak init, mount its routes in your own router, or drop a Beak form, table or block into a screen of yours.

After this page you can put Beak in an app that already exists: as a second entrypoint that boots the panel, as routes inside your own router, or as a single form, table or block on a screen you wrote.

The panel is Beak's default host, not its only one. Every piece it is made of (a configured form, a data table, a block tree) is a public widget that takes a model and a data source. The cost of using one alone is that you provide what the panel would have provided, and this page lists what that is.

## At a glance

| Level | You get | You provide | Section |
| --- | --- | --- | --- |
| A second entrypoint | The whole panel, booted from a file next to your `main.dart` | `beak init`, then a `flutter run -t` | [Add the panel](#add-the-panel-as-a-second-entrypoint) |
| Panel routes in your router | The same pages under your `GoRouter`, your sign-in, your app widget | `registerBeakDependencies`, `beakPanelRoutes(config)`, `OiApp.router` | [Mount the routes](#mount-the-panel-in-your-router) |
| One widget | A form, table or block on a screen of yours | An `OiApp` root, a model and a data source | [Use one widget](#use-one-widget-on-its-own) |

Beak's widgets are `Oi*` widgets, so they read the obers_ui theme, overlay and density scopes that `OiApp` (or `OiApp.router`) injects. A host on `MaterialApp` needs an `OiApp` at or above the point where a Beak widget appears. Beak's own tests always pump them inside `OiApp`. Import `package:beak/panel.dart` for Beak and `package:beak/ui.dart` for the `Oi*` controls.

## Add the panel as a second entrypoint

An app that exists cannot give up `lib/main.dart`, so `beak init` puts the panel next to it. It adds the `beak` dependency, writes a `beak.yaml` that records where the panel boots from, writes an authored entrypoint, and adds a block to `.gitignore` for what Beak generates. Your own files are never rewritten. Run it in the root of the Flutter app:

```console
$ beak init --example
  updated pubspec.yaml (added the beak dependency)
  created beak.yaml
  created lib/admin_main.dart
  created lib/resources/notes/models/note.dart
  created lib/resources/notes/note_resource.dart
  created .gitignore
  1 model · 1 resource class · screens and overrides not applicable (lib/admin_main.dart is authored)
  generated  6 of 6 files
  agents     AGENTS.md created · CLAUDE.md created · docs Beak 0.9.0, .dart_tool/beak/docs/ai-index.md

  next:
    beak make:resource Product --fields name:string!
    beak dev
    flutter run -d chrome -t lib/admin_main.dart
```

`--example` also writes a first `Note` schema class and resource. The default entrypoint is `lib/main.dart` when the app has none of its own and `lib/admin_main.dart` otherwise. `--entrypoint <path>` picks another file, which must sit directly under `lib/`.

| File | What it holds |
| --- | --- |
| `beak.yaml` | A `panel.entrypoint` key naming the file. While it is set, `beak prepare` does not write or compare your `lib/main.dart`. |
| `lib/admin_main.dart` | An authored `BeakPanel(resources: [...])`. It is yours, and `beak prepare` never rewrites it. |
| `.gitignore` | A `# BEGIN beak` block for the generated `bin/` entrypoints, the local database, uploads and `.env`. |

```yaml title="beak.yaml"
# Beak project configuration. Every key is optional: delete this file and
# Beak still boots, titling the panel after the package.
name: Host App

api:
  # The origin the panel calls. Use `auto` to call the origin the panel was
  # served from, which is what a single-host deployment wants.
  baseUrl: http://localhost:8080

panel:
  # This app keeps its own lib/main.dart, so `beak prepare` never writes it.
  # The panel boots from this file instead: flutter run -t lib/admin_main.dart
  entrypoint: lib/admin_main.dart
```

```dart title="lib/admin_main.dart"
import 'package:beak/panel.dart';
import 'package:flutter/widgets.dart';

import 'resources/notes/note_resource.dart';

/// Boots the panel.
void main() => runApp(buildPanel());

/// The panel, and every resource it shows.
///
/// This file is yours: `beak prepare` never rewrites it, so add each
/// resource class you write to `resources`.
///
/// [dataSource] replaces the HTTP-backed source, so a widget test
/// can pump this exact panel against an in-memory one.
BeakPanel buildPanel({BeakDataSource? dataSource}) => BeakPanel(
  title: 'Host App',
  resources: [const NoteResource()],
  dataSource: dataSource,
);
```

Add each new resource to the `resources` list yourself: `beak make:resource` prints a reminder that the file is yours. `beak init` is safe to run twice. It repairs what is missing and writes nothing else.

`beak init` refuses two projects. A pubspec without `flutter: sdk: flutter` is not a Flutter app, and a project inside a Serverpod workspace belongs to the admin app path instead, described under [Serverpod](../serverpod/choosing-an-integration.md).

## Mount the panel in your router

The second level is for an app that wants the panel's pages inside its own navigation: same `GoRouter`, same sign-in, same `OiApp`. You register Beak's dependencies once, then hand the router the panel's routes.

```dart title="packages/beak_frontend/test/src/panel/beak_panel_test.dart"
registerBeakDependencies(config: config, dataSource: FakeDataSource());
final router = GoRouter(
  initialLocation: '/notes',
  routes: [
    GoRoute(
      path: '/sign-in',
      builder: (_, _) => const Text('Host login'),
    ),
    ShellRoute(
      redirect: (_, _) => '/sign-in',
      builder: (_, _, child) => child,
      routes: beakPanelRoutes(config),
    ),
  ],
);
addTearDown(router.dispose);
await tester.pumpWidget(OiApp.router(routerConfig: router));
```

`config` is a `BeakPanelConfig`, the same object `BeakPanel` builds from its arguments. In this test the host router redirects everything under the shell to `/sign-in`, so the panel's pages never render for a guest. That is the point: the host owns authentication and the app root, and no second router or auth route is created.

| Piece | Owner | Detail |
| --- | --- | --- |
| `registerBeakDependencies(config: ...)` | You, once, before the router | Registers the model registry, the data source, the client and the session store into the global `beakLocator`. Pass `locator:` for a container of your own, and mount `BeakDependencyScope(container: ...)` above the routes. |
| `beakPanelRoutes(config)` | You, inside your router | A shell route with the panel chrome and the list, create, show and edit routes of every resource, plus your `pages`. |
| Sign-in | You | The routes include no login page. Guard the shell with your own `redirect`, as above. |
| Session | You | Pass `externalAuthentication: true`, or set `BeakPanelConfig.auth` to a `BeakAuthConfig(adapter: ...)`, and Beak creates no HTTP client or session store. Then every model needs a bound `dataSource`, or you pass one to `registerBeakDependencies`. |

Panel routes are absolute paths (`/notes`, `/notes/create`, `/notes/:id`, `/notes/:id/edit`), and there is no path prefix option. They take the top level of your router, so a resource named like one of your own routes collides with it.

## Use one widget on its own

A single widget needs the least. Three of them cover most embedding.

### A form

`BeakConfiguredForm` accepts a model, a data source and, optionally, a registry, a record id, a presentation mode and a layout or wizard steps. It owns fetching, the local graph, validation, save, cancel and receipt recovery.

```dart title="examples/clean_beak_config/test/shop_widget_test.dart"
await tester.pumpWidget(
  BeakFormattingScope(
    formatting: const BeakFormatting(locale: 'de_AT', currency: 'EUR'),
    child: OiApp(
      theme: OiThemeData.light(),
      home: BeakConfiguredForm(
        model: const FulfillmentPolicyModel(),
        registry: registry,
        dataSource: InMemoryBeakDataSource(registry: registry),
        mode: BeakFormMode.create,
        layout: fulfillmentPolicyForm(),
        onSession: (value) => session = value,
      ),
    ),
  ),
);
```

| Parameter | Meaning |
| --- | --- |
| `model`, `dataSource` | Required. The metadata and the transport. |
| `registry` | The generated `buildBeakRegistry()`. Pass it whenever the model has relationships, so related drafts and references resolve. |
| `mode` | `BeakFormMode.read`, `create` or `edit`. Defaults to `edit`, so pass `create` for a new record. |
| `recordId` | The record to load for `read` and `edit`. |
| `layout`, `steps` | A `BeakFormLayout`, or `BeakWizardStep`s for a wizard. Empty means the model's default layout. |
| `onSaved`, `onClose` | Called after every operation is confirmed applied, and to leave. |
| `onSession` | Hands you the `BeakFormSession`, for tests and for reading the draft. |
| `valueMode` | `populated` (default), `complete` or `changes`. See [Model-owned transports](model-transports.md). |

The `BeakFormattingScope` around it in the example makes an embedded form and the panel's own widgets show money, dates and numbers the same way.

### A table

`BeakDataTable` lists a model's table-context columns with server-side sort, filter and pagination, per-row and bulk actions, and the same cell renderers as the panel (custom columns included):

```dart
BeakDataTable(
  model: const ProductModel(),
  dataSource: dataSource,
  onRowTap: (record) => context.go('/products/${record['id']?.raw}'),
)
```

That block is illustrative, adapted from the class documentation of `BeakDataTable` in `packages/beak_frontend/lib/src/table/beak_data_table.dart`, and `ProductModel` stands for one of your generated models. The table takes its source as a parameter, like the form.

### A block

Blocks are different: `BeakBlockHost` renders a `BeakBlock` tree, and the data blocks (metrics, tables, summaries) resolve their source through the dependency container, not a parameter. So a block needs `registerBeakDependencies` first:

```dart title="packages/beak_frontend/test/src/blocks/beak_metric_block_test.dart"
registerBeakDependencies(
  config: const BeakPanelConfig(
    title: 'Demo',
    apiBaseUrl: 'http://localhost',
    resources: [
      BeakResource(model: NoteModel(), icon: BeakIconToken(OiIcons.file)),
      BeakResource(
        model: ArticleModel(),
        icon: BeakIconToken(OiIcons.newspaper),
      ),
    ],
  ),
  dataSource: dataSource,
);
```

```dart title="packages/beak_frontend/test/src/blocks/beak_metric_block_test.dart"
await tester.pumpWidget(
  OiApp(
    theme: OiThemeData.light(),
    home: BeakBlockHost(block: block),
  ),
);
```

In production, leave out `dataSource:` and the registration builds the HTTP-backed source for `config.apiBaseUrl`. The test passes a fake so no request is made.

## Rules and limits

| Rule | Enforced where | What it means |
| --- | --- | --- |
| An obers_ui root is required | Client | `Oi*` widgets assert on a missing `OiTheme`. Use `OiApp` or `OiApp.router` as the root. |
| Blocks need the container, forms and tables do not | Client | `BeakBlockHost` and custom widgets read `beakDependencies(context)`, which falls back to the global `beakLocator`. If nothing registered it, the lookup throws. |
| Refresh after a write needs the panel's source | Client | `useBeakDataRevision` reacts only to a source that implements `BeakMutationSource`, and only the panel's routing source does. A source you construct and pass straight to a form or table saves fine, but sibling widgets do not refresh. Resolve it with `beakDependencies(context)<BeakDataSource>()` when they should. |
| Server rules need a server | Server | Model behavior and record rules run in the form, and the server re-runs them when the save arrives through the commit route. A source without `BeakCommitDataSource`, such as `InMemoryBeakDataSource`, saves through the staged fallback: no server to re-run the rules, no atomic graph. |
| Routes are absolute | Client | `beakPanelRoutes` cannot be nested under a path prefix. |
| Do not build a second client | You | A second `BeakClient` has its own identity and cache lifetime. Resolve the panel's source instead. |
| Localization falls back safely | Client | Without a `BeakLocalizations.delegate` the widgets follow the ambient locale, English and German only. Install the delegate for a host that lists its own. |

## Verify it

Pump the widget the way Beak does: inside `OiApp`, over `InMemoryBeakDataSource` for presentation, filtering and draft tests (`package:beak/testing.dart`). When the test must see the server's lifecycle (behavior, actions, receipts), run the form through `HttpBeakDataSource` into the real API, as the shop's `test/order_form_test.dart` does with a SQLite-backed server.

```console
$ cd packages/beak_frontend
$ flutter test test/src/panel/beak_panel_test.dart --plain-name "host router owns authentication"
00:00 +0: generated routes host router owns authentication and the app root
00:00 +1: All tests passed!
$ flutter test test/src/blocks/beak_metric_block_test.dart
00:00 +23: All tests passed!
```

For the second-entrypoint route, `beak doctor` checks that the entrypoint lists every resource class and that the generated files are current:

```console
$ beak doctor
  OK   project depends on Beak
  OK   beak.yaml parses
  OK   discovered 1 model · 1 resource class · screens and overrides not applicable (lib/admin_main.dart is authored)
  OK   lib/admin_main.dart lists every resource class
  OK   generated files up to date
  ...
All checks passed.
```

Then `flutter run -d chrome -t lib/admin_main.dart` boots the panel.

## Reference

| Symbol | Library | Role |
| --- | --- | --- |
| `BeakConfiguredForm` | `package:beak/panel.dart` | Form, detail view and wizard host with loading, validation and saving. |
| `BeakDataTable` | `package:beak/panel.dart` | The generated list view. |
| `BeakBlockHost` | `package:beak/panel.dart` | Renders a `BeakBlock` tree onto obers_ui widgets. |
| `BeakFormattingScope`, `BeakFormatting` | `package:beak/panel.dart` | Shared display policy. |
| `registerBeakDependencies`, `beakLocator`, `beakDependencies`, `BeakDependencyScope` | `package:beak/panel.dart` | The dependency container and its lookup. |
| `beakPanelRoutes(config)` | `package:beak/panel.dart` | The panel's routes for a host router. |
| `BeakPanelConfig`, `BeakAuthConfig` | `package:beak/panel.dart` | The panel's configuration and its auth options. |
| `beak init` | `beak_cli` | `[--entrypoint <path>] [--beak-ref <ref> \| --beak-path <dir>] [--example] [--[no-]pub] [--dry-run]`. |

Sources: `packages/beak_frontend/lib/src/panel/beak_router.dart`, `packages/beak_frontend/lib/src/di/beak_locator.dart`, `packages/beak_frontend/lib/src/form/beak_configured_form.dart`, `packages/beak_cli/lib/src/commands/init_command.dart`.

## Continue reading

- [An existing Flutter app](../start-here/paths/existing-flutter-app.md) the whole path: sharing the session and running the API.
- [Custom blocks and widgets](custom-blocks-and-widgets.md) widgets that read the panel's dependencies from inside it.
- [Testing](../shipping/testing.md) the in-memory source, the recording decorator and the widget test setup.
- [Two ways to boot a panel](../start-here/generated-or-authored.md) the authored entrypoint `beak init` writes, and its generated twin.
