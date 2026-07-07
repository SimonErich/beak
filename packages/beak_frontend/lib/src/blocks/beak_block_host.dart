import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:obers_ui_charts/obers_ui_charts.dart';

import '../dashboard/beak_chart.dart';
import '../dashboard/beak_stat.dart';
import '../data/beak_resource_repository.dart';
import '../di/beak_locator.dart';
import '../table/beak_data_table.dart';
import 'beak_block.dart';

part 'views/beak_chart_block_view.dart';
part 'views/beak_kpi_block_view.dart';
part 'views/beak_metric_block_view.dart';
part 'views/beak_table_block_view.dart';

/// Renders a [BeakBlock] tree onto obers_ui widgets — the single renderer
/// behind custom pages, resource view modes, and overlay bodies.
///
/// The switch over the sealed union is exhaustive, so adding a block type
/// without teaching the host about it is a compile error.
///
/// ```dart
/// BeakBlockHost(
///   block: BeakCardBlock(
///     title: 'Revenue',
///     child: BeakTextBlock('42'),
///   ),
/// )
/// ```
class BeakBlockHost extends StatelessWidget {
  /// Creates a host rendering [block].
  const BeakBlockHost({required this.block, super.key});

  /// The block tree to render.
  final BeakBlock block;

  @override
  Widget build(BuildContext context) => switch (block) {
    final BeakColumnBlock column => _column(context, column),
    final BeakRowBlock row => _row(context, row),
    final BeakGridBlock grid => _grid(context, grid),
    final BeakCardBlock card => _card(card),
    final BeakSectionBlock section => _section(context, section),
    final BeakTabsBlock tabs => _BeakTabsHost(block: tabs),
    final BeakKpiBlock kpi => _BeakKpiBlockView(block: kpi),
    final BeakChartBlock chart => _BeakChartBlockView(block: chart),
    final BeakTableBlock table => _BeakTableBlockView(block: table),
    final BeakMetricBlock metric => _BeakMetricBlockView(block: metric),
    final BeakAccordionBlock accordion => _accordion(accordion),
    final BeakBreadcrumbsBlock crumbs => _breadcrumbs(context, crumbs),
    final BeakMasonryBlock masonry => _masonry(context, masonry),
    final BeakThreePaneBlock panes => _threePane(panes),
    final BeakTextBlock text => _text(text),
    final BeakImageBlock image => _image(image),
    final BeakMarkdownBlock markdown => OiMarkdown(data: markdown.source),
    final BeakDividerBlock divider => _divider(divider),
    final BeakSpacerBlock spacer => SizedBox(height: spacer.heightInPixels),
    final BeakWidgetBlock widget => Builder(builder: widget.builder),
  };

  Widget _column(BuildContext context, BeakColumnBlock block) => OiColumn(
    breakpoint: context.breakpoint,
    gap: OiResponsive<double>(block.gapInPixels),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [for (final child in block.children) BeakBlockHost(block: child)],
  );

  Widget _row(BuildContext context, BeakRowBlock block) => OiRow(
    breakpoint: context.breakpoint,
    gap: OiResponsive<double>(block.gapInPixels),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [for (final child in block.children) BeakBlockHost(block: child)],
  );

  Widget _grid(BuildContext context, BeakGridBlock block) => OiGrid(
    breakpoint: context.breakpoint,
    columns: switch (block.columns) {
      final int columns => OiResponsive<int>(columns),
      null => null,
    },
    minColumnWidth: switch (block.minColumnWidthInPixels) {
      final double width => OiResponsive<double>(width),
      null => null,
    },
    gap: OiResponsive<double>(block.gapInPixels),
    children: [for (final child in block.children) _spanned(child)],
  );

  /// Wraps a grid child in its [BeakBlock.span] placement, when declared.
  Widget _spanned(BeakBlock child) {
    final host = BeakBlockHost(block: child);
    final span = child.span;
    if (span == null) {
      return host;
    }
    return OiSpan(
      data: OiSpanData(
        columnSpan: OiResponsive<int>(span.columns),
        rowSpan: OiResponsive<int>(span.rows),
      ),
      child: host,
    );
  }

  Widget _card(BeakCardBlock block) => OiCard(
    title: switch (block.title) {
      final String title => OiLabel.h4(title),
      null => null,
    },
    subtitle: switch (block.subtitle) {
      final String subtitle => OiLabel.caption(subtitle),
      null => null,
    },
    footer: switch (block.footer) {
      final BeakBlock footer => BeakBlockHost(block: footer),
      null => null,
    },
    child: BeakBlockHost(block: block.child),
  );

  Widget _section(BuildContext context, BeakSectionBlock block) => OiSection(
    breakpoint: context.breakpoint,
    gap: const OiResponsive<double>(8),
    children: [
      OiLabel.h3(block.title),
      if (block.description case final String description)
        OiLabel.caption(description),
      BeakBlockHost(block: block.child),
    ],
  );

  Widget _accordion(BeakAccordionBlock block) => OiAccordion(
    allowMultiple: block.allowMultiple,
    sections: [
      for (final item in block.items)
        OiAccordionSection(
          title: item.title,
          initiallyExpanded: item.initiallyExpanded,
          content: BeakBlockHost(block: item.content),
        ),
    ],
  );

  Widget _breadcrumbs(BuildContext context, BeakBreadcrumbsBlock block) =>
      OiBreadcrumbs(
        items: [
          for (final item in block.items)
            OiBreadcrumbItem(
              label: item.label,
              onTap: switch (item.route) {
                final String route => () => GoRouter.of(context).go(route),
                null => null,
              },
            ),
        ],
      );

  Widget _masonry(BuildContext context, BeakMasonryBlock block) => OiMasonry(
    breakpoint: context.breakpoint,
    columns: OiResponsive<int>(block.columns),
    gap: OiResponsive<double>(block.gapInPixels),
    children: [for (final child in block.children) BeakBlockHost(block: child)],
  );

  Widget _threePane(BeakThreePaneBlock block) => OiThreeColumnLayout(
    label: block.label,
    leftColumn: BeakBlockHost(block: block.left),
    middleColumn: BeakBlockHost(block: block.middle),
    rightColumn: switch (block.right) {
      final BeakBlock right => BeakBlockHost(block: right),
      null => null,
    },
    showRightColumn: block.right != null,
    leftColumnWidth: block.leftWidthInPixels,
    rightColumnWidth: block.rightWidthInPixels,
  );

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

  Widget _image(BeakImageBlock block) => OiImage(
    src: block.url,
    alt: block.alt,
    width: block.widthInPixels,
    height: block.heightInPixels,
    fit: block.fit,
  );

  Widget _divider(BeakDividerBlock block) => switch (block.label) {
    final String label => OiDivider.withLabel(label, spacing: 12),
    null => const OiDivider(spacing: 12),
  };
}

/// Owns the selected-tab state of a [BeakTabsBlock].
class _BeakTabsHost extends HookWidget {
  const _BeakTabsHost({required this.block});

  final BeakTabsBlock block;

  @override
  Widget build(BuildContext context) {
    final selected = useState(block.initialIndex);
    final active = block.tabs[selected.value];
    return OiTabs(
      tabs: [
        for (final tab in block.tabs)
          OiTabItem(label: tab.label, icon: tab.icon),
      ],
      selectedIndex: selected.value,
      onSelected: (index) => selected.value = index,
      content: BeakBlockHost(block: active.content),
    );
  }
}
