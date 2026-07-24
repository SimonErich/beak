---
title: Using Beak widgets standalone
description: Render a BeakBlockHost or a single obers_ui widget inside a normal Flutter app without the panel, and know exactly what you keep and what you give up.
---

# Using Beak widgets standalone

After this page you can drop Beak's block renderer, or a single obers_ui widget,
into a Flutter app that is not a Beak panel, on one screen or a hundred. You give
up the generated CRUD and get a declarative content tree you render yourself.
This page draws the line between the two.

`BeakPanel` is the whole bird: routing, the nav shell, generated resource pages,
theming, auth, and the data layer in GetIt. But the piece that turns a
declarative tree into obers_ui widgets, `BeakBlockHost`, is a plain widget you
can use alone. So is every `Oi*` widget underneath it.

## The one thing you need first: an OiApp ancestor

Beak's UI is obers_ui, and obers_ui widgets read a theme and a responsive
breakpoint from an `OiApp` scope. `BeakBlockHost` is no exception: its layout
blocks resolve the active breakpoint from context. So the setup is the same as
any obers_ui app. Wrap your tree in an `OiApp`:

```dart title="obers_ui/lib/src/foundation/oi_app.dart"
void main() {
  runApp(
    OiApp(
      theme: OiThemeData.light(),
      darkTheme: OiThemeData.dark(),
      themeMode: OiThemeMode.system,
      home: const MyHomePage(),
    ),
  );
}
```

`OiApp` replaces `MaterialApp` and `CupertinoApp` as the root. Inside it, any
obers_ui widget, and any `BeakBlockHost`, renders.

## Option one: plain obers_ui widgets

If you want none of Beak's abstraction, reach past it. `OiCard`, `OiColumn`,
`OiRow`, `OiGrid`, `OiTable`, `OiLabel`, `OiBadge`, and the rest of the obers_ui
catalogue are yours to compose by hand. This is not really "using Beak" at all;
it is using the design system Beak is built on, and the
[obers_ui docs](https://github.com/SimonErich/obers_ui) cover it. Reach here when
a screen has nothing to do with a model and you want full control.

## Option two: a BeakBlockHost

The more interesting standalone tool is the block renderer. `BeakBlockHost` takes
a `BeakBlock` tree and renders it exhaustively onto obers_ui:

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
class BeakBlockHost extends StatelessWidget {
  /// Creates a host rendering [block].
  const BeakBlockHost({required this.block, super.key});

  /// The block tree to render.
  final BeakBlock block;
```

A block tree is `const` configuration. You build it once and hand it over:

```dart title="packages/beak_frontend/lib/src/blocks/beak_block.dart"
const body = BeakColumnBlock(
  children: [
    BeakTextBlock('Welcome back', variant: BeakTextVariant.h1),
    BeakGridBlock(
      columns: 12,
      children: [
        BeakCardBlock(
          span: BeakSpan(columns: 6),
          child: BeakTextBlock('Half width'),
        ),
        BeakCardBlock(
          span: BeakSpan(columns: 6),
          child: BeakTextBlock('Other half'),
        ),
      ],
    ),
  ],
);
```

Dropped into a screen under `OiApp`, `BeakBlockHost(block: body)` renders that
tree. You get the block system's layout, display, and UI-kit families with no
panel around them: columns, rows, grids, cards, sections, tabs, accordions, text,
images, markdown, alerts, badges, progress, ratings, dividers, wizards. All of
them are pure presentation and need nothing but the `OiApp` scope. See
[The block system](../concepts/the-block-system.md) for the full union.

!!! note "What just happened"
    You used Beak's renderer without Beak's panel. The same `BeakColumnBlock`
    that composes a custom screen inside `BeakPanel` composes a section of your
    own app here. One renderer, two homes.

## What you keep

- **The declarative block tree.** Const config, one exhaustive renderer. Adding
  an unknown block type is a compile error, not a runtime surprise.
- **The layout, display, and UI-kit blocks.** Everything presentational renders
  from the `OiApp` scope alone.
- **The escape hatch.** `BeakWidgetBlock` embeds any Flutter widget subtree where
  no block fits, so a block tree can host your own widgets mid-stream. See
  [The widget escape hatch](../blocks/the-widget-escape-hatch.md).

## What you give up

The panel earns its keep by wiring things a bare `BeakBlockHost` does not have.
Two categories of block quietly depend on that wiring.

**Data-bound blocks need the data layer in GetIt.** A `BeakTableBlock`,
`BeakKpiBlock`, or `BeakMetricBlock` resolves `beakLocator<BeakDataSource>()` to
fetch its rows. Inside a panel, `registerBeakDependencies` populated that
locator. Standalone, it is empty, and these blocks throw until you register a
source yourself. Look at how the relation block reaches for the locator:

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
return BeakRelationManager(
  parentModel: scope.model,
  parentId: id,
  relationship: block.relationship,
  dataSource: beakLocator<BeakDataSource>(),
);
```

If you want data-bound blocks standalone, call `registerBeakDependencies` with a
`dataSource` (see [Custom data sources](custom-data-sources.md)) before you render
them. Otherwise, stick to presentational blocks.

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
  // ... renders the read-only value.
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
| A full admin panel from models | `BeakPanel` and a `BeakPanelConfig` |
| A block tree on your own screen | `BeakBlockHost` under an `OiApp` |
| Data-bound blocks off-panel | `registerBeakDependencies` first, then `BeakBlockHost` |
| One-off UI, no model in sight | plain `Oi*` widgets |

## Continue reading

- [The block system](../concepts/the-block-system.md) the sealed `BeakBlock` union and the one renderer behind it.
- [Custom screens](../panel/custom-screens.md) the same block tree as a first-class page inside a panel.
- [The widget escape hatch](../blocks/the-widget-escape-hatch.md) `BeakWidgetBlock`, for dropping raw Flutter into a block tree.
- [Custom data sources](custom-data-sources.md) how to feed data-bound blocks a source of your own.
