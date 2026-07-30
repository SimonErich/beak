---
title: Layout blocks
description: The structural block family: columns, rows, grids with spans, cards, sections, tabs, accordions, breadcrumbs, masonry, three-pane, carousel, dividers, spacers, and timelines.
---

# Layout blocks

After this page you can arrange any screen: stack content in columns, place cards
on a responsive grid, split a page into tabs or a three-pane app shell, and space
it out with dividers and gaps. These are the structural blocks. They hold other
blocks and decide where things sit.

Every block here is `const` configuration that renders onto an obers_ui layout
widget. Nothing below hard-codes a widget or a callback.

The tree you build lands in one of three files: `lib/screens/<name>.dart` for a
page of your own, `lib/dashboard.dart` for the screen at `/`, or
`lib/resources/<table>.dart` for a resource's `detail` and `formLayout`.

## The family at a glance

| Block | Renders onto | Key parameters |
| --- | --- | --- |
| `BeakColumnBlock` | `OiColumn` | `children`, `gapInPixels` |
| `BeakRowBlock` | `OiRow` | `children`, `gapInPixels` |
| `BeakGridBlock` | `OiGrid` + `OiSpan` | `children`, `columns` or `minColumnWidthInPixels`, `gapInPixels` |
| `BeakCardBlock` | `OiCard` | `child`, `title`, `subtitle`, `footer` |
| `BeakSectionBlock` | `OiSection` | `title`, `child`, `description` |
| `BeakTabsBlock` | `OiTabs` | `tabs`, `initialIndex` |
| `BeakAccordionBlock` | `OiAccordion` | `items`, `allowMultiple` |
| `BeakBreadcrumbsBlock` | `OiBreadcrumbs` | `items` |
| `BeakMasonryBlock` | `OiMasonry` | `children`, `columns`, `gapInPixels` |
| `BeakThreePaneBlock` | `OiThreeColumnLayout` | `label`, `left`, `middle`, `right` |
| `BeakCarouselBlock` | `OiCarousel` | `query`, `imageUrlField`, `captionField` |
| `BeakDividerBlock` | `OiDivider` | `label` |
| `BeakSpacerBlock` | fixed whitespace | `heightInPixels` |
| `BeakTimelineBlock` | `OiTimeline` | `query`, `titleField`, `timeField` |

## Stacks: column and row

`BeakColumnBlock` stacks its children vertically with a uniform gap, stretching
each to the full width. It is the default shape for page content.

```dart title="packages/beak_frontend/lib/src/blocks/beak_column_block.dart"
const BeakColumnBlock({
  required this.children,
  this.gapInPixels = 16,
  super.span,
});
```

Here it holds a stack of text blocks inside a card, straight from the showcase's
typography page:

```dart title="examples/superdashboard/lib/screens/typography_screen.dart"
body: BeakCardBlock(
  title: 'Type scale',
  child: BeakColumnBlock(
    gapInPixels: 12,
    children: [
      BeakTextBlock('Display', variant: BeakTextVariant.display),
      BeakTextBlock('Heading 1', variant: BeakTextVariant.h1),
      BeakTextBlock('Heading 2', variant: BeakTextVariant.h2),
      BeakTextBlock('Heading 3', variant: BeakTextVariant.h3),
      BeakTextBlock('Heading 4', variant: BeakTextVariant.h4),
      // ... the body, small, and caption variants.
    ],
  ),
),
```

`BeakRowBlock` is the horizontal twin. It renders onto `OiRow`, which collapses
into a column on narrow breakpoints so rows stay readable on small screens.

```dart title="packages/beak_frontend/lib/src/blocks/beak_row_block.dart"
const BeakRowBlock({
  required this.children,
  this.gapInPixels = 16,
  super.span,
});
```

```dart title="examples/superdashboard/lib/screens/ui_kit_screen.dart"
child: BeakRowBlock(
  gapInPixels: 8,
  children: [
    for (final color in BeakColor.values)
      BeakBadgeBlock(color.name, color: color),
  ],
),
```

## Grids and spans

`BeakGridBlock` places its children on a column grid. Give it either a fixed
`columns` count or a `minColumnWidthInPixels` for an auto-fitting grid, never
both (an assert enforces it).

```dart title="packages/beak_frontend/lib/src/blocks/beak_grid_block.dart"
const BeakGridBlock({
  required this.children,
  this.columns,
  this.minColumnWidthInPixels,
  this.gapInPixels = 16,
  super.span,
}) : assert(
       columns == null || minColumnWidthInPixels == null,
       'Provide either columns or minColumnWidthInPixels, not both.',
     );
```

