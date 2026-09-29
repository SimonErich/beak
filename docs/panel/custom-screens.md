---
title: Custom screens
description: Add a page that belongs to no resource, replace one route of a resource with your own widget, and embed a widget in a page of blocks.
type: guide
audience: [beginner, expert]
status: stable
---

# Custom screens

A resource gives you four routes. Some pages belong to no resource (an overview, a work queue), and sometimes one route of a resource needs a page Beak cannot derive. There are two tools for that, and a third for the widget that fits neither.

## At a glance

| You want | Use | Route | Sidebar entry |
| --- | --- | --- | --- |
| A page that belongs to no resource | `BeakScreen`, registered in `pages:` (authored panel) or declared under `lib/screens/` (generated panel) | Its own `path` | Yes, unless `showInNav: false` |
| One route of a resource to show your widget | `BeakCustomResourceScreen` in the resource's `screens` | The resource's own route | The resource's |
| A widget inside a page of blocks | `BeakWidgetBlock` | None | None |
| A widget inside a form | `BeakFormWidget`, see [Form screens](../forms/form-screens.md) | None | None |

A widget is the quickest way to get one odd page done, and it costs what the declarative path gives for free: the block types, the startup checks and the shared look. Try blocks first. A `BeakScreen` made of blocks is a tree of constants, a widget is code you maintain.

## A screen made of blocks

A `BeakScreen` has a route, a title, an icon and a body. The body is one `BeakBlock`, usually a column of others. The shop's operations page is a real one: a text block, a widget block, two tables in sections and a CSV import.

```dart title="examples/clean_beak_config/lib/operations.dart"
--8<-- "examples/clean_beak_config/lib/operations.dart:shopOperations"
```

| Parameter | Default | Meaning |
| --- | --- | --- |
| `path` | required | The route, such as `'/operations'`. `'/'` makes it the landing page (see [Dashboards](dashboards.md)) |
| `title` | required | The heading of the framed page, and the sidebar title unless `navigationTitle` is set |
| `icon` | required | A `BeakIconToken` for the sidebar |
| `body` | required | The `BeakBlock` that is the page |
| `navigationTitle` | `title` | A shorter sidebar label |
| `navigationGroup` | none | The sidebar heading the entry is filed under |
| `showInNav` | `true` | `false` keeps the route and drops the sidebar entry, for pages reached only by a link |
| `framed` | `true` | Wraps the body in the page header, gutters and scrolling |

A framed screen adds a heading and 32 pixels of side gutter, and no card behind the body: cards, charts and tables bring their own surface, and `BeakCardBlock` puts a group on a shared one. An unframed screen (`framed: false`) renders the body full-bleed and owns the whole viewport, which is what a board or a calendar wants:

```dart title="examples/showcase/lib/pages/data_blocks.dart"
--8<-- "examples/showcase/lib/pages/data_blocks.dart:plannerPage"
```

Foodio's kitchen page shows the same shape with a grouped summary. It sits in the Orders section of the custom navigation and is filed under `navigationGroup: 'Orders'`:

```dart title="examples/foodio-adminpanel/lib/pages/operations.dart"
final BeakScreen kitchenScreen = BeakScreen(
  path: '/kitchen',
  title: 'Kitchen summary',
  navigationGroup: 'Orders',
  icon: const BeakIconToken(OiIcons.clipboardList),
  body: BeakColumnBlock(
    gapInPixels: 24,
    children: [
      const BeakTextBlock('Today’s preparation list · Changes close at 10:30'),
      BeakSummaryBlock(
// ...
```

Block types, queries and summaries are in [Blocks](../blocks/index.md).

### Register it

The authored panel takes a list. Order is sidebar order:

```dart title="examples/clean_beak_config/lib/main.dart"
pages: [shopOverview(), shopOperations()],
```

The generated panel finds screens for you. `beak prepare` scans `lib/screens/` (subfolders included, files starting with `_` and `*.g.dart` skipped) and writes what it finds into the `pages:` of `lib/beak/panel.g.dart`, in import-path order. A screen is either:

