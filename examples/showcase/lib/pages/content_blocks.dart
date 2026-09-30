import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

/// Blocks that show content: text, markdown, images, badges, alerts,
/// progress, ratings, sliders, breadcrumbs and an icon reference.
BeakScreen contentBlocksPage() => BeakScreen(
  path: '/content',
  title: 'Content blocks',
  icon: const BeakIconToken(OiIcons.fileText),
  navigationGroup: 'Blocks',
  body: BeakColumnBlock(
    gapInPixels: 24,
    children: [
      _breadcrumbs(),
      _typography(),
      _markdown(),
      _alerts(),
      _badges(),
      _meters(),
      _icons(),
    ],
  ),
);

/// Where the reader is.
// --8<-- [start:breadcrumbs]
BeakBlock _breadcrumbs() => const BeakBreadcrumbsBlock(
  items: [
    BeakBreadcrumbBlockItem(label: 'Blocks'),
    BeakBreadcrumbBlockItem(label: 'Content', route: '/content'),
  ],
);
// --8<-- [end:breadcrumbs]

/// The whole type ramp.
// --8<-- [start:typography]
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
// --8<-- [end:typography]

/// Markdown and an image.
// --8<-- [start:markdown]
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
// --8<-- [end:markdown]

/// Four severities.
// --8<-- [start:alerts]
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
// --8<-- [end:alerts]

/// Every semantic colour.
// --8<-- [start:badges]
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
// --8<-- [end:badges]

/// Progress, rating and a radial slider.
// --8<-- [start:meters]
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
// --8<-- [end:meters]

/// A named grid of icons.
// --8<-- [start:icons]
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
// --8<-- [end:icons]