Each child's `span` decides how many tracks it covers. A child with no span
occupies one track. This two-up grid of cards comes from the UI-kit page:

```dart title="examples/superdashboard/lib/screens/ui_kit_screen.dart"
BeakBlock _widgets() => BeakGridBlock(
  columns: 2,
  gapInPixels: 20,
  children: [
    BeakCardBlock(
      title: 'Badges',
      child: BeakRowBlock(
        gapInPixels: 8,
        children: [
          for (final color in BeakColor.values)
            BeakBadgeBlock(color.name, color: color),
        ],
      ),
    ),
    const BeakCardBlock(title: 'Rating', child: BeakRatingBlock(value: 3.5)),
    // ... the Progress and Round slider cards.
  ],
);
```

For finer control, set a wider grid and span individual children. On a
twelve-track grid, `BeakSpan(columns: 6)` is a half-width child. A layout of
your own might say:

```dart
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
```

!!! note "What just happened"
    - `span` is only read for direct children of a `BeakGridBlock`. On a child
      of a column or row it is ignored.
    - `BeakSpan` also takes `rows` for a child that should be taller than one
      track.
    - Spans resolve responsively, because the host maps them to obers_ui's
      `OiSpan` placement.

## Surfaces: card and section

`BeakCardBlock` wraps content in an elevated card with an optional header
(`title`, `subtitle`) and `footer`.

```dart title="packages/beak_frontend/lib/src/blocks/beak_card_block.dart"
const BeakCardBlock({
  required this.child,
  this.title,
  this.subtitle,
  this.footer,
  super.span,
});
```

`BeakSectionBlock` is lighter: a heading, an optional description, and a body.
Use it to label a run of content without the card chrome.

```dart title="packages/beak_frontend/lib/src/blocks/beak_section_block.dart"
const BeakSectionBlock({
  required this.title,
  required this.child,
  this.description,
  super.span,
});
```

```dart title="packages/beak_frontend/test/src/blocks/beak_block_host_test.dart"
const BeakSectionBlock(
  title: 'Settings',
  description: 'Tune the panel',
  child: BeakTextBlock('content'),
),
```

## Navigation: tabs, accordion, breadcrumbs

`BeakTabsBlock` shows a tab bar and renders the selected tab's content below it.
Each tab is a `BeakTabBlockItem` (a label, an optional icon, and its content).
The selected index is the only piece of state, and the host owns it.

```dart title="packages/beak_frontend/lib/src/blocks/beak_tabs_block.dart"
const BeakTabsBlock({required this.tabs, this.initialIndex = 0, super.span});
```

```dart title="packages/beak_frontend/test/src/blocks/beak_block_host_test.dart"
const BeakTabsBlock(
  tabs: [
    BeakTabBlockItem(label: 'One', content: BeakTextBlock('first')),
    BeakTabBlockItem(label: 'Two', content: BeakTextBlock('second')),
  ],
),
```

`BeakAccordionBlock` stacks expandable sections (FAQ-style). Set
`allowMultiple: true` to let several open at once; each item can start expanded.

```dart title="packages/beak_frontend/lib/src/blocks/beak_accordion_block.dart"
const BeakAccordionBlock({
  required this.items,
  this.allowMultiple = false,
  super.span,
});
```

```dart title="examples/superdashboard/lib/screens/ui_kit_screen.dart"
child: BeakAccordionBlock(
  items: [
    BeakAccordionBlockItem(
      title: 'What is a block?',
      initiallyExpanded: true,
      content: BeakTextBlock('A declarative, optionally data-bound node.'),
    ),
    BeakAccordionBlockItem(
      title: 'How does it render?',
      content: BeakTextBlock('Through one exhaustive host switch.'),
    ),
  ],
),
```

`BeakBreadcrumbsBlock` renders a trail of crumbs. A crumb with a `route`
navigates through the panel's go_router on tap; the current page's crumb usually
has none.

```dart title="packages/beak_frontend/lib/src/blocks/beak_breadcrumbs_block.dart"
const BeakBreadcrumbsBlock({required this.items, super.span});
```

```dart title="packages/beak_frontend/test/src/blocks/beak_block_host_test.dart"
block: BeakBreadcrumbsBlock(
  items: [
    BeakBreadcrumbBlockItem(label: 'Home', route: '/target'),
    BeakBreadcrumbBlockItem(label: 'Here'),
  ],
),
```

## App layouts: masonry, three-pane, carousel, timeline

