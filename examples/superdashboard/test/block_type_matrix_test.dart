import 'package:beak/panel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superdashboard/beak/panel.g.dart';

/// Every block type Beak has, one enum value each.
///
/// [BeakBlock] is a sealed hierarchy, and Dart cannot list a sealed type's
/// subtypes at runtime — so [_describe] switches over it exhaustively.
/// Adding a block stops this file compiling until someone adds an arm; the
/// arm forces a value here; and this test then demands the superdashboard
/// actually use it.
///
/// That chain is the point. `examples/superdashboard` is what the Blocks
/// pages quote, so a block type nothing here builds is a block type nobody
/// can see working.
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
  kpi,
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
  table,
  tabs,
  text,
  threePane,
  tileMap,
  timeline,
  video,
  widget,
  wizard,
}

/// What [block] is, and the blocks nested inside it.
///
/// One switch rather than two, because a container that gains a slot has to
/// be found in exactly one place.
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
  BeakKpiBlock() => (_BlockKind.kpi, const []),
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
  BeakWizardBlock(:final steps) => (
    _BlockKind.wizard,
    [for (final step in steps) step.body],
  ),
};

/// Every block kind reachable from [config], by the route that reaches it.
Map<_BlockKind, String> _kindsIn(BeakPanelConfig config) {
  final found = <_BlockKind, String>{};
  void walk(BeakBlock block, String route) {
    final (kind, children) = _describe(block);
    found.putIfAbsent(kind, () => route);
    for (final child in children) {
      walk(child, route);
    }
  }

  for (final resource in config.resources) {
    walk(resource.effectiveDetail, '${resource.model.table} detail');
    if (resource.formLayout case final BeakBlock form) {
      walk(form, '${resource.model.table} form');
    }
    // A view mode builds its own block, so a calendar or a board is only
    // reachable by asking it to.
    for (final view in resource.viewModes) {
      walk(view.build(resource.model), '${resource.model.table} view mode');
    }
  }
  for (final screen in config.pages) {
    walk(screen.body, 'screen ${screen.path}');
  }
  return found;
}

void main() {
  test('every block type is built somewhere in this example', () {
    final Map<_BlockKind, String> found = _kindsIn(buildBeakPanel());

    final missing = [
      for (final kind in _BlockKind.values)
        if (!found.containsKey(kind)) kind.name,
    ];
    expect(
      missing,
      isEmpty,
      reason:
          'examples/superdashboard is what the Blocks pages quote, so a '
          'block type nothing here builds is one nobody can see working. '
          'Add it to a detail layout or a screen under lib/screens/.\n'
          '${found.length} of ${_BlockKind.values.length} are built.',
    );
  });
}
