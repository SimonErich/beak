import 'package:beak/panel.dart';
import 'package:superdashboard/models/models.dart';
import 'package:beak/ui.dart';

/// The UI-elements showcase — one page proving every leaf block: alerts (the
/// four severities), the full badge palette, progress bars, a star rating, a
/// round slider, tabs, an accordion, and a live activity timeline bound to
/// the seeded `activities` table.
BeakScreen buildUiKitScreen() => BeakScreen(
  path: '/ui-kit',
  title: 'UI Elements',
  icon: const BeakIconToken(OiIcons.layoutGrid),
  section: 'Showcase',
  body: BeakColumnBlock(
    gapInPixels: 24,
    children: [_alerts(), _widgets(), _tabs(), _accordion(), _timeline()],
  ),
);

BeakBlock _alerts() => const BeakSectionBlock(
  title: 'Alerts',
  child: BeakColumnBlock(
    gapInPixels: 12,
    children: [
      BeakAlertBlock('Heads up — this is an informational message.'),
      BeakAlertBlock(
        'Success — your changes were saved.',
        level: BeakAlertLevel.success,
      ),
      BeakAlertBlock(
        'Warning — your storage is almost full.',
        level: BeakAlertLevel.warning,
      ),
      BeakAlertBlock(
        'Error — the last payment could not be processed.',
        level: BeakAlertLevel.error,
      ),
    ],
  ),
);

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
    const BeakCardBlock(
      title: 'Progress',
      child: BeakColumnBlock(
        gapInPixels: 12,
        children: [
          BeakProgressBlock(value: 0.25, label: 'Design'),
          BeakProgressBlock(value: 0.6, label: 'Development'),
          BeakProgressBlock(value: 0.9, label: 'Launch'),
        ],
      ),
    ),
    const BeakCardBlock(
      title: 'Round slider',
      child: BeakRadialSliderBlock(label: 'Volume', initialValue: 65),
    ),
  ],
);

BeakBlock _tabs() => const BeakCardBlock(
  title: 'Tabs',
  child: BeakTabsBlock(
    tabs: [
      BeakTabBlockItem(
        label: 'Overview',
        content: BeakTextBlock('The overview tab — declarative content.'),
      ),
      BeakTabBlockItem(
        label: 'Details',
        content: BeakTextBlock('The details tab — a second panel.'),
      ),
    ],
  ),
);

BeakBlock _accordion() => const BeakCardBlock(
  title: 'Accordion',
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
);

BeakBlock _timeline() => const BeakCardBlock(
  title: 'Activity timeline',
  child: BeakTimelineBlock(
    query: BeakQuerySpec(
      table: 'activities',
      // Newest-first at the source, so the 12 shown really are the latest.
      sorts: [BeakSort('created_at', descending: true)],
      pagination: BeakPagination(perPage: 12),
    ),
    titleField: ActivityColumns.body,
    timeField: SharedColumns.createdAt,
  ),
);