`BeakMasonryBlock` distributes children across vertical columns, each column
packing items top-down (Pinterest-style). It defaults to three columns.

```dart title="packages/beak_frontend/lib/src/blocks/beak_masonry_block.dart"
const BeakMasonryBlock({
  required this.children,
  this.columns = 3,
  this.gapInPixels = 16,
  super.span,
}) : assert(columns >= 1, 'columns must be >= 1');
```

```dart title="packages/beak_frontend/test/src/blocks/beak_block_host_test.dart"
const BeakMasonryBlock(
  columns: 2,
  children: [BeakTextBlock('a'), BeakTextBlock('b')],
),
```

`BeakThreePaneBlock` is the backbone of email, chat, and file-manager screens: a
narrow start pane, a main middle pane, and an optional end pane. The showcase's
file manager builds all three panes from tables.

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

```dart title="examples/superdashboard/lib/screens/files_screen.dart"
body: BeakThreePaneBlock(
  label: 'File manager',
  leftWidthInPixels: 260,
  rightWidthInPixels: 320,
  left: BeakTableBlock(
    title: 'Folders',
    model: FileFolderModel(),
    heightInPixels: 640,
  ),
  middle: BeakFileManagerBlock(
    label: 'Files',
    model: ManagedFileModel(),
    nameField: ManagedFileColumns.name,
    sizeField: ManagedFileColumns.size,
    modifiedField: ManagedFileColumns.modifiedAt,
  ),
  right: BeakTableBlock(
    title: 'Storage',
    model: StorageAccountModel(),
    heightInPixels: 640,
  ),
),
```

`BeakCarouselBlock` is data-bound: each row of its `query` becomes a slide.
`imageUrlField` supplies the image and `captionField` an optional caption. Slide
content comes from seeded data, never a hard-coded list.

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

```dart title="examples/superdashboard/lib/screens/gallery_screen.dart"
child: BeakCarouselBlock(
  query: BeakQuerySpec(
    table: 'media_assets',
    filter: _inCollection(MediaCollection.carousel),
    sorts: const [BeakSort('sort_index')],
  ),
  imageUrlField: MediaAssetColumns.url,
  captionField: MediaAssetColumns.caption,
),
```

`BeakTimelineBlock` is also data-bound: each row becomes a dated event.
`titleField` is the event label and `timeField` its timestamp.

```dart title="packages/beak_frontend/lib/src/blocks/beak_timeline_block.dart"
const BeakTimelineBlock({
  required this.query,
  required this.titleField,
  required this.timeField,
  super.span,
});
```

```dart title="examples/superdashboard/lib/screens/ui_kit_screen.dart"
child: BeakTimelineBlock(
  query: BeakQuerySpec(
    table: 'activities',
    sorts: [BeakSort('created_at', descending: true)],
    pagination: BeakPagination(perPage: 12),
  ),
  titleField: ActivityColumns.body,
  timeField: SharedColumns.createdAt,
),
```

!!! tip "Query-backed layout blocks"
    Carousel and timeline take a [`BeakQuerySpec`](../concepts/how-data-flows.md),
    so they read live rows instead of static content. You point them at typed
    columns (`MediaAssetColumns.url`, `ActivityColumns.body`), never string keys.

## Spacing: divider and spacer

`BeakDividerBlock` draws a horizontal rule, with a centred label when you give it
one.

```dart title="packages/beak_frontend/lib/src/blocks/beak_divider_block.dart"
const BeakDividerBlock({this.label, super.span});
```

`BeakSpacerBlock` is fixed vertical whitespace between blocks.

```dart title="packages/beak_frontend/lib/src/blocks/beak_spacer_block.dart"
const BeakSpacerBlock({this.heightInPixels = 16, super.span});
```

Both, side by side:

```dart title="packages/beak_frontend/test/src/blocks/beak_block_host_test.dart"
const BeakColumnBlock(
  children: [
    BeakMarkdownBlock('# Heading\n\nBody copy.'),
    BeakDividerBlock(label: 'or'),
    BeakDividerBlock(),
    BeakSpacerBlock(heightInPixels: 32),
  ],
),
```

## Continue reading

- [Display blocks](display-blocks.md) text, markdown, images, video, and icon
  galleries to fill these layouts.
- [Data blocks](data-blocks.md) KPIs, charts, and tables for a dashboard grid.
- [Custom screens](../panel/custom-screens.md) where a layout tree becomes a
  page in the nav.
- [Blocks overview](index.md) the sealed family, the host, and grid spans.
