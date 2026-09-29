---
title: Layout blocks
description: Arrange a custom screen with columns, rows, grids, cards, tabs and accordions, and learn when a row or grid stacks on a narrow page.
type: guide
audience: [beginner]
status: stable
---

# Layout blocks

Layout blocks hold other blocks and show nothing themselves. After this page you can build the frame of a custom screen, predict when a row or a grid folds into one column, and reach for a plain widget when no block fits.

You have a `BeakScreen` and an empty `body`. The body takes exactly one block, so make it a `BeakColumnBlock` and put everything else inside it. The Aviary example does the same on every page:

```dart title="examples/showcase/lib/pages/layout_blocks.dart"
--8<-- "examples/showcase/lib/pages/layout_blocks.dart:layoutBlocksPage"
```

`navigationGroup` files the screen under a sidebar heading. `framed` (default `true`) gives the screen the standard header, gutters and scrolling. Set `framed: false` for full-bleed content such as a kanban board, which brings its own height.

## At a glance

| Block | Renders onto | Use it for |
| --- | --- | --- |
| `BeakColumnBlock` | `OiColumn` | Children stacked top to bottom, stretched to the full width. |
| `BeakRowBlock` | `OiRow` | Children side by side. `expand: true` shares the width by span weights. |
| `BeakGridBlock` | `OiGrid` | Children on tracks: a fixed column count, or as many columns as fit. |
| `BeakCardBlock` | `OiCard` | A surface with an optional title, subtitle and footer. |
| `BeakSectionBlock` | `OiSection` | A heading and a description over one child. |
| `BeakTabsBlock` | `OiTabs` | One panel at a time. |
| `BeakAccordionBlock` | `OiAccordion` | Expandable panels. |
| `BeakMasonryBlock` | `OiMasonry` | Cards of different heights packed into columns. |
| `BeakDividerBlock` | `OiDivider` | A rule, optionally with a centered label. |
| `BeakSpacerBlock` | `SizedBox` | A fixed vertical gap. |
| `BeakWidgetBlock` | your builder | Any Flutter widget, for what no block expresses. |

Every block also carries an optional `span`, and that is what the next section is about.

## Spans: one field, two meanings

`BeakSpan(columns: 1, rows: 1)` sits on the base class, because it means something to the parent and the parent can be one of two. In a `BeakGridBlock` it is the number of tracks the child covers. In a `BeakRowBlock` with `expand: true` its `columns` is a relative weight. Anywhere else it is ignored, so a card can declare `span: BeakSpan(columns: 8)` and lay out correctly whether or not it currently sits in a grid.

### Grid tracks

A card spans as many of twelve tracks as its span asks for:

```dart title="examples/showcase/lib/pages/layout_blocks.dart"
--8<-- "examples/showcase/lib/pages/layout_blocks.dart:gridSection"
```

Give a grid either `columns` (fixed tracks) or `minColumnWidthInPixels` (as many tracks as fit), never both, because the constructor asserts. With neither, you get one column. The dashboards use the second form: `BeakGridBlock(minColumnWidthInPixels: 220, children: [...])` puts as many metric cards on a line as the width allows and needs no spans at all.

