# Content blocks

> Show text, markdown, images, alerts, badges, progress, ratings, breadcrumbs and an icon reference on a custom screen, with no data plumbing.

Content blocks show what you hand them: a string, a number, an image path. They fetch nothing, which makes them the cheapest blocks on a page. After this page you know all ten, what each one does with its arguments, and the two places where a parameter looks interactive and is not.

## At a glance

| Block | Renders onto | Shows |
| --- | --- | --- |
| `BeakTextBlock` | `OiLabel` | A run of themed text in one of nine variants. |
| `BeakMarkdownBlock` | `OiMarkdown` | Long-form copy from a Markdown string. |
| `BeakImageBlock` | `OiImage` | An image from a URL or an asset. |
| `BeakAlertBlock` | `OiBanner` | An inline message at four severities. |
| `BeakBadgeBlock` | `OiBadge` | A short label in a semantic color. |
| `BeakProgressBlock` | `OiProgress` | A linear bar filled to a fraction. |
| `BeakRatingBlock` | `OiStarRating` | Stars, half steps included. |
| `BeakRadialSliderBlock` | `OiRadialSlider` | A round knob. A demo control, see the limits. |
| `BeakBreadcrumbsBlock` | `OiBreadcrumbs` | A trail whose crumbs can navigate. |
| `BeakIconGalleryBlock` | `OiIcon` in a grid | Named icons, as a cheat sheet. |

Color and type come from the panel theme. A block never takes a hex value. It takes a `BeakColor` or a text variant and the theme decides what that looks like, so a dark theme needs no changes on the page. [Colors and tokens](../theming/colors-and-tokens.md) has the mapping.

## Text

`BeakTextBlock` takes the text as its first argument and a `BeakTextVariant`. The variants are the theme's type ramp, so the same block looks right in any theme:

```dart title="examples/showcase/lib/pages/content_blocks.dart"
BeakBlock _typography() => const BeakCardBlock(
  title: 'Text',
  child: BeakColumnBlock(
    gapInPixels: 8,
    children: [
      BeakTextBlock('Display', variant: BeakTextVariant.display),
      BeakTextBlock('Heading 1', variant: BeakTextVariant.h1),
      BeakTextBlock('Heading 2', variant: BeakTextVariant.h2),
      BeakTextBlock('Heading 3', variant: BeakTextVariant.h3),
      BeakTextBlock('Heading 4', variant: BeakTextVariant.h4),
      BeakTextBlock('Body, the default.'),
      BeakTextBlock('Body strong', variant: BeakTextVariant.bodyStrong),
      BeakTextBlock('Small', variant: BeakTextVariant.small),
      BeakTextBlock('Caption', variant: BeakTextVariant.caption),
    ],
  ),
);
```

`body` is the default. The other eight are `display`, `h1` to `h4`, `bodyStrong`, `small` and `caption`. A framed screen already shows `BeakScreen.title` in its header, so headings inside the body are for the sections under it.

## Markdown and images

```dart title="examples/showcase/lib/pages/content_blocks.dart"
BeakBlock _markdown() => const BeakGridBlock(
  columns: 2,
  children: [
    BeakCardBlock(
      title: 'Markdown',
      child: BeakMarkdownBlock('''
## Opening hours

* **Weekdays** 9:00 to 17:00
* **Weekends** 10:00 to 18:00

Feeding is at *noon*.
'''),
    ),
    BeakCardBlock(
      title: 'Image',
      child: BeakImageBlock(
        'assets/photos/aviary-4.jpg',
        alt: 'The wetlands at midday',
        heightInPixels: 220,
      ),
    ),
  ],
);
```

`BeakMarkdownBlock` keeps copy out of widget code: opening hours, terms, a changelog. `BeakImageBlock` requires an `alt` text, because `OiImage` does. A URL starting with `http://` or `https://` loads over the network. Anything else is read as an asset path, and the asset has to be declared in your `pubspec.yaml` (the Aviary declares `assets/photos/`). `fit` defaults to `BoxFit.cover`, and `widthInPixels` and `heightInPixels` fix the box.

