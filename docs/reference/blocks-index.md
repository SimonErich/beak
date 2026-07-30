---
title: Blocks index
description: Every BeakBlock variant, grouped by category, with its constructor parameters and defaults in one scannable place.
---

# Blocks index

Every block Beak ships, in one table per category. Reach for this page when you know the block you want and need its exact parameter names and defaults. For the prose (when to use each, worked examples), follow the link at the top of each section into the [Blocks section](../blocks/index.md).

## The base

Every block is a `const` node in one sealed union. `BeakBlockHost` renders that union exhaustively, so a new block type is a compile error until every surface handles it. There are no callbacks except where an interaction is the feature, and one documented [widget escape hatch](../blocks/the-widget-escape-hatch.md).

```dart title="packages/beak_frontend/lib/src/blocks/beak_block.dart"
@immutable
sealed class BeakBlock {
  /// Creates a block, optionally sized by [span] inside grid parents.
  const BeakBlock({this.span});

  /// How many grid tracks this block occupies when it is a direct child
  /// of a [BeakGridBlock]; ignored elsewhere.
  final BeakSpan? span;
}

@immutable
final class BeakSpan {
  /// Creates a span covering [columns] × [rows] grid tracks.
  const BeakSpan({this.columns = 1, this.rows = 1})
    : assert(columns >= 1, 'columns must be >= 1'),
      assert(rows >= 1, 'rows must be >= 1');

  final int columns;
  final int rows;
}
```

