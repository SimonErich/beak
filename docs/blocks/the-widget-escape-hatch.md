---
title: The widget escape hatch
description: BeakWidgetBlock lets you drop any obers_ui widget into a block tree when no typed block fits, without leaving the no-Material rule.
---

# The widget escape hatch

After this page you can render an arbitrary widget inside an otherwise
declarative block tree, for the rare corner no typed block covers. `BeakWidgetBlock`
is that hatch. It is the block-tree twin of `BeakCustomColumn`: reach for it when
the union runs out, and only then.

## What it is

Blocks are pure `const` configuration. The whole point is that a block tree
carries no widget code, so the same tree renders a page, a view mode, or an
overlay, and adding a block type is a compile error until every renderer handles
it. `BeakWidgetBlock` deliberately breaks that guarantee in one spot: it holds a
`WidgetBuilder` and renders whatever the builder returns.

```dart title="packages/beak_frontend/lib/src/blocks/beak_widget_block.dart"
final class BeakWidgetBlock extends BeakBlock {
  /// Creates a block that renders whatever [builder] returns.
  const BeakWidgetBlock(this.builder, {super.span});

  /// Builds the embedded subtree.
  final WidgetBuilder builder;
}
```

The host renders it by handing your builder a `BuildContext` and nothing else:

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
final BeakWidgetBlock widget => Builder(builder: widget.builder),
```

That is the entire mechanism. Your builder runs inside the panel's widget tree,
so it can read inherited scopes and theme the way any obers_ui widget does.

## Using it

Pass a builder that returns an obers_ui widget. Because a block can take a `span`,
the escape hatch still places itself inside a `BeakGridBlock` like any other block.

```dart
BeakWidgetBlock(
  (context) => OiCard(
    child: OiLabel.caption('Rendered by a raw builder, still obers_ui.'),
  ),
);
```

That drops a hand-built card wherever a block goes: a custom screen body, a card
child, an overlay. Everything else in the tree stays declarative; only this leaf
is hand-rolled.

## Prefer a typed block

The block's own dartdoc says it plainly, and it is worth repeating:

> Prefer a typed block whenever one exists. Escape hatches trade away the
> declarative guarantees the rest of the union keeps.

A typed block renders the same on every surface, survives a `BeakBlockHost`
refactor, and cannot drift from the design system. A `BeakWidgetBlock` gives up
all three: its contents are opaque to the host, so nothing checks them for you.
Before you use it, scan the [layout](layout-blocks.md), [display](display-blocks.md),
[UI-kit](ui-kit-blocks.md), and [data](data-blocks.md) blocks. There are around
fifty, and one usually fits. When none does, `BeakWidgetBlock` is the honest way
out rather than forking a block.

## Stay off Material

The escape hatch does not exempt you from Beak's one hard UI rule. Your builder
must return obers_ui widgets (the `Oi*` family), with Flutter's `widgets.dart`
and `foundation.dart` allowed only for the core types (`BuildContext`, `Widget`,
`Key`, `EdgeInsets`, `Color`, and friends). Never import
`package:flutter/material.dart` or `package:flutter/cupertino.dart` inside a
builder. The panel's `guard-material` check greps for those imports across the
whole tree, so a Material widget smuggled through a `BeakWidgetBlock` fails the
gate the same as anywhere else.

!!! tip "The column-side twin"
    `BeakWidgetBlock` is to blocks what `BeakCustomColumn` is to columns: the
    documented, typed escape hatch for the one thing the declarative surface does
    not model. If you find yourself wanting a raw widget for a table cell rather
    than a block, that is the tool. See [Custom columns](../extending/custom-columns.md).

## Continue reading

- [The block system](../concepts/the-block-system.md) why blocks are a sealed union and what the host guarantees.
- [Custom blocks and widgets](../extending/custom-blocks-and-widgets.md) when to reach for the hatch versus writing a new typed block.
- [Custom columns](../extending/custom-columns.md) the same escape hatch on the column side, `BeakCustomColumn`.
- [Display blocks](display-blocks.md) the typed blocks to check before you drop to a raw widget.
