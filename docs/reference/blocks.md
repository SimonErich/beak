---
title: Blocks
description: Every block class of the sealed BeakBlock union, its constructor, defaults and data behaviour, grouped by layout, content, data, chart, map, record and module.
type: reference
audience: [expert, agent]
status: stable
search: {boost: 2}
---

# Blocks

A block is a `const` description of one piece of a custom screen, a list header or an overlay body. This page lists all 47 block classes with their constructors, parameter defaults and what each one reads. The guides under [Blocks and charts](../blocks/index.md) teach when to use which.

## Import

```dart
import 'package:beak/panel.dart';
```

`package:beak/panel.dart` re-exports the blocks, `BeakBlockHost`, the chart data types and everything a block parameter names (`BeakModel`, `BeakColumn`, `BeakQuerySpec`). It pulls in Flutter. Server code and model files import `package:beak/beak.dart` instead, which has no blocks.

## Summary

`BeakBlock` is sealed and all 47 subclasses live in `packages/beak_frontend/lib/src/blocks/`. `Reads` says where a block gets its data: `none` (configuration only), `query` (a `BeakQuerySpec` you pass), `model` (the first 500 rows of `model`), `record` (one row by `recordId`), `scope` (the record in the nearest `BeakRecordScope`), `aggregate` (one aggregate request) and `summary` (one grouped summary request).