## Alerts and badges

The Aviary's four alerts: the morning round is done, a chick hatched, seed is running low, the pump failed. Severity is the only thing the block changes.

```dart title="examples/showcase/lib/pages/content_blocks.dart"
BeakBlock _alerts() => const BeakSectionBlock(
  title: 'Alerts',
  child: BeakColumnBlock(
    gapInPixels: 12,
    children: [
      BeakAlertBlock('The morning round is done.'),
      BeakAlertBlock(
        'A chick hatched in the cloud forest.',
        level: BeakAlertLevel.success,
      ),
      BeakAlertBlock(
        'Seed stock is running low.',
        level: BeakAlertLevel.warning,
      ),
      BeakAlertBlock('The wetlands pump failed.', level: BeakAlertLevel.error),
    ],
  ),
);
```

The alert is an `OiBanner`, and a banner has a dismiss control. Dismissing hides it for as long as that widget lives and stores nothing. For a message that appears after an action and fades out, use an overlay ([Overlays](../panel/overlays.md)).

```dart title="examples/showcase/lib/pages/content_blocks.dart"
BeakBlock _badges() => BeakCardBlock(
  title: 'Badges',
  child: BeakRowBlock(
    gapInPixels: 8,
    children: [
      for (final color in BeakColor.values)
        BeakBadgeBlock(color.name, color: color),
    ],
  ),
);
```

That loop is also the fastest way to see what your theme does to the seven `BeakColor` values. A badge without a `color` is `primary`.

## Progress, rating and the slider

```dart title="examples/showcase/lib/pages/content_blocks.dart"
BeakBlock _meters() => const BeakGridBlock(
  columns: 3,
  children: [
    BeakCardBlock(
      title: 'Progress',
      child: BeakColumnBlock(
        gapInPixels: 12,
        children: [
          BeakProgressBlock(value: 0.25, label: 'Feeding round'),
          BeakProgressBlock(value: 0.8, label: 'Cleaning round'),
        ],
      ),
    ),
    BeakCardBlock(title: 'Rating', child: BeakRatingBlock(value: 4.5)),
    BeakCardBlock(
      title: 'Radial slider',
      child: BeakRadialSliderBlock(label: 'Heat lamp', initialValue: 65),
    ),
  ],
);
```

`BeakProgressBlock.value` is a fraction from 0 to 1, not a percentage, and the optional label sits above the bar. `BeakRatingBlock` shows half stars (`4.5`) out of `maxStars` (5). Neither is bound to data. For a real completion rate, use a [metric with a target](data-blocks.md) or a [summary](summaries.md).

## Breadcrumbs and the icon gallery

```dart title="examples/showcase/lib/pages/content_blocks.dart"
BeakBlock _breadcrumbs() => const BeakBreadcrumbsBlock(
  items: [
    BeakBreadcrumbBlockItem(label: 'Blocks'),
    BeakBreadcrumbBlockItem(label: 'Content', route: '/content'),
  ],
);
```

A crumb with a `route` navigates there through the panel's router on tap (`go`, so the crumb replaces the location instead of stacking a new one). The block does not read the current location, so the trail is the one you wrote. A crumb without a route is plain text, which is what the current page's crumb normally is.

```dart title="examples/showcase/lib/pages/content_blocks.dart"
BeakBlock _icons() => const BeakCardBlock(
  title: 'Icons',
  child: BeakIconGalleryBlock(
    columns: 6,
    items: [
      BeakIconGalleryItem(icon: BeakIconToken(OiIcons.bird), label: 'bird'),
      BeakIconGalleryItem(icon: BeakIconToken(OiIcons.egg), label: 'egg'),
      BeakIconGalleryItem(
        icon: BeakIconToken(OiIcons.feather),
        label: 'feather',
      ),
      BeakIconGalleryItem(icon: BeakIconToken(OiIcons.trees), label: 'trees'),
      BeakIconGalleryItem(icon: BeakIconToken(OiIcons.map), label: 'map'),
      BeakIconGalleryItem(
        icon: BeakIconToken(OiIcons.calendar),
        label: 'calendar',
      ),
    ],
  ),
);
```