- a top-level `BeakScreen` variable, typed `BeakScreen` or initialised with `BeakScreen(...)`, or
- a function returning `BeakScreen` that takes no required arguments.

A function with required arguments is reported as a problem and skipped. A variable whose initializer is a call to something other than the `BeakScreen` constructor, `final x = buildScreen()`, is not seen at all, so annotate it. A screen is only as visible as its sidebar: with a `BeakNavigation` in play, a screen appears only in a section that lists it with `BeakNavigationItem.screen`, see [Navigation](navigation.md).

## Replace one route of a resource

A `BeakCustomResourceScreen` takes over one or more routes of a resource and builds whatever you like. The route, the redirect to `/403` for an account that may not read it, and the sidebar entry stay with the resource. The showcase's keepers list uses the generated table and swaps only the read route:

```dart title="examples/showcase/lib/resources/keepers/keeper_resource.dart"
screens: [
  BeakTableScreen(
    fields: [KeeperModel.name, KeeperModel.email, KeeperModel.role],
  ),
  BeakCustomResourceScreen(
    roles: const {BeakScreenRole.read},
    builder: (context, recordId) => KeeperSheet(recordId: recordId),
  ),
],
```

`builder` gets the `BuildContext` and the record id: `null` on the list and create routes, the value from the URL on read and edit. It arrives as the path segment, a `String`, so an integer key needs `int.parse` before it goes anywhere typed. Loading the record and handing it to blocks is your code:

```dart title="examples/showcase/lib/resources/keepers/keeper_sheet.dart"
--8<-- "examples/showcase/lib/resources/keepers/keeper_sheet.dart:recordScopeHandOff"
```

`BeakRecordScope` is how record blocks (`BeakFieldBlock`, `BeakRelationBlock`) find their record; no built-in page mounts one, so a custom read screen does it itself.

What you take on when you replace a route:

- The generated page frame is gone: no title, Back button or record actions. The keepers sheet builds its own `OiPageLayout`. The sidebar and header of the shell stay.
- A custom `create` or `edit` screen makes that route available even if the model does not expose the operation as standard, as long as `canCreate` or `canEdit` and the model's permissions allow it. This is how a checkout-style workflow keeps a resource URL.
- Permissions are still the resource's. The server still decides what your widget may read and write.

The panel tests pin the routing: a custom create and edit screen answer `/notes/create` and `/notes/:id/edit`, with the record id handed to the builder.

## A widget inside a page of blocks

`BeakWidgetBlock` embeds an arbitrary widget where no block fits.

```dart title="packages/beak_frontend/lib/src/blocks/beak_widget_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_widget_block.dart:BeakWidgetBlock"
```

The operations page above uses two. `BeakWidgetBlock((context) => const ShopReceivablesCard())` embeds the receivables card, a `HookWidget` that reads the panel's data source, formatting and refresh scope from its context; it is the worked example on [Dashboards](dashboards.md). The second wraps `BeakImportView` for the category import, which previews a CSV, lists row errors and saves each accepted row with its own receipt ([Imports and bulk edits](../forms/imports-and-bulk-edits.md)).

Inside a widget block you have the panel's services: `beakDependencies(context)<BeakDataSource>()`, `BeakFormatting.of(context)`, `BeakLocalizations.of(context)`, `useBeakDataRevision` to refetch after writes. Prefer them to your own HTTP client, or your widget bypasses authentication and the error mapping.

## Rules and limits

- A screen has no permission of its own. It is visible to anyone the auth gate lets in, and every block reads through the same data source, so the server's row and field rules decide what shows. A block over a model the account cannot read renders the error, not the page redirect that a resource route gives.
- Give a screen a `path` no resource uses. Resource routes are `/<table>`, `/<table>/create`, `/<table>/:id` and `/<table>/:id/edit`, and they are registered before the pages, so a screen at `/orders/summary` meets the order's show route first (go_router takes the first match).
- At most one screen per role per resource, custom or not. A second one throws `Resource "x" defines more than one read screen.` when the panel starts.
- `BeakScreen.body` is a `BeakBlock`. Anything else goes in through `BeakWidgetBlock`, and that block gives up the declarative guarantees for its subtree.
- A framed screen scrolls its body. Blocks that want the viewport height (a kanban board, a map) belong in an unframed one.
- `BeakScreenView(screen:)` renders a screen anywhere you have a context, for a host app that embeds one page.
- Table, metric and summary blocks refetch after a write to their table. Chart, kanban and calendar blocks do not yet.

