---
title: Display blocks
description: The content blocks: themed text and its variants, rendered Markdown, images, data-bound video, and named icon galleries.
---

# Display blocks

After this page you can put content on a screen: headings and body copy at the
right size, long-form Markdown, images from a URL, a video pulled from your data,
and a reference grid of named icons. These are the blocks that show things
rather than arrange them.

| Block | Renders onto | Key parameters |
| --- | --- | --- |
| `BeakTextBlock` | `OiLabel` (per variant) | `text`, `variant` |
| `BeakMarkdownBlock` | `OiMarkdown` | `source` |
| `BeakImageBlock` | `OiImage` | `url`, `alt`, `widthInPixels`, `heightInPixels`, `fit` |
| `BeakVideoBlock` | `OiVideoPlayer` | `query`, `urlField`, `posterField` |
| `BeakIconGalleryBlock` | `OiIcon` grid | `items`, `columns` |

## Text

`BeakTextBlock` is a run of themed text. You pick a `variant`, and the block maps
to the matching `OiLabel`, so your typography stays on the theme's scale.

```dart title="packages/beak_frontend/lib/src/blocks/beak_text_block.dart"
const BeakTextBlock(
  this.text, {
  this.variant = BeakTextVariant.body,
  super.span,
});
```

The variant is the whole story. One enum, nine sizes, each wired to an `OiLabel`
constructor by the host:

```dart title="packages/beak_frontend/lib/src/blocks/beak_block_host.dart"
Widget _text(BeakTextBlock block) => switch (block.variant) {
  BeakTextVariant.display => OiLabel.display(block.text),
  BeakTextVariant.h1 => OiLabel.h1(block.text),
  BeakTextVariant.h2 => OiLabel.h2(block.text),
  BeakTextVariant.h3 => OiLabel.h3(block.text),
  BeakTextVariant.h4 => OiLabel.h4(block.text),
  BeakTextVariant.body => OiLabel.body(block.text),
  BeakTextVariant.bodyStrong => OiLabel.bodyStrong(block.text),
  BeakTextVariant.small => OiLabel.small(block.text),
  BeakTextVariant.caption => OiLabel.caption(block.text),
};
```

The showcase's typography page walks the whole ramp. Here is the top of it,
inside a card:

```dart title="apps/beak_superdashboard/lib/screens/typography_screen.dart"
BeakCardBlock(
  title: 'Type scale',
  child: BeakColumnBlock(
    gapInPixels: 12,
    children: [
      BeakTextBlock('Display', variant: BeakTextVariant.display),
      BeakTextBlock('Heading 1', variant: BeakTextVariant.h1),
      BeakTextBlock('Heading 2', variant: BeakTextVariant.h2),
      BeakTextBlock('Heading 3', variant: BeakTextVariant.h3),
      BeakTextBlock('Heading 4', variant: BeakTextVariant.h4),
    ],
  ),
),
```

`BeakTextVariant.body` is the default, so a plain `BeakTextBlock('...')` is body
copy. The full list:

| Variant | Use for |
| --- | --- |
| `display` | Hero display text |
| `h1` | Page-level heading |
| `h2` | Section heading |
| `h3` | Sub-section heading |
| `h4` | Minor heading |
| `body` | Regular body copy (the default) |
| `bodyStrong` | Emphasized body copy |
| `small` | De-emphasized small text |
| `caption` | Caption or hint text |

!!! tip "Match the type to the theme, not to pixels"
    You never set a font size on a `BeakTextBlock`. You pick a semantic variant,
    and the panel's [theme](../theming/typography-and-icons.md) decides the size.
    Change the theme and every heading moves together.

## Markdown

`BeakMarkdownBlock` renders a raw Markdown string. It is the block for long-form
copy: terms, changelogs, and starter pages.

```dart title="packages/beak_frontend/lib/src/blocks/beak_markdown_block.dart"
const BeakMarkdownBlock(this.source, {super.span});
```

```dart title="packages/beak_frontend/test/src/blocks/beak_block_host_test.dart"
BeakMarkdownBlock('# Heading\n\nBody copy.'),
```

The showcase's starter screen is nothing but a `BeakCardBlock` wrapping one
`BeakMarkdownBlock`, which makes it the documented starting point for a new page.

## Image

`BeakImageBlock` loads an image from a URL, with the panel's placeholder and
error states. `alt` is required (accessibility is not optional), and `fit`
defaults to `BoxFit.cover`.

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

```dart title="packages/beak_frontend/test/src/blocks/beak_block_host_test.dart"
BeakImageBlock(
  'https://example.com/pic.png',
  alt: 'A picture',
  widthInPixels: 100,
  heightInPixels: 80,
),
```

!!! note "Static image versus image column"
    `BeakImageBlock` shows one URL you already have. To render an image *field*
    of a record (a product photo, an avatar), use a
    [`BeakImageColumn`](../models/files-and-storage-columns.md) instead, and let
    the column own upload, validation, and thumbnails.

## Video

`BeakVideoBlock` is data-bound: it plays the first row of its `query`, reading
the source from `urlField` and an optional poster from `posterField`. The
showcase feeds it the seeded `media_assets` table.

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

```dart title="apps/beak_superdashboard/lib/screens/gallery_screen.dart"
BeakVideoBlock(
  title: 'Featured video',
  query: BeakQuerySpec(
    table: 'media_assets',
    filter: _inCollection(MediaCollection.video),
    sorts: const [BeakSort('sort_index')],
  ),
  urlField: MediaAssetColumns.url,
),
```

`urlField` and `posterField` are typed [columns](../models/column-types.md), not
string keys. The block reads the source from the row the query returns, so the
video is whatever your data says it is.

## Icon gallery

`BeakIconGalleryBlock` lays out named icons in a grid, each with its label
beneath. It is the design-system cheat-sheet: a way to show which icons a project
uses. Each entry is a `BeakIconGalleryItem` pairing a `BeakIconToken` with a
name.

```dart title="packages/beak_frontend/lib/src/blocks/beak_icon_gallery_block.dart"
const BeakIconGalleryBlock({
  required this.items,
  this.columns = 6,
  super.span,
});
```

The showcase's icons page builds one from a curated list of Lucide icons:

```dart title="apps/beak_superdashboard/lib/screens/icons_screen.dart"
BeakCardBlock(
  title: 'Lucide icons',
  child: BeakIconGalleryBlock(
    columns: 6,
    items: [
      for (final (icon, label) in _icons)
        BeakIconGalleryItem(icon: icon, label: label),
    ],
  ),
),
```

Where `_icons` is a plain list of token-and-label pairs:

```dart title="apps/beak_superdashboard/lib/screens/icons_screen.dart"
const List<_Icon> _icons = [
  (BeakIconToken(OiIcons.home), 'home'),
  (BeakIconToken(OiIcons.user), 'user'),
  (BeakIconToken(OiIcons.settings), 'settings'),
  // ...
];
```

`BeakIconToken` is Beak's typed handle on an obers_ui icon, so you name icons
like `OiIcons.home` instead of reaching for a Material `IconData`. The same token
type names a resource's or screen's nav icon.

## Continue reading

- [UI-kit blocks](ui-kit-blocks.md) alerts, badges, progress, and ratings for
  small stateful UI.
- [Layout blocks](layout-blocks.md) the columns, grids, and cards these display
  blocks sit inside.
- [Typography and icons](../theming/typography-and-icons.md) how the text
  variants and icon tokens map to the theme.
- [Blocks overview](index.md) the sealed family and its one renderer.