`BeakIconGalleryBlock` draws each `BeakIconToken` with its label underneath. It exists for design-system pages and for finding the name of the icon you want. The tokens come from `OiIcons`, the Lucide set that ships with obers_ui, and a theme can swap the drawing for every token at once ([Typography and icons](../theming/typography-and-icons.md)).

## Rules and limits

- **Content blocks add no visible text of their own.** Every string on screen is one you passed.
- **`BeakRatingBlock.readOnly` defaults to `true`, and `false` does not make it editable.** The block has no callback, so nothing can change the value and nothing learns that someone tapped. Leave it read-only.
- **`BeakRadialSliderBlock` keeps its value to itself.** It starts at `initialValue`, the knob moves, and the number goes nowhere: no binding, no callback. It is a showcase control. A knob that saves is a `BeakWidgetBlock` around `OiRadialSlider`.
- **`BeakImageBlock` passes no placeholder and no error widget to `OiImage`.** A failed load falls through to Flutter's default handling, so check the URL or the asset path before you blame the block.
- **Alerts are dismissible.** There is no parameter to turn the dismiss control off.
- **Breadcrumb routes are panel routes.** A route the router does not know opens the panel's not-found page.
- **Nothing validates the numbers.** `BeakProgressBlock` documents 0 to 1 and does not assert it.

## Verify it

The Aviary renders every page against a fixture source on each test run. A page that throws while it builds fails its test:

```console
$ cd examples/showcase
$ flutter test --no-pub test/aviary_pages_test.dart
...
00:04 +11: FAQ renders
00:05 +12: All tests passed!
```

The tests do not judge how a page looks. Run the panel and open Content blocks for that.

## Reference

Required parameters are marked with a star. Every block also takes `span`.

| Block | Parameters (default) |
| --- | --- |
| `BeakTextBlock` | text* (positional), `variant` (`BeakTextVariant.body`) |
| `BeakMarkdownBlock` | source* (positional) |
| `BeakImageBlock` | url* (positional), `alt`*, `widthInPixels`, `heightInPixels`, `fit` (`BoxFit.cover`) |
| `BeakAlertBlock` | message* (positional), `level` (`BeakAlertLevel.info`; also `success`, `warning`, `error`) |
| `BeakBadgeBlock` | label* (positional), `color` (`BeakColor.primary`) |
| `BeakProgressBlock` | `value`*, `label` |
| `BeakRatingBlock` | `value`*, `maxStars` (5), `readOnly` (true) |
| `BeakRadialSliderBlock` | `label`*, `min` (0), `max` (100), `initialValue` (40), `sizeInPixels` (200) |
| `BeakBreadcrumbsBlock` | `items`*; each `BeakBreadcrumbBlockItem` takes `label`* and `route` |
| `BeakIconGalleryBlock` | `items`*, `columns` (6); each `BeakIconGalleryItem` takes `icon`* (a `BeakIconToken`) and `label`* |

The text variants, verbatim:

```dart title="packages/beak_frontend/lib/src/blocks/beak_text_block.dart"
enum BeakTextVariant {
  /// Hero display text.
  display,

  /// Page-level heading.
  h1,

  /// Section heading.
  h2,

  /// Sub-section heading.
  h3,

  /// Minor heading.
  h4,

  /// Regular body copy.
  body,

  /// Emphasized body copy.
  bodyStrong,

  /// De-emphasized small text.
  small,

  /// Caption / hint text.
  caption,
}
```

Every block class with its constructor is on [Blocks](../reference/blocks.md).

## Continue reading

- [Data blocks](data-blocks.md) metrics, tables, boards and calendars that fetch for themselves.
- [Colors and tokens](../theming/colors-and-tokens.md) how `BeakColor` becomes a color in your theme.
- [Layout blocks](layout-blocks.md) the frame these blocks sit in.
- [Blocks](../reference/blocks.md) every block class and its parameters.