A fixed grid protects itself on a narrow page. It measures every child at its declared span, and when any child would come out narrower than `minChildWidthInPixels` (240 by default) the whole grid becomes one column, in reading order. The arithmetic is in `BeakBlockHost`:

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_block_host.dart:gridStacking"
```

Two consequences. The measurement uses the grid's own width, not the window's, so the same grid folds sooner inside a narrow region than in a full page. And the smallest span decides: the 8 and 4 grid above has 16 pixel gaps, so its 4-track card is 240 pixels wide at a grid width of 752 and folds below that. Set `minChildWidthInPixels: 0` to keep the tracks at every width.

### Row weights

A natural row keeps each child's own width. An expanded row shares the width by weight and folds the same way a grid does:

```dart title="examples/showcase/lib/pages/layout_blocks.dart"
--8<-- "examples/showcase/lib/pages/layout_blocks.dart:rowSection"
```

The card with `BeakSpan(columns: 2)` gets two shares, the other one share. A child without a span has weight 1. Each child's width is `(width - gap * (children - 1)) * weight / total weight`, and the row folds into a column when any share falls under `minChildWidthInPixels`. With weights 5, 3 and 4 and the default 16 pixel gap:

| Row width | Widths of the three children | Result |
| --- | --- | --- |
| 1200 px | 486.7, 292.0, 389.3 | side by side |
| 1000 px | 403.3, 242.0, 322.7 | side by side |
| 992 px | 400.0, 240.0, 320.0 | side by side, the middle one exactly at the minimum |
| 991 px | 991.0 each | one column |

A row inside an unbounded width (a horizontal scroller, say) keeps intrinsic widths instead, because weights need a width to divide.

## Cards, sections and dividers

`BeakCardBlock` is the surface. It draws its own background, which is why a framed screen adds none: the frame gives you header, gutters and scrolling, and the cards give you the surfaces. Wrap the whole body in one card only when you want one shared surface.

`BeakSectionBlock` is a heading without a surface. `BeakDividerBlock` and `BeakSpacerBlock` are the small parts, both visible in the row example above (a labelled divider and a 12 pixel spacer).

## Tabs and accordions

```dart title="examples/showcase/lib/pages/layout_blocks.dart"
--8<-- "examples/showcase/lib/pages/layout_blocks.dart:tabsSection"
```

The selected tab is state, and a block is a `const` description, so the host owns it (a small `HookWidget` per `BeakTabsBlock`). Only the selected tab's content is built. A data block in a hidden tab does not fetch until you open it, and it fetches again when you come back.

```dart title="examples/showcase/lib/pages/layout_blocks.dart"
--8<-- "examples/showcase/lib/pages/layout_blocks.dart:accordionSection"
```

An accordion opens one panel at a time unless you pass `allowMultiple: true`. `initiallyExpanded` opens a panel on first build.

## Masonry

`BeakMasonryBlock` distributes its children across `columns` (default 3) and packs each column from the top, so cards of different heights leave no holes:

```dart title="examples/showcase/lib/pages/layout_blocks.dart"
--8<-- "examples/showcase/lib/pages/layout_blocks.dart:masonrySection"
```

## The escape hatch

`BeakWidgetBlock` takes a `WidgetBuilder`. It is the one block that holds code, and it is here for what no block expresses yet:

```dart title="examples/showcase/lib/pages/layout_blocks.dart"
--8<-- "examples/showcase/lib/pages/layout_blocks.dart:escapeHatchSection"
```

Use it last. The builder runs under the panel's scopes, so `beakDependencies(context)` works inside it, but nothing checks what it builds and a test that walks the block tree cannot see into it. [Custom blocks and widgets](../extending/custom-blocks-and-widgets.md) covers what to do with it.

## Rules and limits

- A screen's `body` is one block. Compose with a column, row or grid.
- Layout blocks do not bound height. Blocks that draw need a height and take one (`heightInPixels` on charts, maps, tables, summaries). A card around them takes its natural height, and cards in a row or grid are not stretched to match each other.
- `BeakTabsBlock` with no tabs renders nothing, and an `initialIndex` past the last tab selects the last one. Neither is asserted.
- `BeakMasonryBlock` asserts `columns >= 1`, a `BeakSpan` asserts `columns >= 1` and `rows >= 1`, and a `BeakRowBlock` or `BeakGridBlock` asserts non-negative `minChildWidthInPixels`.
- `BeakSectionBlock` puts an 8 pixel gap between its heading and its child. There is no parameter for it.
- Forms are not made of these blocks. A form layout has its own `BeakCard`, `BeakColumns`, `BeakTabs` and `BeakWizardStep` nodes, which stay connected to the draft. See [The block system](../concepts/the-block-system.md) for why there are two families.
- `BeakThreePaneBlock` is a layout too, but it hosts data blocks in every example, so it lives on [Module blocks](module-blocks.md).

## Verify it

The Aviary pumps every page against a fixture source and fails on any exception:

```console
$ cd examples/showcase
$ flutter test --no-pub test/aviary_pages_test.dart test/block_type_matrix_test.dart
00:07 +14: All tests passed!
```

To watch a fold happen, run the panel (see the [Showcase](../examples/showcase.md) page) and drag the browser window narrower on the Layout blocks page. The Grid section folds when its own width drops under 752 pixels, the Row and column section under 736 (weights 2 and 1, so the lighter card gets a third of what is left after the gap). The sidebar and the page gutters come off the window width first.

## Reference

Required parameters are marked with a star. Every block also takes `span`.

| Block | Parameters (default) |
| --- | --- |
| `BeakColumnBlock` | `children`*, `gapInPixels` (16) |
| `BeakRowBlock` | `children`*, `gapInPixels` (16), `expand` (false), `minChildWidthInPixels` (240) |
| `BeakGridBlock` | `children`*, `columns`, `minColumnWidthInPixels`, `minChildWidthInPixels` (240), `gapInPixels` (16) |
| `BeakCardBlock` | `child`*, `title`, `subtitle`, `headerGapInPixels` (16), `footer` |
| `BeakSectionBlock` | `title`*, `child`*, `description` |
| `BeakTabsBlock` | `tabs`*, `initialIndex` (0); each `BeakTabBlockItem` takes `label`*, `content`*, `icon` |
| `BeakAccordionBlock` | `items`*, `allowMultiple` (false); each `BeakAccordionBlockItem` takes `title`*, `content`*, `initiallyExpanded` (false) |
| `BeakMasonryBlock` | `children`*, `columns` (3), `gapInPixels` (16) |
| `BeakDividerBlock` | `label` |
| `BeakSpacerBlock` | `heightInPixels` (16) |
| `BeakWidgetBlock` | `builder`* (positional) |

The two constructors with layout logic, verbatim:

```dart title="packages/beak_frontend/lib/src/blocks/beak_row_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_row_block.dart:BeakRowBlock"
```

```dart title="packages/beak_frontend/lib/src/blocks/beak_grid_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_grid_block.dart:BeakGridBlock"
```

Every block class with its constructor is on [Blocks](../reference/blocks.md). The exhaustive host that renders them is explained in [Block system internals](../architecture/block-system-internals.md).

## Continue reading

- [Content blocks](content-blocks.md) text, images, alerts and the other blocks that show what you typed.
- [Data blocks](data-blocks.md) metrics, tables and boards that fetch for themselves.
- [Custom screens](../panel/custom-screens.md) how a `BeakScreen` becomes a route.
- [Blocks](../reference/blocks.md) every block class and its parameters.
