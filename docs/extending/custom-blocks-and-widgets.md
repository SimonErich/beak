---
title: Custom blocks and widgets
description: Drop any obers_ui widget into a Beak block tree with BeakWidgetBlock, and compose it with the typed blocks.
---

# Custom blocks and widgets

After this page you can embed an arbitrary `obers_ui` widget anywhere a block
goes, using `BeakWidgetBlock`, and you know how it composes with the rest of the
block tree and when to prefer a typed block instead.

Blocks are Beak's declarative vocabulary for every non-CRUD surface: dashboards,
custom screens, alternate view modes, overlay bodies. There are around fifty of
them, one sealed union, rendered by a single exhaustive host. When your subtree
is not in the union, `BeakWidgetBlock` is the way in. It is the block-level twin
of the [custom column](custom-columns.md) hatch.

## The block

`BeakWidgetBlock` holds a `WidgetBuilder` and nothing else. When the host reaches
it, it builds whatever the builder returns.

```dart title="packages/beak_frontend/lib/src/blocks/beak_widget_block.dart"
final class BeakWidgetBlock extends BeakBlock {
  /// Creates a block that renders whatever [builder] returns.
  const BeakWidgetBlock(this.builder, {super.span});

  /// Builds the embedded subtree.
  final WidgetBuilder builder;
}
```

The renderer is one arm of the host's exhaustive switch, and it is as thin as it
looks: the builder is handed straight to a Flutter `Builder`.

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
    final BeakWidgetBlock widget => Builder(builder: widget.builder),
```

Using it is a one-liner. The builder receives the build context and returns any
widget:

```dart title="packages/beak_frontend/test/src/blocks/beak_block_host_test.dart"
BeakWidgetBlock((context) => const OiLabel.body('escaped'))
```

!!! note "What just happened"
    - `BeakWidgetBlock` is a `BeakBlock` like any other, so it slots wherever a
      block is expected: a screen body, a card's child, a grid cell.
    - The host does no interpretation. Your builder owns the subtree from that
      node down.
    - Nothing here is data-bound. If you need records, read them yourself inside
      the builder, or reach for a data-bound block instead.

## Staying no-Material

The builder is plain Flutter, which means the no-Material rule is now yours to
enforce. Return widgets from `obers_ui` (`OiLabel`, `OiCard`, `OiColumn`,
`OiButton`, and the rest), never `package:flutter/material.dart` or
`cupertino.dart`. Beak's Material guard scans Beak's own packages and cannot see
inside your closure, so a stray `Text` or `Card` from Material compiles and runs
and quietly breaks the house style. Keep the import list honest.

## Composing with other blocks

Because a `BeakWidgetBlock` is just another node in the union, you compose it
exactly like the typed blocks: nest it in a `BeakColumnBlock`, a `BeakCardBlock`,
or a `BeakGridBlock`, and mix it freely with typed siblings.

```dart
BeakGridBlock(
  columns: 12,
  children: [
    const BeakCardBlock(
      span: BeakSpan(columns: 6),
      title: 'Revenue',
      child: BeakTextBlock('A typed block'),
    ),
    BeakCardBlock(
      span: const BeakSpan(columns: 6),
      title: 'Bespoke gauge',
      child: BeakWidgetBlock((context) => const OiLabel.body('your widget here')),
    ),
  ],
)
```

Every block, the widget block included, can take a `BeakSpan` to size itself
inside a grid parent. That field lives on the base of the union:

```dart title="packages/beak_frontend/lib/src/blocks/beak_block.dart"
sealed class BeakBlock {
  /// Creates a block, optionally sized by [span] inside grid parents.
  const BeakBlock({this.span});

  /// How many grid tracks this block occupies when it is a direct child
  /// of a [BeakGridBlock]; ignored elsewhere.
  final BeakSpan? span;
}
```

Wrapping your widget in a `BeakCardBlock` (as above) is usually what you want:
the card gives it the panel's chrome, so a custom gauge sits flush beside typed
KPI and chart cards instead of floating unstyled.

## When to prefer a typed block

Prefer a typed block whenever one exists. The escape hatch trades away the
guarantees the rest of the union keeps: a typed block is `const`, inspectable,
and rendered through one audited switch, while a `BeakWidgetBlock` is opaque code
Beak runs on trust. Before you reach for it, scan the catalog:

- Text, headings, markdown, images, icons: [display blocks](../blocks/display-blocks.md).
- Alerts, badges, progress, ratings: [UI-kit blocks](../blocks/ui-kit-blocks.md).
- KPIs, charts, tables, calendars, kanban: [data blocks](../blocks/data-blocks.md).
- Chat, inbox, files, invoices, pricing, FAQ: [module blocks](../blocks/module-blocks.md).

If your subtree is genuinely none of those, the widget block is the honest
answer. If it is almost one of them, extend the typed path instead.

## Continue reading

- [The widget escape hatch](../blocks/the-widget-escape-hatch.md) the same block from the blocks catalog's side.
- [The block system](../concepts/the-block-system.md) how the union and its single host fit together.
- [Custom screens and pages](custom-screens-and-pages.md) give a widget block tree a route and a place in the nav.
- [Using Beak widgets standalone](using-beak-widgets-standalone.md) drop a Beak surface into an app that is not a full panel.