| Block | Group | Renders onto | Reads | Refetches after a write |
| --- | --- | --- | --- | --- |
| [`BeakColumnBlock`](#beakcolumnblock) | layout | `OiColumn` | none | n/a |
| [`BeakRowBlock`](#beakrowblock) | layout | `OiRow` | none | n/a |
| [`BeakGridBlock`](#beakgridblock) | layout | `OiGrid` | none | n/a |
| [`BeakMasonryBlock`](#beakmasonryblock) | layout | `OiMasonry` | none | n/a |
| [`BeakCardBlock`](#beakcardblock) | layout | `OiCard` | none | n/a |
| [`BeakSectionBlock`](#beaksectionblock) | layout | `OiSection` | none | n/a |
| [`BeakTabsBlock`](#beaktabsblock) | layout | `OiTabs` | none | n/a |
| [`BeakAccordionBlock`](#beakaccordionblock) | layout | `OiAccordion` | none | n/a |
| [`BeakThreePaneBlock`](#beakthreepaneblock) | layout | `OiThreeColumnLayout` | none | n/a |
| [`BeakSpacerBlock`](#beakspacerblock) | layout | `SizedBox` | none | n/a |
| [`BeakDividerBlock`](#beakdividerblock) | layout | `OiDivider` | none | n/a |
| [`BeakWidgetBlock`](#beakwidgetblock) | layout | the widget your builder returns | none | n/a |
| [`BeakTextBlock`](#beaktextblock) | content | `OiLabel` | none | n/a |
| [`BeakMarkdownBlock`](#beakmarkdownblock) | content | `OiMarkdown` | none | n/a |
| [`BeakImageBlock`](#beakimageblock) | content | `OiImage` | none | n/a |
| [`BeakAlertBlock`](#beakalertblock) | content | `OiBanner` | none | n/a |
| [`BeakBadgeBlock`](#beakbadgeblock) | content | `OiBadge` | none | n/a |
| [`BeakProgressBlock`](#beakprogressblock) | content | `OiProgress` | none | n/a |
| [`BeakRatingBlock`](#beakratingblock) | content | `OiStarRating` | none | n/a |
| [`BeakBreadcrumbsBlock`](#beakbreadcrumbsblock) | content | `OiBreadcrumbs` | none | n/a |
| [`BeakIconGalleryBlock`](#beakicongalleryblock) | content | `OiGrid` of `OiIcon` | none | n/a |
| [`BeakRadialSliderBlock`](#beakradialsliderblock) | content | `OiRadialSlider` | none | n/a |
| [`BeakTableBlock`](#beaktableblock) | data | `BeakDataTable` | model, own paging | yes |
| [`BeakMetricBlock`](#beakmetricblock) | data | a metric card | aggregate | yes |
| [`BeakSummaryBlock`](#beaksummaryblock) | data | metrics, strip, bar, donut, table or capacity | summary | yes |
| [`BeakTimelineBlock`](#beaktimelineblock) | data | `OiTimeline` | query | no |
| [`BeakGalleryBlock`](#beakgalleryblock) | data | `OiGallery` | query | no |
| [`BeakCarouselBlock`](#beakcarouselblock) | data | `OiCarousel` | query | no |
| [`BeakVideoBlock`](#beakvideoblock) | data | `OiVideoPlayer` | query, first row | no |
| [`BeakChartBlock`](#beakchartblock) | chart | line, bar, pie, donut, area, radar or funnel chart | query | no |
| [`BeakBubbleChartBlock`](#beakbubblechartblock) | chart | `OiBubbleChart` | query | no |
| [`BeakCandlestickChartBlock`](#beakcandlestickchartblock) | chart | `OiCandlestickChart` | query | no |
| [`BeakHeatmapChartBlock`](#beakheatmapchartblock) | chart | `OiHeatmap` | query | no |
| [`BeakMapBlock`](#beakmapblock) | map | `OiVectorMap` | query | no |
| [`BeakTileMapBlock`](#beaktilemapblock) | map | `OiTileMap` | query | no |
| [`BeakFieldBlock`](#beakfieldblock) | record | the table cell renderer | scope | follows the scope |
| [`BeakFieldGroupBlock`](#beakfieldgroupblock) | record | `OiGrid` of field blocks | scope | follows the scope |
| [`BeakRelationBlock`](#beakrelationblock) | record | `BeakRelationManager` | scope, then the relation | yes |
| [`BeakCalendarBlock`](#beakcalendarblock) | module | `OiCalendar` | model | own moves only |
| [`BeakKanbanBlock`](#beakkanbanblock) | module | `OiKanban` | model | own moves only |
| [`BeakChatBlock`](#beakchatblock) | module | `OiChat` | model | own messages only |
| [`BeakInboxBlock`](#beakinboxblock) | module | folder rail, list and detail pane | model | no |
| [`BeakFileManagerBlock`](#beakfilemanagerblock) | module | `OiFileManager` | model, first 25 rows | no |
| [`BeakInvoiceBlock`](#beakinvoiceblock) | module | header, line-item table and totals | record, plus a table | line items only |
| [`BeakProfileBlock`](#beakprofileblock) | module | `OiProfilePage` | record | own edits only |
| [`BeakPricingBlock`](#beakpricingblock) | module | `OiPricingTable` | model | no |
| [`BeakFaqBlock`](#beakfaqblock) | module | `OiHelpCenter` | model | no |

Refetch is the important column when a block sits beside a form or a table on the same screen. A block marked "no" shows the data it loaded when it mounted. [Data loading](#data-loading) has the details.

## Shared by every block

Every block extends `BeakBlock`, which carries one field.

```dart title="packages/beak_frontend/lib/src/blocks/beak_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_block.dart:BeakBlock"
```

`span` is read by the parent. A `BeakGridBlock` reads it as the tracks the child covers, an expanded `BeakRowBlock` reads `columns` as a relative width weight, and every other parent ignores it. Every constructor below accepts `super.span`, so the parameter tables omit it.

```dart title="packages/beak_frontend/lib/src/blocks/beak_block.dart"
const BeakSpan({this.columns = 1, this.rows = 1})
  : assert(columns >= 1, 'columns must be >= 1'),
    assert(rows >= 1, 'rows must be >= 1');
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `columns` | `int` | `1` | Number of grid columns covered. |
| `rows` | `int` | `1` | Number of grid rows covered. |

Blocks carry no other shared parameter: no id, no visibility rule, no permission. Visibility and authorization belong to the screen and to the server, see [Rules and limits](#rules-and-limits).

### BeakBlockHost

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
  const BeakBlockHost({required this.block, super.key});
```

`BeakBlockHost` renders one block tree with a single exhaustive `switch` over the union. Four consumers create it for you:

| Consumer | Parameter | Where |
| --- | --- | --- |
| `BeakScreen` | `body` | a custom page in the panel |
| `BeakListDefinition` | `header`, `collapsedHeader` | the top of a composed resource list |
| `BeakOverlays.modal`, `BeakOverlays.sheet` | `body` | a dialog or a bottom sheet |
| Your own widget tree | `BeakBlockHost(block: ...)` | anywhere below a `BeakPanel` scope |

## Layout blocks

Layout blocks hold other blocks and read nothing. The guide is [Layout blocks](../blocks/layout-blocks.md).

```dart title="examples/showcase/lib/pages/layout_blocks.dart"
--8<-- "examples/showcase/lib/pages/layout_blocks.dart:gridSection"
```

### BeakColumnBlock

Stacks children vertically and stretches them to the full width.

```dart title="packages/beak_frontend/lib/src/blocks/beak_column_block.dart"
const BeakColumnBlock({
  required this.children,
  this.gapInPixels = 16,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `children` | `List<BeakBlock>` | required | The blocks to stack, top to bottom. |
| `gapInPixels` | `double` | `16` | Vertical spacing between children. |

### BeakRowBlock

Lays children out horizontally. A natural row keeps each child's intrinsic width. With `expand: true` the row shares its width by `span.columns` weights and stacks vertically when the narrowest child would fall under `minChildWidthInPixels`. An unbounded row keeps intrinsic widths either way.

```dart title="packages/beak_frontend/lib/src/blocks/beak_row_block.dart"
const BeakRowBlock({
  required this.children,
  this.gapInPixels = 16,
  this.expand = false,
  this.minChildWidthInPixels = 240,
  super.span,
}) : assert(gapInPixels >= 0),
     assert(minChildWidthInPixels >= 0);
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `children` | `List<BeakBlock>` | required | The blocks to lay out, start to end. |
| `gapInPixels` | `double` | `16` | Horizontal spacing between children. |
| `expand` | `bool` | `false` | Fills bounded horizontal space using child span columns as flex weights. Gaps are subtracted once between actual children, not imaginary tracks. Unspecified spans have weight one. Unbounded rows keep intrinsic widths. |
| `minChildWidthInPixels` | `double` | `240` | Minimum width of each expanded child before the row stacks vertically. Uses container constraints rather than the viewport breakpoint. Set zero to keep a weighted row at every width. Ignored when `expand` is false. |

### BeakGridBlock

Places children on a column grid. Give either `columns` (a fixed grid) or `minColumnWidthInPixels` (an auto-fitting grid), never both: the constructor asserts. A fixed grid collapses to one column when any child, at its declared span, would come out narrower than `minChildWidthInPixels`. An auto-fitting grid ignores that setting.

```dart title="packages/beak_frontend/lib/src/blocks/beak_grid_block.dart"
const BeakGridBlock({
  required this.children,
  this.columns,
  this.minColumnWidthInPixels,
  this.minChildWidthInPixels = 240,
  this.gapInPixels = 16,
  super.span,
}) : assert(
       columns == null || minColumnWidthInPixels == null,
       'Provide either columns or minColumnWidthInPixels, not both.',
     ),
     assert(minChildWidthInPixels >= 0);
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `children` | `List<BeakBlock>` | required | The blocks to place, in reading order. |
| `columns` | `int?` | `null` | Fixed number of grid columns, when set. |
| `minColumnWidthInPixels` | `double?` | `null` | Minimum column width for an auto-fitting grid, when set. |
| `minChildWidthInPixels` | `double` | `240` | Minimum readable child width before a fixed grid stacks in one column. Uses available container width, declared spans, and gaps. Set to zero to retain fixed tracks at every width. Auto-fitting grids use `minColumnWidthInPixels` instead and ignore this setting. |
| `gapInPixels` | `double` | `16` | Spacing between grid tracks. |

### BeakMasonryBlock

Distributes children across vertical columns and packs each column top down.

```dart title="packages/beak_frontend/lib/src/blocks/beak_masonry_block.dart"
const BeakMasonryBlock({
  required this.children,
  this.columns = 3,
  this.gapInPixels = 16,
  super.span,
}) : assert(columns >= 1, 'columns must be >= 1');
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `children` | `List<BeakBlock>` | required | The blocks to distribute. |
| `columns` | `int` | `3` | Number of vertical columns. |
| `gapInPixels` | `double` | `16` | Spacing between columns and items. |

### BeakCardBlock

Wraps one child in a card with an optional title, subtitle and footer block. Without a title and a subtitle the header gap has no effect.

```dart title="packages/beak_frontend/lib/src/blocks/beak_card_block.dart"
const BeakCardBlock({
  required this.child,
  this.title,
  this.subtitle,
  this.headerGapInPixels = 16,
  this.footer,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `child` | `BeakBlock` | required | The card body. |
| `title` | `String?` | `null` | Header title text. |
| `subtitle` | `String?` | `null` | Header subtitle text, shown under `title`. |
| `headerGapInPixels` | `double` | `16` | Space after the header; ignored when no header is declared. |
| `footer` | `BeakBlock?` | `null` | Footer content, separated from the body. |

### BeakSectionBlock

A heading (and optional description) above one child.

```dart title="packages/beak_frontend/lib/src/blocks/beak_section_block.dart"
const BeakSectionBlock({
  required this.title,
  required this.child,
  this.description,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | `String` | required | The section heading. |
| `child` | `BeakBlock` | required | The section body. |
| `description` | `String?` | `null` | Supporting copy under the heading. |

### BeakTabsBlock

A tab bar with the selected tab's content below it. The selected index is state of the host, so it survives a rebuild of the parent. `tabs` must not be empty (see [Rules and limits](#rules-and-limits)).

```dart title="packages/beak_frontend/lib/src/blocks/beak_tabs_block.dart"
const BeakTabsBlock({required this.tabs, this.initialIndex = 0, super.span});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `tabs` | `List<BeakTabBlockItem>` | required | The tabs, in display order. |
| `initialIndex` | `int` | `0` | Index of the tab selected on first build. |

#### BeakTabBlockItem

```dart title="packages/beak_frontend/lib/src/blocks/beak_tabs_block.dart"
const BeakTabBlockItem({
  required this.label,
  required this.content,
  this.icon,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `label` | `String` | required | The tab label. |
| `content` | `BeakBlock` | required | Content rendered while this tab is selected. |
| `icon` | `IconData?` | `null` | Icon shown before the label. |

### BeakAccordionBlock

Vertically stacked expandable sections.

```dart title="packages/beak_frontend/lib/src/blocks/beak_accordion_block.dart"
const BeakAccordionBlock({
  required this.items,
  this.allowMultiple = false,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `items` | `List<BeakAccordionBlockItem>` | required | The expandable sections, in display order. |
| `allowMultiple` | `bool` | `false` | Whether several sections may be open at once. |

#### BeakAccordionBlockItem

```dart title="packages/beak_frontend/lib/src/blocks/beak_accordion_block.dart"
const BeakAccordionBlockItem({
  required this.title,
  required this.content,
  this.initiallyExpanded = false,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | `String` | required | The always-visible section header. |
| `content` | `BeakBlock` | required | Content revealed when the section expands. |
| `initiallyExpanded` | `bool` | `false` | Whether the section starts expanded. |

### BeakThreePaneBlock

A resizable three-pane layout for navigation, list and detail. `right` is optional; without it the third pane is hidden.

```dart title="packages/beak_frontend/lib/src/blocks/beak_three_pane_block.dart"
const BeakThreePaneBlock({
  required this.label,
  required this.left,
  required this.middle,
  this.right,
  this.leftWidthInPixels = 260,
  this.rightWidthInPixels = 320,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `label` | `String` | required | Accessibility label describing the layout (e.g. `'Inbox'`). |
| `left` | `BeakBlock` | required | The narrow start pane (folders, contacts, filters). |
| `middle` | `BeakBlock` | required | The main middle pane. |
| `right` | `BeakBlock?` | `null` | The optional end pane (detail, preview). |
| `leftWidthInPixels` | `double` | `260` | Initial width of the start pane. |
| `rightWidthInPixels` | `double` | `320` | Initial width of the end pane. |

### BeakSpacerBlock

Fixed vertical whitespace.

```dart title="packages/beak_frontend/lib/src/blocks/beak_spacer_block.dart"
const BeakSpacerBlock({this.heightInPixels = 16, super.span});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `heightInPixels` | `double` | `16` | The whitespace height. |

### BeakDividerBlock

A horizontal rule, with centred text when `label` is set.

```dart title="packages/beak_frontend/lib/src/blocks/beak_divider_block.dart"
const BeakDividerBlock({this.label, super.span});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `label` | `String?` | `null` | Text centred in the divider line, when set. |

### BeakWidgetBlock

The escape hatch: embeds any widget subtree. It is the only block that carries arbitrary code, so it gives up the declarative guarantees the rest of the union keeps. Use a typed block whenever one exists.

```dart title="packages/beak_frontend/lib/src/blocks/beak_widget_block.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_widget_block.dart:BeakWidgetBlock"
```

```dart title="packages/beak_frontend/lib/src/blocks/beak_widget_block.dart"
const BeakWidgetBlock(this.builder, {super.span});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `builder` | `WidgetBuilder` | required (positional) | Builds the embedded subtree. |

## Content blocks

Content blocks render what their constructor holds and read no data. The guide is [Content blocks](../blocks/content-blocks.md).

```dart title="examples/showcase/lib/pages/content_blocks.dart"
--8<-- "examples/showcase/lib/pages/content_blocks.dart:alerts"
```

### BeakTextBlock

A run of themed text. `text` is positional.

```dart title="packages/beak_frontend/lib/src/blocks/beak_text_block.dart"
const BeakTextBlock(
  this.text, {
  this.variant = BeakTextVariant.body,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `text` | `String` | required (positional) | The text to show. |
| `variant` | `BeakTextVariant` | `BeakTextVariant.body` | The typographic variant. |

### BeakMarkdownBlock

Rendered Markdown for long-form copy such as terms or a changelog. `source` is positional.

```dart title="packages/beak_frontend/lib/src/blocks/beak_markdown_block.dart"
const BeakMarkdownBlock(this.source, {super.span});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `source` | `String` | required (positional) | The raw Markdown source. |

### BeakImageBlock

An image loaded from a URL, with the panel's placeholder and error states. `url` is positional, `alt` is required.

```dart title="packages/beak_frontend/lib/src/blocks/beak_image_block.dart"
const BeakImageBlock(
  this.url, {
  required this.alt,
  this.widthInPixels,
  this.heightInPixels,
  this.fit = BoxFit.cover,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `url` | `String` | required (positional) | The image source URL. |
| `alt` | `String` | required | Accessibility description of the image. |
| `widthInPixels` | `double?` | `null` | Fixed render width, when set. |
| `heightInPixels` | `double?` | `null` | Fixed render height, when set. |
| `fit` | `BoxFit` | `BoxFit.cover` | How the image fills its box. |

### BeakAlertBlock

An inline banner at one of four severities. `message` is positional. The banner keeps the obers_ui default of a close button that hides it for the life of the widget; the dismissal is not stored.

```dart title="packages/beak_frontend/lib/src/blocks/beak_alert_block.dart"
const BeakAlertBlock(
  this.message, {
  this.level = BeakAlertLevel.info,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `message` | `String` | required (positional) | The alert text. |
| `level` | `BeakAlertLevel` | `BeakAlertLevel.info` | The severity. |

### BeakBadgeBlock

A soft coloured pill. `label` is positional. `BeakColor.secondary` renders as the accent colour and `BeakColor.muted` as the neutral one.

```dart title="packages/beak_frontend/lib/src/blocks/beak_badge_block.dart"
const BeakBadgeBlock(
  this.label, {
  this.color = BeakColor.primary,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `label` | `String` | required (positional) | The badge text. |
| `color` | `BeakColor` | `BeakColor.primary` | The badge color. |

### BeakProgressBlock

A linear progress bar. `value` is a fraction from 0 to 1.

```dart title="packages/beak_frontend/lib/src/blocks/beak_progress_block.dart"
const BeakProgressBlock({required this.value, this.label, super.span});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `value` | `double` | required | Fill fraction in the range 0..1. |
| `label` | `String?` | `null` | An optional caption shown above the bar. |

### BeakRatingBlock

A star rating that allows half stars. It is display-only by default. There is no change callback, so `readOnly: false` has no way to hand a value back.

```dart title="packages/beak_frontend/lib/src/blocks/beak_rating_block.dart"
const BeakRatingBlock({
  required this.value,
  this.maxStars = 5,
  this.readOnly = true,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `value` | `double` | required | The current rating. |
| `maxStars` | `int` | `5` | The number of stars. |
| `readOnly` | `bool` | `true` | Whether the rating is display-only. |

### BeakBreadcrumbsBlock

A breadcrumb trail. A crumb with a `route` navigates through the panel's router (`GoRouter.go`) when tapped.

```dart title="packages/beak_frontend/lib/src/blocks/beak_breadcrumbs_block.dart"
const BeakBreadcrumbsBlock({required this.items, super.span});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `items` | `List<BeakBreadcrumbBlockItem>` | required | The trail, root first. |

#### BeakBreadcrumbBlockItem

```dart title="packages/beak_frontend/lib/src/blocks/beak_breadcrumbs_block.dart"
const BeakBreadcrumbBlockItem({required this.label, this.route});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `label` | `String` | required | The crumb text. |
| `route` | `String?` | `null` | Panel route navigated to on tap, when set. |

### BeakIconGalleryBlock

A reference grid of named icons. Each cell shows the icon with its label beneath.

```dart title="packages/beak_frontend/lib/src/blocks/beak_icon_gallery_block.dart"
const BeakIconGalleryBlock({
  required this.items,
  this.columns = 6,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `items` | `List<BeakIconGalleryItem>` | required | The icons to display. |
| `columns` | `int` | `6` | The number of grid columns. |

#### BeakIconGalleryItem

`BeakIconToken` is an extension type over `IconData`, declared in `packages/beak_frontend/lib/src/panel/beak_resource.dart`.

```dart title="packages/beak_frontend/lib/src/blocks/beak_icon_gallery_block.dart"
const BeakIconGalleryItem({required this.icon, required this.label});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `icon` | `BeakIconToken` | required | The icon to display. |
| `label` | `String` | required | The name shown beneath the icon. |

### BeakRadialSliderBlock

An interactive knob. It keeps its value locally and has no binding, so it is a showcase control and not an input.

```dart title="packages/beak_frontend/lib/src/blocks/beak_radial_slider_block.dart"
const BeakRadialSliderBlock({
  required this.label,
  this.min = 0,
  this.max = 100,
  this.initialValue = 40,
  this.sizeInPixels = 200,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `label` | `String` | required | The control label. |
| `min` | `double` | `0` | The minimum value. |
| `max` | `double` | `100` | The maximum value. |
| `initialValue` | `double` | `40` | The value the knob starts at. |
| `sizeInPixels` | `double` | `200` | The rendered diameter. |

## Data blocks

Data blocks fetch through the panel's `BeakDataSource`. The guides are [Data blocks](../blocks/data-blocks.md) and [Population summaries](../blocks/summaries.md).

```dart title="examples/showcase/lib/pages/data_blocks.dart"
--8<-- "examples/showcase/lib/pages/data_blocks.dart:metrics"
```

### BeakTableBlock

A full `BeakDataTable` on a page: server-side sort, filter and pagination, row actions and the built-in delete. `fields` picks exact fields, including typed relationship paths, and wins over `columns`. `initialSpec` seeds order and page size, `baseFilter` is AND-merged into every query. The table needs a bounded height, so it takes `heightInPixels`.

```dart title="packages/beak_frontend/lib/src/blocks/beak_table_block.dart"
const BeakTableBlock({
  required this.model,
  this.title,
  this.columns,
  this.fields,
  this.enableDelete = true,
  this.initialSpec,
  this.baseFilter,
  this.actions = const [],
  this.onRowTap,
  this.heightInPixels = 360,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `model` | `BeakModel` | required | The model whose rows the table lists. |
| `title` | `String?` | `null` | Optional heading shown above the table. |
| `columns` | `List<BeakColumn>?` | `null` | The columns to show, in order; defaults to the model's table-context columns. A card on a page is not a list page: three columns read at a glance where seventeen do not fit at all. |
| `fields` | `List<BeakScalarField<Object>>?` | `null` | Exact ordered fields, including typed relationship paths and formatting. Takes precedence over `columns` and suppresses automatic relation columns. |
| `enableDelete` | `bool` | `true` | Adds the built-in delete action. Disable for read-only embedded listings. Custom `actions` remain available independently. |
| `initialSpec` | `BeakQuerySpec?` | `null` | Seeds sort order and page size on first load. |
| `baseFilter` | `BeakFilter?` | `null` | A filter AND-merged into every query (e.g. status scope). |
| `actions` | `List<BeakTableAction>` | `const []` | Extra per-row actions. |
| `onRowTap` | `void Function(BeakRecord record)?` | `null` | Invoked when a row is tapped. |
| `heightInPixels` | `double` | `360` | Bounded render height, so the table lays out inside a grid cell or card (which otherwise impose no vertical bound). |

### BeakMetricBlock

One number: a live aggregate, optionally compared with a prior period and a target. Numbers go through the panel's format policy (`BeakFormatting`), so `BeakValueFormat.currency` uses the panel currency. A minor-unit sum, such as cents, sets `minorUnits: true`. The block shows a loading state and a retry when the request fails, and refetches after writes to the aggregated tables.

```dart title="packages/beak_frontend/lib/src/blocks/beak_metric_block.dart"
const BeakMetricBlock({
  required this.label,
  required this.aggregate,
  this.icon,
  this.format = BeakValueFormat.number,
  this.minorUnits = false,
  this.scale = 2,
  this.unit,
  this.previous,
  this.target,
  super.span,
}) : assert(scale >= 0 && scale <= 12, 'scale must be between 0 and 12'),
     assert(
       format == BeakValueFormat.number ||
           format == BeakValueFormat.currency ||
           format == BeakValueFormat.percent,
       'format must be number, currency or percent',
     );
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `label` | `String` | required | The metric caption. |
| `aggregate` | `BeakAggregateSpec` | required | The aggregate producing the value. |
| `icon` | `IconData?` | `null` | An optional leading icon. |
| `format` | `BeakValueFormat` | `BeakValueFormat.number` | How the value (and `target`) are displayed: `BeakValueFormat.number`, `BeakValueFormat.currency` in the panel's currency, or `BeakValueFormat.percent` for a fractional rate. No other format is accepted. |
| `minorUnits` | `bool` | `false` | Whether the aggregate is in integer minor units such as cents. Aggregates return physical storage units, so a sum over a money field stored in cents sets this to display major units. |
| `scale` | `int` | `2` | Decimal places in minor-unit storage (2 for cents, 4 for basis points). |
| `unit` | `String?` | `null` | An optional unit shown after the value and `target`, separated by a space (`'kg'` renders `12 kg`). |
| `previous` | `BeakAggregateSpec?` | `null` | The prior period's aggregate; when set, the card shows the percentage change from it to `aggregate`. |
| `target` | `num?` | `null` | An optional goal in the aggregate's own units, drawn as a progress track. |

### BeakSummaryBlock

A bounded server summary bound to the surrounding list scope. `scope` decides what it inherits from a composed list: `active` (permanent, preset and user filters and search, never the page), `base` (permanent application scope only) or `standalone` (only its own query). Aggregate typing lives in [Queries](queries.md#summaries).

```dart title="packages/beak_frontend/lib/src/blocks/beak_summary_block.dart"
const BeakSummaryBlock({
  required this.title,
  required this.query,
  required this.values,
  this.presentation = BeakSummaryPresentation.metrics,
  this.scope = BeakSummaryScope.active,
  this.heightInPixels = 240,
  this.subtitle,
  this.footer,
  this.groupStyle,
  this.groupOrder = const [],
  this.showTableToggle = false,
  this.showValues = false,
  this.centerLabel,
  this.maximum,
  this.divisions,
  this.capacity,
  this.legend = const [],
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | `String` | required | Accessible panel and chart title. |
| `query` | `BeakSummarySpec` | required | Whole-population query, independent of the visible table page. Its `groupBy` field is also what formats each group's label (enum labels, dates), so the grouping is declared once. |
| `values` | `List<BeakSummaryValue>` | required | Ordered measures and their formats. |
| `presentation` | `BeakSummaryPresentation` | `BeakSummaryPresentation.metrics` | Chart or summary presentation. |
| `scope` | `BeakSummaryScope` | `BeakSummaryScope.active` | Which surrounding query constraints are inherited. |
| `heightInPixels` | `double` | `240` | Bounded chart height in logical pixels. |
| `subtitle` | `String?` | `null` | Text below the heading. |
| `footer` | `String Function(BeakSummaryResult summary)?` | `null` | Contextual footer computed from the full summary, never the visible page. |
| `groupStyle` | `BeakSummaryGroupStyle Function(BeakSummaryRow row)?` | `null` | Pure group presentation; it cannot change counts or query scope. |
| `groupOrder` | `List<Object>` | `const []` | Raw group values in display order; unspecified groups follow server order. |
| `showTableToggle` | `bool` | `false` | Accessible chart/table switch over the same loaded result. |
| `showValues` | `bool` | `false` | Shows measure values above bars. |
| `centerLabel` | `String?` | `null` | Label below the authoritative first-measure total in a donut center. |
| `maximum` | `double?` | `null` | Optional fixed value-axis maximum and number of divisions. |
| `divisions` | `int?` | `null` | Number of equal divisions on the value axis. |
| `capacity` | `BeakSummaryCapacity?` | `null` | Required when `presentation` is `BeakSummaryPresentation.capacity`. |
| `legend` | `List<BeakSummaryLegend>` | `const []` | Optional chart key displayed above the data. |

#### BeakSummaryValue

```dart title="packages/beak_frontend/lib/src/blocks/beak_summary_block.dart"
const BeakSummaryValue({
  required this.measure,
  required this.label,
  this.format = BeakValueFormat.number,
  this.minorUnits = false,
  this.scale = 2,
  this.color,
  this.icon,
  this.iconColor,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `measure` | `BeakSummaryMeasure` | required | Same measure object declared in the summary query. |
| `label` | `String` | required | Human-readable label. |
| `format` | `BeakValueFormat` | `BeakValueFormat.number` | Panel display formatting. |
| `minorUnits` | `bool` | `false` | Whether integer values store minor currency units. |
| `scale` | `int` | `2` | Number of decimal places in minor-unit storage. |
| `color` | `Color?` | `null` | Optional series color, also used for conditional metric donut segments. |
| `icon` | `IconData?` | `null` | Optional semantic marker in compact operational metric strips. |
| `iconColor` | `BeakColor?` | `null` | Theme color of the metric marker; omitted values use muted text. |

#### BeakSummaryCapacity

```dart title="packages/beak_frontend/lib/src/blocks/beak_summary_block.dart"
const BeakSummaryCapacity({
  required this.used,
  required this.total,
  this.warningThreshold = .95,
  this.warning,
  this.warningColor,
  this.trackHeightInPixels = 6,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `used` | `BeakSummaryMeasure` | required | Booked/consumed measure. |
| `total` | `BeakSummaryMeasure` | required | Maximum available measure. |
| `warningThreshold` | `double` | `.95` | Utilization ratio at which the warning treatment is applied. |
| `warning` | `String? Function(BeakSummaryRow row)?` | `null` | Optional explanation evaluated against the authoritative grouped row. |
| `warningColor` | `Color?` | `null` | Optional chart color for near-capacity tracks. |
| `trackHeightInPixels` | `double` | `6` | Height of the shared capacity track in logical pixels. |

#### BeakSummaryGroupStyle

```dart title="packages/beak_frontend/lib/src/blocks/beak_summary_block.dart"
const BeakSummaryGroupStyle({
  this.label,
  this.section,
  this.color,
  this.hatched = false,
  this.emphasized = false,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `label` | `String?` | `null` | Optional concise label, for example a day number. |
| `section` | `String?` | `null` | Optional second-level axis label, for example a calendar week. |
| `color` | `Color?` | `null` | Semantic group color, shared by the chart and its legend. |
| `hatched` | `bool` | `false` | Differentiates planned quantities using a diagonal pattern. |
| `emphasized` | `bool` | `false` | Emphasizes this category and displays its value above the bar. |

#### BeakSummaryLegend

```dart title="packages/beak_frontend/lib/src/blocks/beak_summary_block.dart"
const BeakSummaryLegend({
  required this.label,
  required this.color,
  this.hatched = false,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `label` | `String` | required | Human-readable meaning. |
| `color` | `Color` | required | Marker color from the application theme. |
| `hatched` | `bool` | `false` | Diagonal pattern, also used by forecast bars and free capacity tracks. |

### BeakTimelineBlock

A vertical timeline, one event per row.

```dart title="packages/beak_frontend/lib/src/blocks/beak_timeline_block.dart"
const BeakTimelineBlock({
  required this.query,
  required this.titleField,
  required this.timeField,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `query` | `BeakQuerySpec` | required | The query producing one row per event. |
| `titleField` | `BeakColumn` | required | The column holding each event's title. |
| `timeField` | `BeakColumn` | required | The column holding each event's timestamp. |

### BeakGalleryBlock

An image gallery, one thumbnail per row.

```dart title="packages/beak_frontend/lib/src/blocks/beak_gallery_block.dart"
const BeakGalleryBlock({
  required this.query,
  required this.imageUrlField,
  this.captionField,
  this.columns = 4,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `query` | `BeakQuerySpec` | required | The query producing one row per image. |
| `imageUrlField` | `BeakColumn` | required | The column holding each image's URL. |
| `captionField` | `BeakColumn?` | `null` | The column holding each image's caption, if any. |
| `columns` | `int` | `4` | The number of columns. |

### BeakCarouselBlock

A slide per row, with arrows and indicators.

```dart title="packages/beak_frontend/lib/src/blocks/beak_carousel_block.dart"
const BeakCarouselBlock({
  required this.query,
  required this.imageUrlField,
  this.captionField,
  this.heightInPixels = 320,
  this.autoplay = true,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `query` | `BeakQuerySpec` | required | The query producing one row per slide. |
| `imageUrlField` | `BeakColumn` | required | The column holding each slide's image URL. |
| `captionField` | `BeakColumn?` | `null` | The column holding each slide's caption, if any. |
| `heightInPixels` | `double` | `320` | Rendered height. |
| `autoplay` | `bool` | `true` | Whether the carousel advances on its own. |

### BeakVideoBlock

A video player over the first row of `query`.

```dart title="packages/beak_frontend/lib/src/blocks/beak_video_block.dart"
const BeakVideoBlock({
  required this.query,
  required this.urlField,
  this.posterField,
  this.title,
  this.autoPlay = false,
  this.loop = false,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `query` | `BeakQuerySpec` | required | The query whose first row supplies the video. |
| `urlField` | `BeakColumn` | required | The column holding the video source URL. |
| `posterField` | `BeakColumn?` | `null` | The column holding an optional poster image URL. |
| `title` | `String?` | `null` | An accessible label / caption for the player. |
| `autoPlay` | `bool` | `false` | Whether the video starts playing automatically. |
| `loop` | `bool` | `false` | Whether the video loops. |

## Chart blocks

Chart blocks run a query and map its rows to a typed point list. The mapper is a plain function over `List<BeakRecord>` that reads fields through generated references, so no string key appears. The guide is [Charts](../blocks/charts.md).

```dart title="examples/showcase/lib/pages/chart_blocks.dart"
--8<-- "examples/showcase/lib/pages/chart_blocks.dart:chart"
```

```dart title="examples/showcase/lib/pages/chart_data.dart"
--8<-- "examples/showcase/lib/pages/chart_data.dart:sightingPoints"
```

### BeakChartBlock

One block for the seven families of `BeakChartType`. Every family maps from the same `BeakChartPoint` list; bubble, candlestick and heatmap charts have their own blocks because their points have another shape.

```dart title="packages/beak_frontend/lib/src/blocks/beak_chart_block.dart"
const BeakChartBlock({
  required this.title,
  required this.type,
  required this.query,
  required this.map,
  this.heightInPixels = 260,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | `String` | required | The chart heading. |
| `type` | `BeakChartType` | required | The chart family. |
| `query` | `BeakQuerySpec` | required | The query producing the chart's records. |
| `map` | `BeakChartMapper` | required | The typed record→point mapping. |
| `heightInPixels` | `double` | `260` | Rendered height (charts need bounded constraints). |

```dart title="packages/beak_frontend/lib/src/blocks/beak_chart_data.dart"
--8<-- "packages/beak_frontend/lib/src/blocks/beak_chart_data.dart:BeakChartMapper"
```

#### BeakChartPoint

```dart title="packages/beak_frontend/lib/src/blocks/beak_chart_data.dart"
const BeakChartPoint({required this.label, required this.value, this.x});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `label` | `String` | required | The category/point label. |
| `value` | `double` | required | The measured value. |
| `x` | `double?` | `null` | Explicit x position for line/area charts, if any. |

### BeakBubbleChartBlock

An (x, y) point sized by a third value. The mapper type is `BeakBubbleMapper`, a `List<BeakBubblePoint> Function(List<BeakRecord> records)`.

```dart title="packages/beak_frontend/lib/src/blocks/beak_bubble_chart_block.dart"
const BeakBubbleChartBlock({
  required this.title,
  required this.query,
  required this.map,
  this.heightInPixels = 300,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | `String` | required | The chart heading. |
| `query` | `BeakQuerySpec` | required | The query supplying the records. |
| `map` | `BeakBubbleMapper` | required | Maps the records to bubble points. |
| `heightInPixels` | `double` | `300` | The chart height in pixels. |

#### BeakBubblePoint

```dart title="packages/beak_frontend/lib/src/blocks/beak_chart_data.dart"
const BeakBubblePoint({
  required this.x,
  required this.y,
  required this.size,
  this.label,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `x` | `double` | required | The horizontal position. |
| `y` | `double` | required | The vertical position. |
| `size` | `double` | required | The bubble's magnitude (its area encodes this). |
| `label` | `String?` | `null` | An optional label for the point. |

### BeakCandlestickChartBlock

An open, high, low, close chart. The mapper type is `BeakCandleMapper`, a `List<BeakCandle> Function(List<BeakRecord> records)`.

```dart title="packages/beak_frontend/lib/src/blocks/beak_candlestick_chart_block.dart"
const BeakCandlestickChartBlock({
  required this.title,
  required this.query,
  required this.map,
  this.heightInPixels = 320,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | `String` | required | The chart heading. |
| `query` | `BeakQuerySpec` | required | The query supplying the records. |
| `map` | `BeakCandleMapper` | required | Maps the records to OHLC candles. |
| `heightInPixels` | `double` | `320` | The chart height in pixels. |

#### BeakCandle

```dart title="packages/beak_frontend/lib/src/blocks/beak_chart_data.dart"
const BeakCandle({
  required this.x,
  required this.open,
  required this.high,
  required this.low,
  required this.close,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `x` | `double` | required | The horizontal position (e.g. a day index or epoch millis). |
| `open` | `double` | required | The opening price. |
| `high` | `double` | required | The session high. |
| `low` | `double` | required | The session low. |
| `close` | `double` | required | The closing price. |

### BeakHeatmapChartBlock

A heatmap over a row by column matrix. Without `rowLabels` and `columnLabels` the order is inferred from the cells. The mapper type is `BeakMatrixMapper`, a `List<BeakMatrixCell> Function(List<BeakRecord> records)`.

```dart title="packages/beak_frontend/lib/src/blocks/beak_heatmap_chart_block.dart"
const BeakHeatmapChartBlock({
  required this.title,
  required this.query,
  required this.map,
  this.rowLabels,
  this.columnLabels,
  this.heightInPixels = 320,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | `String` | required | The chart heading. |
| `query` | `BeakQuerySpec` | required | The query supplying the records. |
| `map` | `BeakMatrixMapper` | required | Maps the records to matrix cells. |
| `rowLabels` | `List<String>?` | `null` | An explicit row order, if any (otherwise inferred from the cells). |
| `columnLabels` | `List<String>?` | `null` | An explicit column order, if any (otherwise inferred from the cells). |
| `heightInPixels` | `double` | `320` | The chart height in pixels. |

#### BeakMatrixCell

```dart title="packages/beak_frontend/lib/src/blocks/beak_chart_data.dart"
const BeakMatrixCell({
  required this.row,
  required this.column,
  required this.value,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `row` | `String` | required | The row key. |
| `column` | `String` | required | The column key. |
| `value` | `double` | required | The cell's magnitude. |

## Map blocks

The guide is [Maps](../blocks/maps.md).

```dart title="examples/showcase/lib/pages/map_blocks.dart"
--8<-- "examples/showcase/lib/pages/map_blocks.dart:choropleth"
```

### BeakMapBlock

A choropleth world map. Each row is a region: `regionCodeField` holds an ISO 3166-1 alpha-2 code and `valueField` drives the shade. The geometry is bundled with obers_ui.

```dart title="packages/beak_frontend/lib/src/blocks/beak_map_block.dart"
const BeakMapBlock({
  required this.title,
  required this.query,
  required this.regionCodeField,
  required this.valueField,
  this.valueLabel = 'Value',
  this.heightInPixels = 320,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | `String` | required | The card heading. |
| `query` | `BeakQuerySpec` | required | The query producing one row per region. |
| `regionCodeField` | `BeakColumn` | required | The column holding each row's ISO 3166-1 alpha-2 region code. |
| `valueField` | `BeakColumn` | required | The column holding each row's value (drives the shade). |
| `valueLabel` | `String` | `'Value'` | The tooltip/legend caption for the value. |
| `heightInPixels` | `double` | `320` | Rendered height (the map needs bounded constraints). |

### BeakTileMapBlock

A raster tile map with one pin per row. The centre defaults to the first marker. The default tile server is the public OpenStreetMap one, so point `tileUrlTemplate` at your own tiles for production traffic.

```dart title="packages/beak_frontend/lib/src/blocks/beak_tile_map_block.dart"
const BeakTileMapBlock({
  required this.title,
  required this.query,
  required this.latitudeField,
  required this.longitudeField,
  this.labelField,
  this.centerLatitude,
  this.centerLongitude,
  this.zoom = 3,
  this.tileUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  this.heightInPixels = 360,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | `String` | required | The card heading. |
| `query` | `BeakQuerySpec` | required | The query supplying the marker rows. |
| `latitudeField` | `BeakColumn` | required | The column holding each marker's latitude. |
| `longitudeField` | `BeakColumn` | required | The column holding each marker's longitude. |
| `labelField` | `BeakColumn?` | `null` | The column labelling each marker, if any. |
| `centerLatitude` | `double?` | `null` | The starting center latitude; defaults to the first marker. |
| `centerLongitude` | `double?` | `null` | The starting center longitude; defaults to the first marker. |
| `zoom` | `int` | `3` | The starting zoom level. |
| `tileUrlTemplate` | `String` | `'https://tile.openstreetmap.org/{z}/{x}/{y}.png'` | The `{z}/{x}/{y}` tile URL template. |
| `heightInPixels` | `double` | `360` | The map height in pixels. |

## Record blocks

Record blocks show the record in the nearest `BeakRecordScope` and hold no query. Outside a scope they render nothing and do not throw. The value is drawn by the same renderer as a table cell (`renderBeakCell`, context `BeakContext.detail`), so a badge, a date or an image looks the same in both. The guide is [Record blocks](../blocks/record-blocks.md).

```dart title="examples/showcase/lib/resources/keepers/keeper_sheet.dart"
--8<-- "examples/showcase/lib/resources/keepers/keeper_sheet.dart:keeperSheetBlock"
```

### BeakFieldBlock

One label and value. `column` is positional. `label` defaults to the column's own label.

```dart title="packages/beak_frontend/lib/src/blocks/beak_field_block.dart"
const BeakFieldBlock(
  this.column, {
  this.label,
  this.layout = BeakFieldLayout.stacked,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `column` | `BeakColumn` | required (positional) | The column to display. |
| `label` | `String?` | `null` | A label override; defaults to `BeakColumn.label`. |
| `layout` | `BeakFieldLayout` | `BeakFieldLayout.stacked` | Whether the label sits above or beside the value. |

### BeakFieldGroupBlock

Several fields in a responsive grid, each drawn as a stacked field block. `columns` is positional.

```dart title="packages/beak_frontend/lib/src/blocks/beak_field_group_block.dart"
const BeakFieldGroupBlock(this.columns, {this.columnCount = 2, super.span});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `columns` | `List<BeakColumn>` | required (positional) | The columns to display, in order. |
| `columnCount` | `int` | `2` | The number of grid columns the fields flow across. |

### BeakRelationBlock

The scoped record's related rows in the shared relation manager: a table with attach and detach where the relation allows it. It takes the parent model and id from the scope and paints from the record's eager-loaded rows when the page loaded them, otherwise it queries. `relationship` is positional.

```dart title="packages/beak_frontend/lib/src/blocks/beak_relation_block.dart"
const BeakRelationBlock(this.relationship, {this.title, super.span});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `relationship` | `BeakRelationship` | required (positional) | The relationship to render. |
| `title` | `String?` | `null` | A heading override; defaults to the relationship's own label. |

## Module blocks

Module blocks bind a whole model (or one record) to a richer obers_ui widget through typed column bindings. The guide is [Module blocks](../blocks/module-blocks.md).

```dart title="examples/showcase/lib/pages/module_blocks.dart"
--8<-- "examples/showcase/lib/pages/module_blocks.dart:chat"
```

### BeakCalendarBlock

Each row is an event. Tapping calls `onEventTap`. Dragging an event writes the new start (and end, when `endField` is bound) with an update on the row and then calls `onEventMove`. A failed write snaps the event back.

```dart title="packages/beak_frontend/lib/src/blocks/beak_calendar_block.dart"
const BeakCalendarBlock({
  required this.model,
  required this.titleField,
  required this.startField,
  this.endField,
  this.allDayField,
  this.categoryField,
  this.mode = OiCalendarMode.month,
  this.label = 'Calendar',
  this.onEventTap,
  this.onEventMove,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `model` | `BeakModel` | required | The model whose records become events. |
| `titleField` | `BeakColumn` | required | Column supplying each event's title. |
| `startField` | `BeakColumn` | required | Column supplying each event's start instant. |
| `endField` | `BeakColumn?` | `null` | Column supplying each event's end instant; falls back to `startField`. |
| `allDayField` | `BeakColumn?` | `null` | Boolean column flagging all-day events, when bound. |
| `categoryField` | `BeakColumn?` | `null` | Column categorizing events; a `BeakEnumColumn` here tints each event with its value's badge color. |
| `mode` | `OiCalendarMode` | `OiCalendarMode.month` | The initial calendar mode (day/week/month). |
| `label` | `String` | `'Calendar'` | Accessibility label for the calendar. |
| `onEventTap` | `void Function(BeakRecord record)?` | `null` | Invoked with the tapped event's record. |
| `onEventMove` | `void Function(BeakRecord record, DateTime start, DateTime end)?` | `null` | Invoked after an event is dragged to a new range; the block first persists the move through the data source. |

### BeakKanbanBlock

One column per value of an enum field, each holding the rows whose `groupField` matches. Column titles and colours come from the enum's labels and badge colours. Dropping a card writes the new enum value with an update and then calls `onCardMove`. `groupField` must be an enum field of `model` itself; `groupColumn` throws a `BeakConfigurationException` otherwise.

```dart title="packages/beak_frontend/lib/src/blocks/beak_kanban_block.dart"
const BeakKanbanBlock({
  required this.model,
  required this.groupField,
  required this.titleField,
  this.subtitleField,
  this.sortField,
  this.sortDescending = false,
  this.label = 'Board',
  this.onCardMove,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `model` | `BeakModel` | required | The model whose records become cards. |
| `groupField` | `BeakScalarField<Enum>` | required | The enum field whose values define the board's columns. |
| `titleField` | `BeakColumn` | required | Column supplying each card's title. |
| `subtitleField` | `BeakColumn?` | `null` | Column supplying each card's subtitle, when bound. |
| `sortField` | `BeakColumn?` | `null` | Column ordering the cards within each column, when bound. Without it the card order is whatever the data source returns. |
| `sortDescending` | `bool` | `false` | Whether `sortField` orders descending. |
| `label` | `String` | `'Board'` | Accessibility label for the board. |
| `onCardMove` | `void Function(BeakRecord record)?` | `null` | Invoked with a card's record after it is dropped in a new column; the block first persists the new group through the data source. |

### BeakChatBlock

A transcript of message bubbles sorted by `timeField`. Rows where `isMineField` is true sit on the outgoing side. With `composeRecord` bound, the block shows a composer and creates the row it returns; without it the transcript is read-only.

```dart title="packages/beak_frontend/lib/src/blocks/beak_chat_block.dart"
const BeakChatBlock({
  required this.model,
  required this.authorField,
  required this.bodyField,
  required this.timeField,
  this.isMineField,
  this.composeRecord,
  this.label = 'Chat',
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `model` | `BeakModel` | required | The model whose records become messages. |
| `authorField` | `BeakColumn` | required | Column supplying each message's author name. |
| `bodyField` | `BeakColumn` | required | Column supplying each message's body text. |
| `timeField` | `BeakColumn` | required | Column supplying each message's timestamp; also the sort key. |
| `isMineField` | `BeakColumn?` | `null` | Boolean column marking outgoing (own) messages, when bound. |
| `composeRecord` | `BeakRecord Function(String body)?` | `null` | Builds the record persisted when the user sends `body` from the composer, fill in the FKs and defaults a new message needs. When unbound the transcript is read-only and no composer is shown. |
| `label` | `String` | `'Chat'` | Accessibility label for the transcript. |

### BeakInboxBlock

A folder rail, a message list and a detail pane. Bind `folderRelation` with `folderLabelField` and the rail is built from the related folder labels and filters the list; without the relation, `folders` is a static rail that does not filter. Bind `unreadField` or `readField`, never both: the constructor asserts. Selection is local widget state.

```dart title="packages/beak_frontend/lib/src/blocks/beak_inbox_block.dart"
const BeakInboxBlock({
  required this.model,
  required this.senderField,
  required this.subjectField,
  this.previewField,
  this.timeField,
  this.unreadField,
  this.readField,
  this.folderRelation,
  this.folderLabelField,
  this.folders = const ['Inbox'],
  this.label = 'Inbox',
  this.leftWidthInPixels = 220,
  this.rightWidthInPixels = 360,
  super.span,
}) : assert(
       unreadField == null || readField == null,
       'Bind unreadField (true = unread) or readField (true = read), '
       'not both.',
     );
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `model` | `BeakModel` | required | The model whose records become message rows. |
| `senderField` | `BeakColumn` | required | Column supplying each row's sender. |
| `subjectField` | `BeakColumn` | required | Column supplying each row's subject. |
| `previewField` | `BeakColumn?` | `null` | Column supplying each row's preview snippet, when bound. |
| `timeField` | `BeakColumn?` | `null` | Column supplying each row's received time, when bound. |
| `unreadField` | `BeakColumn?` | `null` | Boolean column that is `true` on unread rows, when bound. |
| `readField` | `BeakColumn?` | `null` | Boolean column that is `true` on read rows, when bound, the inverse convention of `unreadField`, for models that store `is_read`. |
| `folderRelation` | `BeakToOneField?` | `null` | The to-one field from a message to its folder; when bound (with `folderLabelField`) the rail is data-driven and filters the list. |
| `folderLabelField` | `BeakColumn?` | `null` | The related folder model's label column backing the rail entries. |
| `folders` | `List<String>` | `const ['Inbox']` | The folder labels shown in the left rail when `folderRelation` is unbound (static, non-filtering), or, when it is bound, the preferred ordering of the data-driven rail. |
| `label` | `String` | `'Inbox'` | Accessibility label for the layout. |
| `leftWidthInPixels` | `double` | `220` | Initial width of the folder rail. |
| `rightWidthInPixels` | `double` | `360` | Initial width of the detail pane. |

### BeakFileManagerBlock

Folders and files from one table. Without `isFolderField` every row lists as a file. Opening an entry calls `onOpen`.

```dart title="packages/beak_frontend/lib/src/blocks/beak_file_manager_block.dart"
const BeakFileManagerBlock({
  required this.model,
  required this.nameField,
  this.isFolderField,
  this.sizeField,
  this.modifiedField,
  this.thumbnailField,
  this.label = 'Files',
  this.onOpen,
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `model` | `BeakModel` | required | The model whose records become file/folder entries. |
| `nameField` | `BeakColumn` | required | Column supplying each entry's name. |
| `isFolderField` | `BeakColumn?` | `null` | Boolean column marking folder entries, when the table has both. |
| `sizeField` | `BeakColumn?` | `null` | Integer column supplying each file's size in bytes, when bound. |
| `modifiedField` | `BeakColumn?` | `null` | Column supplying each entry's last-modified instant, when bound. |
| `thumbnailField` | `BeakColumn?` | `null` | Column supplying each file's thumbnail URL, when bound. |
| `label` | `String` | `'Files'` | Accessibility label for the manager. |
| `onOpen` | `void Function(BeakRecord record)?` | `null` | Invoked with the opened entry's record. |

### BeakInvoiceBlock

A composed document: a header (logo, details, from and to), a line-item table and a totals column. obers_ui has no invoice widget, so the block composes a header and a `BeakTableBlock` over `lineItemsModel`, scoped to the invoice through `lineItemsForeignKey`. That inner table is built with the defaults of `BeakTableBlock`, so it carries the built-in delete row action. With `toRelation` bound, the invoice is loaded through a one-row query with the relation eager-loaded and the "To" block shows `toPartyFields` of the billed party.

```dart title="packages/beak_frontend/lib/src/blocks/beak_invoice_block.dart"
const BeakInvoiceBlock({
  required this.model,
  required this.recordId,
  required this.lineItemsModel,
  required this.totalField,
  this.logoField,
  this.fromFields = const [],
  this.toFields = const [],
  this.metaFields = const [],
  this.toRelation,
  this.toPartyFields = const [],
  this.lineItemsForeignKey,
  this.subtotalField,
  this.discountField,
  this.shippingField,
  this.taxField,
  this.title = 'Invoice',
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `model` | `BeakModel` | required | The invoice header/totals model. |
| `recordId` | `Object` | required | Primary key of the invoice record. |
| `lineItemsModel` | `BeakModel` | required | The line-items model listed in the itemized table. |
| `totalField` | `BeakColumn` | required | Column supplying the grand total. |
| `logoField` | `BeakColumn?` | `null` | Column supplying the header logo URL, when bound. |
| `fromFields` | `List<BeakColumn>` | `const []` | Columns rendered in the "from" (issuer) block, in order. |
| `toFields` | `List<BeakColumn>` | `const []` | Columns rendered in the "to" (recipient) block, in order. |
| `metaFields` | `List<BeakColumn>` | `const []` | Invoice columns rendered in a "Details" block (number, status, dates), distinct from the recipient, which `toFields`/`toPartyFields` name. |
| `toRelation` | `BeakBelongsTo?` | `null` | The belongs-to relation to the billed party; when bound (with `toPartyFields`) the "To" block renders the related record's fields. |
| `toPartyFields` | `List<BeakColumn>` | `const []` | The related party model's columns rendered in the "To" block. |
| `lineItemsForeignKey` | `BeakColumn?` | `null` | The line-items foreign key scoping the itemized table to this invoice, when bound. |
| `subtotalField` | `BeakColumn?` | `null` | Column supplying the pre-adjustment subtotal, when bound. |
| `discountField` | `BeakColumn?` | `null` | Column supplying the discount total, when bound. |
| `shippingField` | `BeakColumn?` | `null` | Column supplying the shipping total, when bound. |
| `taxField` | `BeakColumn?` | `null` | Column supplying the tax total, when bound. |
| `title` | `String` | `'Invoice'` | The document heading. |

### BeakProfileBlock

One record as a profile page. The page is editable: saving name, email or bio writes an update on the record and shows the returned row.

```dart title="packages/beak_frontend/lib/src/blocks/beak_profile_block.dart"
const BeakProfileBlock({
  required this.model,
  required this.recordId,
  required this.nameField,
  this.emailField,
  this.roleField,
  this.avatarField,
  this.bioField,
  this.label = 'Profile',
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `model` | `BeakModel` | required | The model the profile record belongs to. |
| `recordId` | `Object` | required | Primary key of the profile record. |
| `nameField` | `BeakColumn` | required | Column supplying the display name. |
| `emailField` | `BeakColumn?` | `null` | Column supplying the email, when bound. |
| `roleField` | `BeakColumn?` | `null` | Column supplying the role/subtitle, when bound. |
| `avatarField` | `BeakColumn?` | `null` | Column supplying the avatar URL, when bound. |
| `bioField` | `BeakColumn?` | `null` | Column supplying the bio, when bound. |
| `label` | `String` | `'Profile'` | Accessibility label for the page. |

### BeakPricingBlock

A plans model as pricing cards. With `featuresRelation` and `featureLabelField` bound, each plan's eager-loaded feature rows become its bullet list. There is no per-plan period field: the table models the billing period itself, and `yearlyPriceField` feeds the annual price.

```dart title="packages/beak_frontend/lib/src/blocks/beak_pricing_block.dart"
const BeakPricingBlock({
  required this.model,
  required this.nameField,
  required this.priceField,
  this.yearlyPriceField,
  this.featuredField,
  this.descriptionField,
  this.ctaField,
  this.featuresRelation,
  this.featureLabelField,
  this.sortField,
  this.label = 'Pricing',
  this.currencySymbol = r'$',
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `model` | `BeakModel` | required | The plans model whose records become pricing cards. |
| `nameField` | `BeakColumn` | required | Column supplying each plan's name. |
| `priceField` | `BeakColumn` | required | Column supplying each plan's monthly price. |
| `yearlyPriceField` | `BeakColumn?` | `null` | Column supplying each plan's annual price, when bound. |
| `featuredField` | `BeakColumn?` | `null` | Boolean column flagging the recommended plan, when bound. |
| `descriptionField` | `BeakColumn?` | `null` | Column supplying each plan's description, when bound. |
| `ctaField` | `BeakColumn?` | `null` | Column supplying each plan's call-to-action label, when bound. |
| `featuresRelation` | `BeakRelationship?` | `null` | The relation whose eager-loaded records list each plan's features. |
| `featureLabelField` | `BeakColumn?` | `null` | Column read for each feature record's bullet label. |
| `sortField` | `BeakColumn?` | `null` | Column ordering the plans left-to-right, when bound. |
| `label` | `String` | `'Pricing'` | Accessibility label for the table. |
| `currencySymbol` | `String` | `r'$'` | Currency prefix shown on prices. |

### BeakFaqBlock

A model's rows as a help center with search and category grouping. `answerField` may hold Markdown.

```dart title="packages/beak_frontend/lib/src/blocks/beak_faq_block.dart"
const BeakFaqBlock({
  required this.model,
  required this.questionField,
  required this.answerField,
  this.categoryField,
  this.sortField,
  this.label = 'Help',
  super.span,
});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `model` | `BeakModel` | required | The model whose records become FAQ entries. |
| `questionField` | `BeakColumn` | required | Column supplying each entry's question. |
| `answerField` | `BeakColumn` | required | Column supplying each entry's answer (Markdown supported). |
| `categoryField` | `BeakColumn?` | `null` | Column grouping entries into categories, when bound. |
| `sortField` | `BeakColumn?` | `null` | Column ordering the entries, when bound. |
| `label` | `String` | `'Help'` | Accessibility label for the help center. |

## Enumerations

| Enum | Values | Used by |
| --- | --- | --- |
| `BeakTextVariant` | `display`, `h1`, `h2`, `h3`, `h4`, `body`, `bodyStrong`, `small`, `caption` | `BeakTextBlock.variant` |
| `BeakAlertLevel` | `info`, `success`, `warning`, `error` | `BeakAlertBlock.level` |
| `BeakFieldLayout` | `stacked`, `inline` | `BeakFieldBlock.layout` |
| `BeakChartType` | `line`, `bar`, `pie`, `donut`, `area`, `radar`, `funnel` | `BeakChartBlock.type` |
| `BeakSummaryScope` | `active`, `base`, `standalone` | `BeakSummaryBlock.scope` |
| `BeakSummaryPresentation` | `metrics`, `strip`, `bar`, `donut`, `table`, `capacity` | `BeakSummaryBlock.presentation` |
| `BeakColor` | `primary`, `secondary`, `success`, `warning`, `error`, `info`, `muted` | `BeakBadgeBlock.color`, `BeakSummaryValue.iconColor` |
| `BeakValueFormat` | `text`, `number`, `currency`, `date`, `dateTime`, `time`, `percent` | `BeakSummaryValue.format`; `BeakMetricBlock.format` accepts `number`, `currency` and `percent` only |
| `OiCalendarMode` | `day`, `week`, `month` | `BeakCalendarBlock.mode` (from obers_ui) |
| `BoxFit` | Flutter's `BoxFit` | `BeakImageBlock.fit` |

## Data loading

A block that reads data resolves `BeakDataSource` from `beakDependencies(context)`, so it goes through the same transport and the same server-side authorization as a table. It loads when it mounts and again when the block instance or the data source changes.

| Aspect | Behaviour |
| --- | --- |
| Rows fetched by a module block | `BeakCalendarBlock`, `BeakKanbanBlock`, `BeakChatBlock`, `BeakInboxBlock`, `BeakFaqBlock` and `BeakPricingBlock` query their model with a page of 500 rows, so a board is not silently cut at the default 25. Chat sorts newest first, and so does the inbox when `timeField` is bound, so overflow drops the oldest rows. |
| Rows fetched by `BeakFileManagerBlock` | The default page of 25 rows. Sizes, names and folders past row 25 do not appear. |
| Rows fetched by a query block | Chart, map, gallery, carousel, video and timeline blocks run `query` as you wrote it. The default page is 25 rows, so set `pagination` on the spec for more. |
| Refetch after a write | `BeakTableBlock` (through its table view model), `BeakMetricBlock`, `BeakSummaryBlock` and `BeakRelationBlock` subscribe to the data source's change stream and query again when their table is written. Every other data block keeps what it loaded. |
| Writes by a block | Calendar drag, kanban drop and profile edits send an update, chat send sends a create, all through `BeakResourceRepository` on the per-record routes. The block then mirrors the written row into what it shows. |
| Failure | Metric and summary blocks show an error state with a retry. The other data blocks stay empty (or on `Loading…` for record-bound blocks) when the request fails or the server denies it. |

## Rules and limits

- `BeakBlock` is sealed. A new block type needs a change in `beak_frontend`; application code extends the union through `BeakWidgetBlock` only.
- Blocks are `const` configuration. Callbacks exist only where the interaction is the feature (row tap and row actions, event tap and move, card move, open, compose, the summary footer and group style) and in the builder of `BeakWidgetBlock`.
- A block has no visibility rule and no permission of its own. Show or hide a block by building a different tree, and enforce access on the server with policies. A denied read leaves a module or chart block empty.
- `BeakTabsBlock.tabs` must not be empty and `initialIndex` must be in range. The constructor does not assert this; an empty list throws a `RangeError` at build time.
- `BeakSummaryBlock` with `presentation: BeakSummaryPresentation.capacity` needs `capacity`. The constructor does not assert it; a missing value fails a null check at build time.
- Writes from calendar, kanban, chat and profile blocks use the per-record routes, not `POST /api/commits`. A model that closes those routes with `graphOnly` rejects the write. Save through a form screen or a model action instead.
- `BeakRecordScope` is provided by your screen. Nothing in the framework mounts it around a custom layout, see [Block system internals](../architecture/block-system-internals.md#where-a-block-gets-its-data).
- Charts need bounded height, so chart, map and table blocks take `heightInPixels` and draw inside a fixed-height box.
- Every column parameter takes a `BeakColumn`, in practice `Model.field.column` from the generated references. Table `fields` and kanban `groupField` take the field reference itself.

## Source

- `packages/beak_frontend/lib/src/blocks/beak_block.dart` declares the sealed union and lists every part file.
- `packages/beak_frontend/lib/src/blocks/beak_*_block.dart` holds one block class each.
- `packages/beak_frontend/lib/src/blocks/beak_chart_data.dart` holds `BeakChartType`, the chart point types and the mappers.
- `packages/beak_frontend/lib/src/blocks/beak_block_host.dart` renders the union; `packages/beak_frontend/lib/src/blocks/views/` holds the views of the data blocks.
- `packages/beak_frontend/lib/src/data/beak_data_changes.dart` declares the change stream that drives refetching.
- `examples/showcase/test/block_type_matrix_test.dart` switches exhaustively over the union and fails to compile when a block is added without a showcase page.
- `examples/showcase/lib/pages` builds every block type once.

## Continue reading

- [Blocks and charts](../blocks/index.md) teaches the blocks with worked pages.
- [Block system internals](../architecture/block-system-internals.md) explains the host, spans and record scope.
- [Screens and form layouts](screens-and-layouts.md) lists the typed layout tree that forms use instead of blocks.
- [Panel and resource options](panel-options.md) covers `BeakScreen` and the other places a block tree is mounted.
