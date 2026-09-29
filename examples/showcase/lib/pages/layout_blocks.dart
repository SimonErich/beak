import 'package:beak/panel.dart';
import 'package:beak/ui.dart';
import 'package:flutter/widgets.dart';

/// Blocks that arrange other blocks: grid, row, column, card, section, tabs,
/// accordion, divider, spacer, masonry and the raw-widget escape hatch.
BeakScreen layoutBlocksPage() => BeakScreen(
  path: '/layout',
  title: 'Layout blocks',
  icon: const BeakIconToken(OiIcons.layoutGrid),
  navigationGroup: 'Blocks',
  body: BeakColumnBlock(
    gapInPixels: 24,
    children: [
      _gridSection(),
      _rowSection(),
      _tabsSection(),
      _accordionSection(),
      _masonrySection(),
      _escapeHatchSection(),
    ],
  ),
);

/// Twelve tracks, with cards spanning some of them.
// --8<-- [start:gridSection]
BeakBlock _gridSection() => const BeakSectionBlock(
  title: 'Grid',
  description:
      'A card spans as many of the twelve tracks as its span asks for.',
  child: BeakGridBlock(
    columns: 12,
    children: [
      BeakCardBlock(
        span: BeakSpan(columns: 8),
        title: 'Wide card',
        subtitle: 'Eight of twelve tracks',
        footer: BeakTextBlock(
          'A footer is any block.',
          variant: BeakTextVariant.caption,
        ),
        child: BeakTextBlock('Cards take a title, a subtitle and a footer.'),
      ),
      BeakCardBlock(
        span: BeakSpan(columns: 4),
        title: 'Narrow card',
        child: BeakTextBlock('Four tracks.'),
      ),
    ],
  ),
);
// --8<-- [end:gridSection]

/// An expanded row shares its width by span; a column stacks.
// --8<-- [start:rowSection]
BeakBlock _rowSection() => const BeakSectionBlock(
  title: 'Row and column',
  child: BeakRowBlock(
    expand: true,
    children: [
      BeakCardBlock(
        span: BeakSpan(columns: 2),
        child: BeakColumnBlock(
          gapInPixels: 8,
          children: [
            BeakTextBlock('Two shares', variant: BeakTextVariant.bodyStrong),
            BeakDividerBlock(),
            BeakTextBlock('A column stacks its children.'),
          ],
        ),
      ),
      BeakCardBlock(
        child: BeakColumnBlock(
          gapInPixels: 8,
          children: [
            BeakTextBlock('One share', variant: BeakTextVariant.bodyStrong),
            BeakDividerBlock(label: 'Labelled divider'),
            BeakSpacerBlock(heightInPixels: 12),
            BeakTextBlock('A spacer adds a fixed gap.'),
          ],
        ),
      ),
    ],
  ),
);
// --8<-- [end:rowSection]

/// One panel at a time.
// --8<-- [start:tabsSection]
BeakBlock _tabsSection() => const BeakSectionBlock(
  title: 'Tabs',
  child: BeakTabsBlock(
    tabs: [
      BeakTabBlockItem(
        label: 'Feeding',
        content: BeakTextBlock('Seed at dawn, fruit at noon.'),
      ),
      BeakTabBlockItem(
        label: 'Cleaning',
        content: BeakTextBlock('Perches are scrubbed on Thursdays.'),
      ),
    ],
  ),
);
// --8<-- [end:tabsSection]

/// Expandable panels.
// --8<-- [start:accordionSection]
BeakBlock _accordionSection() => const BeakSectionBlock(
  title: 'Accordion',
  child: BeakAccordionBlock(
    items: [
      BeakAccordionBlockItem(
        title: 'Why is the aviary netted?',
        initiallyExpanded: true,
        content: BeakTextBlock(
          'So that nothing leaves that we did not mean to.',
        ),
      ),
      BeakAccordionBlockItem(
        title: 'Can visitors feed the birds?',
        content: BeakTextBlock('Only with the seed sold at the gate.'),
      ),
    ],
  ),
);
// --8<-- [end:accordionSection]

/// A wall of cards of different heights.
// --8<-- [start:masonrySection]
BeakBlock _masonrySection() => BeakSectionBlock(
  title: 'Masonry',
  child: BeakMasonryBlock(
    columns: 3,
    children: [
      for (final (name, photo, height) in const [
        ('Canopy', 'aviary-1.jpg', 220.0),
        ('Cloud forest', 'aviary-2.jpg', 140.0),
        ('Outback', 'aviary-3.jpg', 180.0),
      ])
        BeakCardBlock(
          title: name,
          child: BeakImageBlock(
            'assets/photos/$photo',
            alt: '$name at dawn',
            heightInPixels: height,
          ),
        ),
    ],
  ),
);
// --8<-- [end:masonrySection]

/// The one block that takes a widget: for what no block expresses yet.
// --8<-- [start:escapeHatchSection]
BeakBlock _escapeHatchSection() => BeakSectionBlock(
  title: 'Escape hatch',
  child: BeakWidgetBlock(
    (BuildContext context) =>
        const OiLabel.body('An ordinary widget, hosted in a block.'),
  ),
);
// --8<-- [end:escapeHatchSection]
