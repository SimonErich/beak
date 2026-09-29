import 'package:beak/panel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:showcase/main.dart';
import 'package:showcase/resources/keepers/keeper_sheet.dart';

/// Every block type Beak has, one enum value each.
///
/// [BeakBlock] is a sealed hierarchy, and Dart cannot list a sealed type's
/// subtypes at runtime, so [_describe] switches over it exhaustively. Adding a
/// block stops this file compiling until someone adds an arm; the arm forces a
/// value here; and this test then demands the Aviary actually builds it.
///
/// That chain is the point. The docs quote this example, so a block type
/// nothing here builds is a block type nobody can see working.
// --8<-- [start:BlockKind]
enum _BlockKind {
  accordion,
  alert,
  badge,
  breadcrumbs,
  bubbleChart,
  calendar,
  candlestickChart,
  card,
  carousel,
  chart,
  chat,
  column,
  divider,
  faq,
  field,
  fieldGroup,
  fileManager,
  gallery,
  grid,
  heatmapChart,
  iconGallery,
  image,
  inbox,
  invoice,
  kanban,
  map,
  markdown,
  masonry,
  metric,
  pricing,
  profile,
  progress,
  radialSlider,
  rating,
  relation,
  row,
  section,
  spacer,
  summary,
  table,
  tabs,
  text,
  threePane,
  tileMap,
  timeline,
  video,
  widget,
}
// --8<-- [end:BlockKind]

/// What [block] is, and the blocks nested inside it.
///
/// One switch rather than two, because a container that gains a slot has to be
/// found in exactly one place. There is no default branch on purpose.
// --8<-- [start:describe]
(_BlockKind, List<BeakBlock>) _describe(BeakBlock block) => switch (block) {
  BeakAccordionBlock(:final items) => (
    _BlockKind.accordion,
    [for (final item in items) item.content],
  ),
  BeakAlertBlock() => (_BlockKind.alert, const []),
  BeakBadgeBlock() => (_BlockKind.badge, const []),
  BeakBreadcrumbsBlock() => (_BlockKind.breadcrumbs, const []),
  BeakBubbleChartBlock() => (_BlockKind.bubbleChart, const []),
  BeakCalendarBlock() => (_BlockKind.calendar, const []),
  BeakCandlestickChartBlock() => (_BlockKind.candlestickChart, const []),
  BeakCardBlock(:final child, :final footer) => (
    _BlockKind.card,
    [child, ?footer],
  ),
  BeakCarouselBlock() => (_BlockKind.carousel, const []),
  BeakChartBlock() => (_BlockKind.chart, const []),
  BeakChatBlock() => (_BlockKind.chat, const []),
  BeakColumnBlock(:final children) => (_BlockKind.column, children),
  BeakDividerBlock() => (_BlockKind.divider, const []),
  BeakFaqBlock() => (_BlockKind.faq, const []),
  BeakFieldBlock() => (_BlockKind.field, const []),
  BeakFieldGroupBlock() => (_BlockKind.fieldGroup, const []),
  BeakFileManagerBlock() => (_BlockKind.fileManager, const []),
  BeakGalleryBlock() => (_BlockKind.gallery, const []),
  BeakGridBlock(:final children) => (_BlockKind.grid, children),
  BeakHeatmapChartBlock() => (_BlockKind.heatmapChart, const []),
  BeakIconGalleryBlock() => (_BlockKind.iconGallery, const []),
  BeakImageBlock() => (_BlockKind.image, const []),
  BeakInboxBlock() => (_BlockKind.inbox, const []),
  BeakInvoiceBlock() => (_BlockKind.invoice, const []),
  BeakKanbanBlock() => (_BlockKind.kanban, const []),
  BeakMapBlock() => (_BlockKind.map, const []),
  BeakMarkdownBlock() => (_BlockKind.markdown, const []),
  BeakMasonryBlock(:final children) => (_BlockKind.masonry, children),
  BeakMetricBlock() => (_BlockKind.metric, const []),
  BeakPricingBlock() => (_BlockKind.pricing, const []),
  BeakProfileBlock() => (_BlockKind.profile, const []),
  BeakProgressBlock() => (_BlockKind.progress, const []),
  BeakRadialSliderBlock() => (_BlockKind.radialSlider, const []),
  BeakRatingBlock() => (_BlockKind.rating, const []),
  BeakRelationBlock() => (_BlockKind.relation, const []),
  BeakRowBlock(:final children) => (_BlockKind.row, children),
  BeakSectionBlock(:final child) => (_BlockKind.section, [child]),
  BeakSpacerBlock() => (_BlockKind.spacer, const []),
  BeakSummaryBlock() => (_BlockKind.summary, const []),
  BeakTableBlock() => (_BlockKind.table, const []),
  BeakTabsBlock(:final tabs) => (
    _BlockKind.tabs,
    [for (final tab in tabs) tab.content],
  ),
  BeakTextBlock() => (_BlockKind.text, const []),
  BeakThreePaneBlock(:final left, :final middle, :final right) => (
    _BlockKind.threePane,
    [left, middle, ?right],
  ),
  BeakTileMapBlock() => (_BlockKind.tileMap, const []),
  BeakTimelineBlock() => (_BlockKind.timeline, const []),
  BeakVideoBlock() => (_BlockKind.video, const []),
  BeakWidgetBlock() => (_BlockKind.widget, const []),
};
// --8<-- [end:describe]

/// Every block kind reachable from the panel's pages and the keeper read
/// screen, mapped to the first route that builds it.
Map<_BlockKind, String> _kindsBuilt() {
  final found = <_BlockKind, String>{};
  void walk(BeakBlock block, String route) {
    final (kind, children) = _describe(block);
    found.putIfAbsent(kind, () => route);
    for (final child in children) {
      walk(child, route);
    }
  }

  for (final page in buildPanel().pages) {
    walk(page.body, page.path);
  }
  walk(keeperSheetBlock(), 'keepers read screen');
  return found;
}

void main() {
  test('every block type is built somewhere in the Aviary', () {
    final found = _kindsBuilt();

    final missing = [
      for (final kind in _BlockKind.values)
        if (!found.containsKey(kind)) kind.name,
    ];
    expect(
      missing,
      isEmpty,
      reason:
          'The Aviary is what the docs quote, so a block type nothing here '
          'builds is one nobody can see working. Add it to a page under '
          'lib/pages/.\n${found.length} of ${_BlockKind.values.length} '
          'are built.',
    );
  });

  test('the record blocks live on the keeper read screen', () {
    final found = _kindsBuilt();

    expect(found[_BlockKind.field], 'keepers read screen');
    expect(found[_BlockKind.fieldGroup], 'keepers read screen');
    expect(found[_BlockKind.relation], 'keepers read screen');
  });
}