Because `span` lives on the base, **every** block below also accepts an optional `super.span` (a `BeakSpan`) that sizes it inside a [`BeakGridBlock`](#layout-blocks). It is omitted from the per-block tables to keep them readable; assume it is always there.

Blocks come in six families. Chart and map blocks are data-bound blocks whose prose lives under [Charts and maps](../charts/index.md); they are listed here for completeness.

| Family | What it is for | Section |
| --- | --- | --- |
| [Layout](#layout-blocks) | Arranging other blocks: stacks, grids, cards, tabs. | [Layout blocks](../blocks/layout-blocks.md) |
| [Display](#display-blocks) | Static content: text, images, markdown, icons. | [Display blocks](../blocks/display-blocks.md) |
| [UI-kit](#ui-kit-blocks) | Small primitives: alerts, badges, meters, ratings. | [UI-kit blocks](../blocks/ui-kit-blocks.md) |
| [Data](#data-blocks) | Query-backed: KPIs, tables, charts, maps, calendars. | [Data blocks](../blocks/data-blocks.md) |
| [Record](#record-blocks) | Dual-mode fields that read or edit one record. | [Record blocks](../blocks/record-blocks.md) |
| [Module](#module-blocks) | Whole screens: chat, inbox, invoice, pricing, wizard. | [Module blocks](../blocks/module-blocks.md) |

## Layout blocks

The scaffolding. These take other blocks as children and decide how they sit on the page. Prose: [Layout blocks](../blocks/layout-blocks.md).

| Block | Required | Optional (default) | Renders as |
| --- | --- | --- | --- |
| `BeakColumnBlock` | `children: List<BeakBlock>` | `gapInPixels = 16` | A vertical stack. |
| `BeakRowBlock` | `children: List<BeakBlock>` | `gapInPixels = 16` | A horizontal row. |
| `BeakGridBlock` | `children: List<BeakBlock>` | `columns?`, `minColumnWidthInPixels?`, `gapInPixels = 16` | A responsive grid; children size with `span`. |
| `BeakCardBlock` | `child: BeakBlock` | `title?`, `subtitle?`, `footer?: BeakBlock` | A card container. |
| `BeakSectionBlock` | `title: String`, `child: BeakBlock` | `description?` | A titled section with an optional blurb. |
| `BeakTabsBlock` | `tabs: List<BeakTabBlockItem>` | `initialIndex = 0` | A tab bar over swappable panels. |
| `BeakTabBlockItem` | `label: String`, `content: BeakBlock` | `icon?: IconData` | One tab (not a block itself). |
| `BeakAccordionBlock` | `items: List<BeakAccordionBlockItem>` | `allowMultiple = false` | Collapsible panels. |
| `BeakAccordionBlockItem` | `title: String`, `content: BeakBlock` | `initiallyExpanded = false` | One accordion panel. |
| `BeakBreadcrumbsBlock` | `items: List<BeakBreadcrumbBlockItem>` | (none) | A breadcrumb trail. |
| `BeakBreadcrumbBlockItem` | `label: String` | `route?: String` | One crumb, optionally a link. |
| `BeakMasonryBlock` | `children: List<BeakBlock>` | `columns = 3`, `gapInPixels = 16` | A masonry (Pinterest-style) grid. |
| `BeakThreePaneBlock` | `label`, `left: BeakBlock`, `middle: BeakBlock` | `right?: BeakBlock`, `leftWidthInPixels = 260`, `rightWidthInPixels = 320` | A three-column mail-app layout. |
| `BeakCarouselBlock` | `query: BeakQuerySpec`, `imageUrlField: BeakColumn` | `captionField?`, `heightInPixels = 320`, `autoplay = true` | A rotating image carousel (data-bound). |
| `BeakDividerBlock` | (none) | `label?: String` | A horizontal rule, optionally labelled. |
| `BeakSpacerBlock` | (none) | `heightInPixels = 16` | Blank vertical space. |
| `BeakTimelineBlock` | `query: BeakQuerySpec`, `titleField`, `timeField: BeakColumn` | (none) | A vertical event timeline (data-bound). |

Here is one verbatim. Note the assert: pass `columns` or `minColumnWidthInPixels`, never both.

```dart title="packages/beak_frontend/lib/src/blocks/beak_grid_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_grid_block.dart:BeakGridBlock"
```

## Display blocks

Static content that does not read the database. Prose: [Display blocks](../blocks/display-blocks.md).

| Block | Signature | Optional (default) | Renders as |
| --- | --- | --- | --- |
| `BeakTextBlock` | `BeakTextBlock(String text, {...})` | `variant = BeakTextVariant.body` | A run of themed text. |
| `BeakMarkdownBlock` | `BeakMarkdownBlock(String source, {...})` | (none) | Rendered Markdown. |
| `BeakImageBlock` | `BeakImageBlock(String url, {required alt, ...})` | `widthInPixels?`, `heightInPixels?`, `fit = BoxFit.cover` | A static image. |
| `BeakVideoBlock` | `BeakVideoBlock({required query, required urlField, ...})` | `posterField?`, `title?`, `autoPlay = false`, `loop = false` | A video from `query` + `urlField` (data-bound). |
| `BeakIconGalleryBlock` | `BeakIconGalleryBlock({required items, ...})` | `columns = 6` | A grid of labelled icons. |
| `BeakIconGalleryItem` | `BeakIconGalleryItem({required icon, required label})` | (none) | One icon tile (`icon: BeakIconToken`). |

`BeakTextBlock`'s `variant` is a `BeakTextVariant`:

| Value | Use |
| --- | --- |
| `display` | Hero display text. |
| `h1` / `h2` / `h3` / `h4` | Headings, largest to smallest. |
| `body` | Regular body copy (the default). |
| `bodyStrong` | Emphasized body copy. |
| `small` | De-emphasized small text. |
| `caption` | Caption or hint text. |

## UI-kit blocks

Small self-contained primitives. Prose: [UI-kit blocks](../blocks/ui-kit-blocks.md).

| Block | Signature | Optional (default) | Renders as |
| --- | --- | --- | --- |
| `BeakAlertBlock` | `BeakAlertBlock(String message, {...})` | `level = BeakAlertLevel.info` | A coloured callout banner. |
| `BeakBadgeBlock` | `BeakBadgeBlock(String label, {...})` | `color = BeakColor.primary` | A small pill badge. |
| `BeakProgressBlock` | `BeakProgressBlock({required value, ...})` | `label?: String` | A progress bar (`value` is `0..1`). |
| `BeakRatingBlock` | `BeakRatingBlock({required value, ...})` | `maxStars = 5`, `readOnly = true` | A star rating. |
| `BeakRadialSliderBlock` | `BeakRadialSliderBlock({required label, ...})` | `min = 0`, `max = 100`, `initialValue = 40`, `sizeInPixels = 200` | A circular slider gauge. |

`BeakAlertBlock`'s `level` is a `BeakAlertLevel`: `info`, `success`, `warning`, `error`.

## Data blocks

Backed by a `BeakModel` or a `BeakQuerySpec`; they fetch and render live rows. Prose: [Data blocks](../blocks/data-blocks.md). Chart and map blocks are documented in depth under [Chart basics](../charts/chart-basics.md), [Advanced charts](../charts/advanced-charts.md), and [Maps](../charts/maps.md).

| Block | Required | Optional (default) | Renders as |
| --- | --- | --- | --- |
| `BeakKpiBlock` | `title: String`, `value: BeakAggregateSpec` | `previous?`, `target?: num`, `format = BeakKpiFormat.number`, `currencySymbol = r'$'`, `decimals = 0` | A single big number with a delta. |
| `BeakMetricBlock` | `label: String`, `aggregate: BeakAggregateSpec` | `icon?: IconData`, `prefix = ''`, `suffix = ''` | A compact metric tile. |
| `BeakTableBlock` | `model: BeakModel` | `title?`, `columns?: List<BeakColumn>`, `initialSpec?: BeakQuerySpec`, `baseFilter?: BeakFilter`, `actions = const []`, `onRowTap?`, `heightInPixels = 360` | An embedded data table. |
| `BeakChartBlock` | `title`, `type: BeakChartType`, `query: BeakQuerySpec`, `map: BeakChartMapper` | `heightInPixels = 260` | A line/bar/pie/etc. chart. |
| `BeakBubbleChartBlock` | `title`, `query`, `map: BeakBubbleMapper` | `heightInPixels = 300` | A bubble chart. |
| `BeakCandlestickChartBlock` | `title`, `query`, `map: BeakCandleMapper` | `heightInPixels = 320` | An OHLC candlestick chart. |
| `BeakHeatmapChartBlock` | `title`, `query`, `map: BeakMatrixMapper` | `rowLabels?`, `columnLabels?: List<String>`, `heightInPixels = 320` | A matrix heatmap. |
| `BeakMapBlock` | `title`, `query`, `regionCodeField`, `valueField: BeakColumn` | `valueLabel = 'Value'`, `heightInPixels = 320` | A choropleth region map. |
| `BeakTileMapBlock` | `title`, `query`, `latitudeField`, `longitudeField: BeakColumn` | `labelField?`, `centerLatitude?`, `centerLongitude?`, `zoom = 3`, `tileUrlTemplate = '…/{z}/{x}/{y}.png'`, `heightInPixels = 360` | A pin map over OpenStreetMap tiles. |
| `BeakGalleryBlock` | `query: BeakQuerySpec`, `imageUrlField: BeakColumn` | `captionField?`, `columns = 4` | An image gallery grid. |
| `BeakCalendarBlock` | `model: BeakModel`, `titleField`, `startField: BeakColumn` | `endField?`, `allDayField?`, `categoryField?`, `mode = OiCalendarMode.month`, `label = 'Calendar'`, `onEventTap?`, `onEventMove?` | A calendar of records. |
| `BeakKanbanBlock` | `model: BeakModel`, `groupField: BeakEnumColumn<Enum>`, `titleField: BeakColumn` | `subtitleField?`, `sortField?`, `sortDescending = false`, `label = 'Board'`, `onCardMove?` | A drag-and-drop board grouped by an enum. |

`BeakKpiBlock`'s `format` is a `BeakKpiFormat`: `number`, `currency`, `percent`. The default tile map URL template quoted above is `https://tile.openstreetmap.org/{z}/{x}/{y}.png`.

## Record blocks

The dual-mode family. The same three blocks render read-only values inside a `BeakRecordScope` (a resource's `detail`) and editable inputs inside a `BeakFormScope` (a resource's `formLayout`). One layout, two surfaces. Prose: [Record blocks](../blocks/record-blocks.md).

| Block | Signature | Optional (default) | Renders as |
| --- | --- | --- | --- |
| `BeakFieldBlock` | `BeakFieldBlock(BeakColumn column, {...})` | `label?`, `layout = BeakFieldLayout.stacked` | One column: a value or an input. |
| `BeakFieldGroupBlock` | `BeakFieldGroupBlock(List<BeakColumn> columns, {...})` | `columnCount = 2` | A grid of fields. |
| `BeakRelationBlock` | `BeakRelationBlock(BeakRelationship relationship, {...})` | `title?: String` | A related-record list or picker. |

`BeakFieldBlock`'s `layout` is a `BeakFieldLayout`: `stacked` (label above value) or `inline` (label beside value).

## Module blocks

Fully-formed screens built from a model and a handful of field bindings. Point one at your data and it renders the whole feature. Prose: [Module blocks](../blocks/module-blocks.md).

| Block | Required | Optional (default) | Renders as |
| --- | --- | --- | --- |
| `BeakChatBlock` | `model`, `authorField`, `bodyField`, `timeField` | `isMineField?`, `composeRecord?`, `label = 'Chat'` | A messaging thread. |
| `BeakInboxBlock` | `model`, `senderField`, `subjectField` | `previewField?`, `timeField?`, `unreadField?`, `readField?`, `folderRelation?: BeakBelongsTo`, `folderLabelField?`, `folders = const ['Inbox']`, `label = 'Inbox'`, `leftWidthInPixels = 220`, `rightWidthInPixels = 360` | A three-pane email client. |
| `BeakFileManagerBlock` | `model`, `nameField`, `isFolderField` | `sizeField?`, `modifiedField?`, `thumbnailField?`, `label = 'Files'`, `onOpen?` | A file/folder browser. |
| `BeakInvoiceBlock` | `model`, `recordId: Object`, `lineItemsModel: BeakModel`, `totalField` | `logoField?`, `fromFields = const []`, `toFields = const []`, `metaFields = const []`, `toRelation?: BeakBelongsTo`, `toPartyFields = const []`, `lineItemsForeignKey?`, `subtotalField?`, `discountField?`, `shippingField?`, `taxField?`, `title = 'Invoice'` | A printable invoice. |
| `BeakProfileBlock` | `model`, `recordId: Object`, `nameField` | `emailField?`, `roleField?`, `avatarField?`, `bioField?`, `label = 'Profile'` | A user profile card. |
| `BeakPricingBlock` | `model`, `nameField`, `priceField` | `yearlyPriceField?`, `featuredField?`, `descriptionField?`, `ctaField?`, `featuresRelation?: BeakRelationship`, `featureLabelField?`, `sortField?`, `label = 'Pricing'`, `currencySymbol = r'$'` | A pricing-tier grid. |
| `BeakFaqBlock` | `model`, `questionField`, `answerField` | `categoryField?`, `sortField?`, `label = 'Help'` | A searchable FAQ. |
| `BeakWizardBlock` | `steps: List<BeakWizardStep>` | `stepperStyle = OiStepperStyle.horizontal`, `onComplete?: VoidCallback` | A multi-step stepper. |
| `BeakWizardStep` | `title: String`, `body: BeakBlock` | `subtitle?`, `icon?`, `canAdvance?: bool Function()` | One wizard step (not a block itself). |

All of the `*Field` parameters above take a typed `BeakColumn`, not a string. That is the [type-safety promise](../concepts/the-type-safety-promise.md) at work: you point a module at columns you already declared, and the compiler checks the wiring.

## The widget escape hatch

When no block fits, drop to a raw obers_ui widget. This is the one sanctioned way out of the block union. Prose: [The widget escape hatch](../blocks/the-widget-escape-hatch.md).

```dart title="packages/beak_frontend/lib/src/blocks/beak_widget_block.dart"
const BeakWidgetBlock(this.builder, {super.span});
```

`builder` is a `WidgetBuilder`. Keep the widget inside obers_ui (no Material) and you stay inside Beak's rules.

## Continue reading

- [The blocks section](../blocks/index.md) prose and worked examples for every family above.
- [The block system](../concepts/the-block-system.md) how the sealed union and `BeakBlockHost` fit together.
- [Chart basics](../charts/chart-basics.md) the data-bound chart blocks in depth.
- [CLI commands](cli-commands.md) scaffold the models these blocks bind to.
