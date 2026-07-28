---
title: Using Beak widgets standalone
description: Render a BeakBlockHost inside a normal Flutter app and mount BeakServer.handler inside an existing Shelf pipeline, without adopting the panel.
---

# Using Beak widgets standalone

After this page you can drop Beak's block renderer into a Flutter app that is
not a Beak panel, and mount Beak's API inside a server you already have. You
give up the generated shell and get a declarative content tree you render
yourself, backed by the same models. This page draws the line between the two.

`BeakPanel` is the whole bird: routing, the nav shell, generated resource pages,
theming, auth, and the data layer in GetIt. `BeakServer` is the whole API. But
the piece that turns a declarative tree into obers_ui widgets, `BeakBlockHost`,
is a plain widget, and `BeakServer.handler` is a plain Shelf handler. Either can
be used alone.

!!! example "The worked example"
    [`examples/embedded`](https://github.com/SimonErich/beak/tree/main/examples/embedded)
    is an application that already exists (its own server, its own Flutter app,
    its own auth) adopting Beak for part of its admin surface. Everything on
    this page is running code in it.

## Half one: Beak's API inside your server

`BeakServer.handler` is the full request pipeline (request log, CORS, JSON,
error mapping, auth) as one Shelf `Handler`. Mount it wherever you like in a
router of your own, behind whatever middleware you already run.

```dart title="examples/embedded/bin/host.dart"
  final router = Router()
    ..get('/', (Request request) => Response.ok('the host application'))
    ..mount('/admin', beak.handler);

  final handler = const Pipeline()
      .addMiddleware(_requireApiKey)
      .addHandler(router.call);

  final server = await shelf_io.serve(handler, '127.0.0.1', 8080);
```

The host keeps its own routes and its own gate. A request it rejects never
reaches Beak, and Beak's own auth and policy stay available for the requests
that do get through.

```console
dart run bin/host.dart
curl -H 'x-api-key: let-me-in' -X POST localhost:8080/admin/api/tickets/query \
  -H 'content-type: application/json' -d '{"table":"tickets"}'
```

## Half two: Beak blocks inside your app

The Flutter side is one widget. `BeakBlockHost` takes a `BeakBlock` tree and
renders it exhaustively onto obers_ui:

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
class BeakBlockHost extends StatelessWidget {
  /// Creates a host rendering [block].
  const BeakBlockHost({required this.block, super.key});

  /// The block tree to render.
  final BeakBlock block;
```

Two things have to be true around it: an `OiApp` ancestor, and a registered data
source if any of your blocks read records. The embedded example does both in one
small class.

```dart title="examples/embedded/lib/host_app.dart"
--8<-- "examples/embedded/lib/host_app.dart:HostApp"
```

The screen under it is an ordinary widget with an ordinary layout. One child
happens to be a Beak block tree, reading the same models and the same API the
admin panel reads:

```dart title="examples/embedded/lib/host_app.dart"
  @override
  Widget build(BuildContext context) => OiColumn(
    breakpoint: context.breakpoint,
    children: const [
      OiPageHeader(title: 'Support'),
      Expanded(
        child: BeakBlockHost(
          block: BeakTableBlock(
            model: TicketModel(),
            columns: [TicketColumns.subject, TicketColumns.status],
          ),
        ),
      ),
    ],
  );
```

!!! note "What just happened"
    - `OiApp` replaces `MaterialApp` and `CupertinoApp` as the root. Every
      `Oi*` widget, `BeakBlockHost` included, resolves its theme and its
      breakpoint from that scope.
    - `registerBeakDependencies` is the whole of the wiring. It populates the
      package-scoped locator with the model registry, the `BeakClient`, the
      `BeakDataSource` and the reference cache, which is what a data-bound
      block reaches for.
    - `buildBeakPanel()` is the generated config. You are not rendering the
      panel, but the config is where the API base URL and the model registry
      come from, so it is still what you hand over.

## The one requirement: an OiApp ancestor

If you take nothing else from this page, take this. `BeakBlockHost`'s layout
blocks resolve the active breakpoint from context, and every obers_ui widget
reads its theme from there. Without an `OiApp` above them, they have nothing to
read.

If you want none of Beak's abstraction at all, reach past it: `OiCard`,
`OiColumn`, `OiRow`, `OiGrid`, `OiTable`, `OiLabel`, `OiBadge` and the rest of
the catalogue come from `package:beak/ui.dart` and are yours to compose by hand.
That is not really "using Beak"; it is using the design system Beak is built on.

## What you keep

- **The declarative block tree.** Const config, one exhaustive renderer. A block
  type the host does not handle is a compile error, not a runtime surprise.
- **The layout, display, and UI-kit blocks.** Everything presentational renders
  from the `OiApp` scope alone: columns, rows, grids, cards, sections, tabs,
  accordions, text, images, markdown, alerts, badges, progress, ratings,
  dividers, wizards. See [The block system](../concepts/the-block-system.md).
- **The data-bound blocks**, once a source is registered: tables, KPIs, metrics,
  charts, calendars, kanban boards.
- **The escape hatch.** `BeakWidgetBlock` embeds any Flutter widget subtree where
  no block fits, so a block tree can host your own widgets mid-stream. See
  [The widget escape hatch](../blocks/the-widget-escape-hatch.md).
- **The models.** The schema classes, the generated columns and the migrations
  work the same whether or not a panel ever renders.

## What you give up

The panel earns its keep by wiring things a bare `BeakBlockHost` does not have.

**Data-bound blocks need the data layer in GetIt.** A `BeakTableBlock`,
`BeakKpiBlock`, or `BeakMetricBlock` resolves `beakLocator<BeakDataSource>()` to
fetch its rows. Inside a panel, `registerBeakDependencies` populated that
locator. Standalone, it is empty until you call the same function, which is
exactly why `HostApp` does so in its constructor.

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
    return BeakRelationManager(
      parentModel: scope.model,
      parentId: id,
      relationship: block.relationship,
      dataSource: beakLocator<BeakDataSource>(),
```

**Record blocks need a scope.** `BeakFieldBlock` and `BeakRelationBlock` are
dual-mode: they render read-only inside a `BeakRecordScope` (a detail view) and
editable inside a `BeakFormScope` (a form). Outside both, they render nothing:

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
  Widget _field(BuildContext context, BeakFieldBlock block) {
    final form = BeakFormScope.of(context);
    if (form != null) {
      return _fieldInput(form, block.column);
    }
    final scope = BeakRecordScope.of(context);
    if (scope == null) {
      return const SizedBox.shrink();
    }
```

So a record block dropped into a bare screen is a blank space by design. The
panel supplies the scope; standalone, you would too, which is most of what
[Detail views and dual-mode blocks](../panel/detail-and-dual-mode.md) is about.

**Everything the panel adds around the content.** Routing (go_router), the
navigation shell, generated list/detail/form pages, the command bar, auth and
idle-lock, theming controls, maintenance mode, and notifications all live in
`BeakPanel`. Standalone, you own navigation and app structure; Beak renders only
the blocks you place.

## When to use which

| You want | Reach for |
| --- | --- |
| A full admin panel from your schema classes | `BeakApp`, which `beak prepare` generates |
| A block tree on your own screen | `BeakBlockHost` under an `OiApp` |
| Data-bound blocks off-panel | `registerBeakDependencies` first, then `BeakBlockHost` |
| Beak's API inside a server you already run | `BeakServer.handler`, mounted in your router |
| One-off UI, no model in sight | plain `Oi*` widgets from `package:beak/ui.dart` |

Standalone use is testable the same way a panel is: pass an
`InMemoryBeakDataSource` where the real one would go and pump the widget.
`examples/embedded/test/embedded_test.dart` does exactly that.

## Continue reading

- [The block system](../concepts/the-block-system.md) the sealed `BeakBlock` union and the one renderer behind it.
- [Custom screens](../panel/custom-screens.md) the same block tree as a first-class page inside a panel.
- [The widget escape hatch](../blocks/the-widget-escape-hatch.md) `BeakWidgetBlock`, for dropping raw Flutter into a block tree.
- [Escape hatches](../models/escape-hatches.md) the rest of the ways out, including a table another system owns.
- [Custom data sources](custom-data-sources.md) how to feed data-bound blocks a source of your own.
