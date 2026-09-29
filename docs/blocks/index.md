---
title: Blocks and charts
description: Compose custom screens, list headers and dialogs from 47 typed blocks for layout, content, data, records, modules, charts and maps.
type: index
audience: [beginner, expert]
status: stable
---

# Blocks and charts

A generated resource gives you a table, a form and a show page. Everything else in a panel, the overview with its numbers, the kitchen list, the page that maps your customers, is a tree of blocks. This section catalogs all 47 of them, grouped the way you reach for them, with the Aviary example on every page.

A block is a `const` description of something to show: a card, a metric, a line chart. It carries configuration and no widget code, so a whole screen is a literal you can read top to bottom. `BeakBlockHost` turns the tree into obers_ui widgets, and it does so with one exhaustive `switch`:

```dart title="packages/beak_frontend/lib/src/blocks/beak_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_block.dart:BeakBlock"
```

## Which page to read

| You want to... | Read | For that |
| --- | --- | --- |
| Arrange a screen with columns, rows, grids, cards, tabs and accordions | [Layout blocks](layout-blocks.md) | The frame of a screen, and when rows and grids stack |
| Show text, markdown, images, alerts, badges, progress and ratings | [Content blocks](content-blocks.md) | Blocks that show what you hand them |
| Put live numbers, a table, a timeline, a board or a calendar on a page | [Data blocks](data-blocks.md) | Blocks that fetch for themselves, and where they stop |
| Total and group the whole authorized population on the server | [Population summaries](summaries.md) | Measures, six presentations and list scope |
| Show one record's fields and related rows on a screen you write | [Record blocks](record-blocks.md) | `BeakRecordScope` and the blocks that read it |
| Add a chat, inbox, file manager, media, profile, invoice, pricing or FAQ view | [Module blocks](module-blocks.md) | Ready-made interfaces bound to your models |
| Draw a query as a line, bar, pie, donut, area, radar, funnel, bubble, candlestick or heat map | [Charts](charts.md) | The mapper pattern for chart points |
| Shade countries by a value or pin rows on a map | [Maps](maps.md) | The vector choropleth and the tile map |

## Where blocks appear

Blocks describe things that show, and a page of them lands in three places:

- **A custom screen.** `BeakScreen(body: ...)` takes one block, registered in `BeakPanel(pages: [...])`.
- **A composed list's header.** `BeakListDefinition.header` and `collapsedHeader` take a block, usually a [summary](summaries.md) that shares the list's filters.
- **A dialog or side sheet.** `BeakOverlays.modal(body:)` and `BeakOverlays.sheet(body:)` render a block tree in an obers_ui dialog or sheet.

The Aviary registers twelve screens, from the data blocks to the FAQ:

```dart title="examples/showcase/lib/main.dart"
--8<-- "examples/showcase/lib/main.dart:aviaryPages"
```

Forms are a different tree. A read, create or edit screen is a list of form nodes bound to a draft, because a form has state a block does not. [The block system](../concepts/the-block-system.md) explains the split, and [Block system internals](../architecture/block-system-internals.md) shows how the host dispatches.

## The 47 blocks

Every block, once, under the page that documents it:

| Page | Blocks |
| --- | --- |
| [Layout blocks](layout-blocks.md) | `BeakColumnBlock`, `BeakRowBlock`, `BeakGridBlock`, `BeakCardBlock`, `BeakSectionBlock`, `BeakTabsBlock`, `BeakAccordionBlock`, `BeakMasonryBlock`, `BeakDividerBlock`, `BeakSpacerBlock`, `BeakWidgetBlock` |
| [Content blocks](content-blocks.md) | `BeakTextBlock`, `BeakMarkdownBlock`, `BeakImageBlock`, `BeakAlertBlock`, `BeakBadgeBlock`, `BeakProgressBlock`, `BeakRatingBlock`, `BeakRadialSliderBlock`, `BeakBreadcrumbsBlock`, `BeakIconGalleryBlock` |
| [Data blocks](data-blocks.md) | `BeakMetricBlock`, `BeakTableBlock`, `BeakTimelineBlock`, `BeakKanbanBlock`, `BeakCalendarBlock`, and `BeakSummaryBlock` (see [Population summaries](summaries.md)) |
| [Record blocks](record-blocks.md) | `BeakFieldBlock`, `BeakFieldGroupBlock`, `BeakRelationBlock` |
| [Module blocks](module-blocks.md) | `BeakChatBlock`, `BeakInboxBlock`, `BeakFileManagerBlock`, `BeakThreePaneBlock`, `BeakCarouselBlock`, `BeakGalleryBlock`, `BeakVideoBlock`, `BeakProfileBlock`, `BeakInvoiceBlock`, `BeakPricingBlock`, `BeakFaqBlock` |
| [Charts](charts.md) | `BeakChartBlock`, `BeakBubbleChartBlock`, `BeakCandlestickChartBlock`, `BeakHeatmapChartBlock` |
| [Maps](maps.md) | `BeakMapBlock`, `BeakTileMapBlock` |

The list is closed. `BeakBlock` is sealed, so you cannot add a block type from outside the package. The escape hatch is `BeakWidgetBlock`, which hosts any widget, and [Custom blocks and widgets](../extending/custom-blocks-and-widgets.md) shows how far it goes.

## What a block needs from the panel

Every block that shows data reads the panel's data source, so it works inside a `BeakPanel` with no wiring, and asks the server the same questions a list page would. They differ in how much they fetch and what makes them fetch again:

| Blocks | Get their data from | Fetch again after a write |
| --- | --- | --- |
| layout, content | the arguments | not applicable |
| `BeakMetricBlock`, `BeakSummaryBlock` | one aggregate or summary request | yes |
| `BeakTableBlock` | pages of a model | yes |
| charts, maps, `BeakTimelineBlock`, carousel, gallery, video | the query you pass | yes |
| kanban, calendar, chat, inbox, pricing, FAQ, `BeakFileManagerBlock` | the first 200 rows of a model (or of its `filter`) | yes |
| `BeakProfileBlock`, `BeakInvoiceBlock` | one record by id | no |
| field, field group | the nearest `BeakRecordScope` | not applicable |
| `BeakRelationBlock` | the scope, then the relation's rows | yes |

A panel's `refreshPolicy` makes the "yes" rows fetch on a timer as well. The "no" rows keep what they loaded until the screen is built again. Each page under this section says what its blocks do when a request fails, which for several of them is nothing at all.

## Spans

Every block takes an optional `span`, a `BeakSpan(columns:, rows:)`. Inside a `BeakGridBlock` it is the number of tracks the block covers. Inside an expanded `BeakRowBlock` its `columns` is a relative width. Everywhere else it is ignored. [Layout blocks](layout-blocks.md) has the arithmetic.

## Continue reading

- [Layout blocks](layout-blocks.md) start here to build the frame of a screen.
- [Data blocks](data-blocks.md) the fastest way to a working overview page.
- [Blocks](../reference/blocks.md) every block class, its constructor and its defaults.
- [Dashboards](../panel/dashboards.md) blocks assembled into an overview.
