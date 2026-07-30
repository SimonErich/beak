import 'package:beak/panel.dart';
import 'package:superdashboard/models/models.dart';
import 'package:beak/ui.dart';

/// The UI-elements showcase — one page proving every leaf block: alerts (the
/// four severities), the full badge palette, progress bars, a star rating, a
/// round slider, tabs, an accordion, the layout primitives, and a live
/// activity timeline bound to the seeded `activities` table.
BeakScreen buildUiKitScreen() => BeakScreen(
  path: '/ui-kit',
  title: 'UI Elements',
  icon: const BeakIconToken(OiIcons.layoutGrid),
  section: 'Showcase',
  body: BeakColumnBlock(
    gapInPixels: 24,
    children: [
      _breadcrumbs(),
      _alerts(),
      _widgets(),
      _tabs(),
      _accordion(),
      _layout(),
      _wizard(),
      _timeline(),
    ],
  ),
);

BeakBlock _breadcrumbs() => const BeakBreadcrumbsBlock(
  items: [
    BeakBreadcrumbBlockItem(label: 'Showcase'),
    BeakBreadcrumbBlockItem(label: 'UI Elements', route: '/ui-kit'),
  ],
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

/// The primitives that arrange other blocks rather than showing data: a
/// masonry wall, the rule and the gap between sections, and the one escape
/// hatch — [BeakWidgetBlock], which hands the slot to an ordinary widget
/// when no block fits.
BeakBlock _layout() => BeakSectionBlock(
  title: 'Layout',
  child: BeakColumnBlock(
    gapInPixels: 12,
    children: [
      const BeakDividerBlock(label: 'Masonry'),
      BeakMasonryBlock(
        columns: 3,
        children: [
          for (final (title, height) in const [
            ('Tall', 240.0),
            ('Short', 120.0),
            ('Medium', 180.0),
          ])
            BeakCardBlock(
              title: title,
              child: BeakImageBlock(
                'https://picsum.photos/seed/\$title/480/360',
                alt: '\$title placeholder',
                heightInPixels: height,
              ),
            ),
        ],
      ),
      const BeakSpacerBlock(heightInPixels: 24),
      const BeakDividerBlock(label: 'Escape hatch'),
      BeakWidgetBlock(
        (context) =>
            const OiLabel.body('An ordinary widget, hosted in a block.'),
      ),
    ],
  ),
);

/// A step-by-step flow, as a block rather than as a resource's form.
///
/// A resource's create form gets its steps from `BeakResource.formSteps`.
/// This is the other case: a flow on a page of its own, whose steps are
/// ordinary blocks and need not be fields at all.
BeakBlock _wizard() => const BeakCardBlock(
  title: 'Wizard',
  child: BeakWizardBlock(
    steps: [
      BeakWizardStep(
        title: 'Account',
        subtitle: 'Who you are',
        icon: OiIcons.user,
        body: BeakTextBlock('Step bodies are blocks, so anything can go here.'),
      ),
      BeakWizardStep(
        title: 'Workspace',
        subtitle: 'Where the work lives',
        icon: OiIcons.building,
        body: BeakTextBlock('A second step, gated by the first.'),
      ),
      BeakWizardStep(
        title: 'Done',
        subtitle: 'Review and finish',
        icon: OiIcons.check,
        body: BeakTextBlock('The last step completes the flow.'),
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