## Verify it

The discovery rules for `lib/screens/` are tested in the CLI:

```console
$ cd packages/beak_cli
$ dart test test/src/project/beak_discovery_test.dart --plain-name "screens"
00:00 +1: screens only a const variable is a constant expression
00:00 +2: screens a builder taking required arguments is reported
00:00 +3: screens non-screen declarations are ignored
00:00 +4: All tests passed!
```

In a scratch project (`beak create dash --no-pub --no-example`) with `lib/screens/overview.dart` holding `final BeakScreen overview = BeakScreen(path: '/', ...)`, `beak prepare` finds the screen and registers it:

```console
$ beak prepare
  0 models · 0 resource classes · 1 screen · 0 overrides
  generated  6 of 7 files
$ grep -n "pages" lib/beak/panel.g.dart
22:    pages: [overview],
```

Routing, sidebar placement and the custom resource screens are tested in the frontend package:

```console
$ cd packages/beak_frontend
$ flutter test test/src/panel/beak_screen_routing_test.dart --plain-name "custom screens" --reporter expanded
00:00 +0: custom screens a page appears in the nav and routes to its body
00:01 +1: custom screens the sidebar title defaults to the title
00:01 +2: custom screens a page is filed under its navigation group
00:01 +3: custom screens a hidden page routes but has no nav entry
00:01 +4: All tests passed!
$ flutter test test/src/panel/beak_panel_test.dart --plain-name "custom create and edit"
00:00 +0: generated routes custom create and edit workflows keep resource routes
00:01 +1: All tests passed!
```

The shop's operations page is pumped at three widths, committed receivables included:

```console
$ cd examples/clean_beak_config
$ flutter test test/custom_shop_test.dart
00:01 +1: custom operations fits 375.0 pixels and refreshes committed receivables
00:01 +2: custom operations fits 600.0 pixels and refreshes committed receivables
00:01 +3: custom operations fits 1440.0 pixels and refreshes committed receivables
00:01 +4: custom billing widget shows a retryable error without a false zero
00:01 +5: All tests passed!
```

## Reference

```dart title="packages/beak_frontend/lib/src/panel/beak_screen.dart"
--8<-- "packages/beak_frontend/lib/src/panel/beak_screen.dart:BeakScreen"
```

| Symbol | Notes |
| --- | --- |
| `BeakScreen` | Immutable; `effectiveNavigationTitle` is `navigationTitle ?? title`; `location` is `path` |
| `BeakScreenView` | Widget that renders a `BeakScreen`, framed or full-bleed |
| `BeakCustomResourceScreen` | `const BeakCustomResourceScreen({required this.builder, required super.roles})`, with `Widget Function(BuildContext context, Object? recordId) builder` |
| `BeakScreenRole` | `list`, `read`, `create`, `edit` |
| `BeakWidgetBlock` | `const BeakWidgetBlock(this.builder, {super.span})`, `builder` is a `WidgetBuilder` |
| `BeakRecordScope` | Carries the record that record blocks read; mount it yourself on a custom read screen |

The complete parameter tables of the screen classes are on [Screens and form layouts](../reference/screens-and-layouts.md).

## Continue reading

- [Dashboards](dashboards.md) an overview page at `/` built from metric, table and summary blocks.
- [Navigation](navigation.md) how a screen gets into a custom sidebar.
- [Blocks](../blocks/index.md) the block catalog a screen body is made of.
- [Custom blocks and widgets](../extending/custom-blocks-and-widgets.md) writing a block of your own.
