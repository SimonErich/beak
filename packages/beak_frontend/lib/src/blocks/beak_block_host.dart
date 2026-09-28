import 'dart:convert';

import 'package:beak_core/beak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:obers_ui_charts/obers_ui_charts.dart';
import 'package:signals/signals_flutter.dart';

import '../dashboard/beak_chart.dart';
import '../dashboard/beak_stat.dart';
import '../data/beak_resource_repository.dart';
import '../data/beak_data_changes.dart';
import '../query/beak_query_scope.dart';
import '../localization/beak_localizations.dart';
import '../detail/beak_record_scope.dart';
import '../detail/relation_manager.dart';
import '../di/beak_locator.dart';
import '../formatting/beak_formatting.dart';
import '../table/beak_data_table.dart';
import '../table/column_cell_renderer.dart';
import 'beak_block.dart';

part 'views/beak_calendar_block_view.dart';
part 'views/beak_bubble_chart_block_view.dart';
part 'views/beak_candlestick_chart_block_view.dart';
part 'views/beak_chart_block_view.dart';
part 'views/beak_heatmap_chart_block_view.dart';
part 'views/beak_chat_block_view.dart';
part 'views/beak_faq_block_view.dart';
part 'views/beak_file_manager_block_view.dart';
part 'views/beak_gallery_block_view.dart';
part 'views/beak_inbox_block_view.dart';
part 'views/beak_invoice_block_view.dart';
part 'views/beak_kanban_block_view.dart';
part 'views/beak_kpi_block_view.dart';
part 'views/beak_metric_block_view.dart';
part 'views/beak_summary_block_view.dart';
part 'views/beak_pricing_block_view.dart';
part 'views/beak_carousel_block_view.dart';
part 'views/beak_map_block_view.dart';
part 'views/beak_radial_slider_block_view.dart';
part 'views/beak_profile_block_view.dart';
part 'views/beak_record_readers.dart';
part 'views/beak_table_block_view.dart';
part 'views/beak_tile_map_block_view.dart';
part 'views/beak_timeline_block_view.dart';
part 'views/beak_video_block_view.dart';

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
    final BeakBubbleChartBlock bubble => _BeakBubbleChartBlockView(
      block: bubble,
    ),
    final BeakCandlestickChartBlock candles => _BeakCandlestickChartBlockView(
      block: candles,
    ),
    final BeakHeatmapChartBlock heatmap => _BeakHeatmapChartBlockView(
      block: heatmap,
    ),
    final BeakTableBlock table => _BeakTableBlockView(block: table),
    final BeakMetricBlock metric => _BeakMetricBlockView(block: metric),
    final BeakSummaryBlock summary => _BeakSummaryBlockView(block: summary),
    final BeakMapBlock map => _BeakMapBlockView(block: map),
    final BeakTileMapBlock tileMap => _BeakTileMapBlockView(block: tileMap),
    final BeakCarouselBlock carousel => _BeakCarouselBlockView(block: carousel),
    final BeakRadialSliderBlock slider => _BeakRadialSliderBlockView(
      block: slider,
    ),
    final BeakCalendarBlock calendar => _BeakCalendarBlockView(block: calendar),
    final BeakKanbanBlock kanban => _BeakKanbanBlockView(block: kanban),
    final BeakChatBlock chat => _BeakChatBlockView(block: chat),
    final BeakInboxBlock inbox => _BeakInboxBlockView(block: inbox),
    final BeakFileManagerBlock files => _BeakFileManagerBlockView(block: files),
    final BeakInvoiceBlock invoice => _BeakInvoiceBlockView(block: invoice),
    final BeakProfileBlock profile => _BeakProfileBlockView(block: profile),
    final BeakPricingBlock pricing => _BeakPricingBlockView(block: pricing),
    final BeakFaqBlock faq => _BeakFaqBlockView(block: faq),
    final BeakAccordionBlock accordion => _accordion(accordion),
    final BeakBreadcrumbsBlock crumbs => _breadcrumbs(context, crumbs),
    final BeakMasonryBlock masonry => _masonry(context, masonry),
    final BeakWizardBlock wizard => _wizard(wizard),
    final BeakThreePaneBlock panes => _threePane(panes),
    final BeakAlertBlock alert => _alert(alert),
    final BeakBadgeBlock badge => _badge(badge),
    final BeakProgressBlock progress => _progress(progress),
    final BeakRatingBlock rating => _rating(rating),
    final BeakGalleryBlock gallery => _BeakGalleryBlockView(block: gallery),
    final BeakVideoBlock video => _BeakVideoBlockView(block: video),
    final BeakTimelineBlock timeline => _BeakTimelineBlockView(block: timeline),
    final BeakIconGalleryBlock icons => _iconGallery(context, icons),
    final BeakFieldBlock field => _field(context, field),
    final BeakFieldGroupBlock group => _fieldGroup(context, group),
    final BeakRelationBlock relation => _relation(context, relation),
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

  Widget _row(BuildContext context, BeakRowBlock block) {
    Widget row({bool expand = false}) => OiRow(
      breakpoint: context.breakpoint,
      gap: OiResponsive<double>(block.gapInPixels),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (final child in block.children)
          if (expand)
            Expanded(
              flex: child.span?.columns ?? 1,
              child: BeakBlockHost(block: child),
            )
          else
            BeakBlockHost(block: child),
      ],
    );
    if (!block.expand || block.children.isEmpty) return row();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth) return row();
        final available =
            constraints.maxWidth -
            block.gapInPixels * (block.children.length - 1);
        final totalWeight = block.children.fold(
          0,
          (total, child) => total + (child.span?.columns ?? 1),
        );
        if (block.children.any(
          (child) =>
              available * (child.span?.columns ?? 1) / totalWeight <
              block.minChildWidthInPixels,
        )) {
          return OiColumn(
            breakpoint: context.breakpoint,
            gap: OiResponsive<double>(block.gapInPixels),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final child in block.children) BeakBlockHost(block: child),
            ],
          );
        }
        return row(expand: true);
      },
    );
  }

  Widget _grid(BuildContext context, BeakGridBlock block) {
    Widget grid(int? columns) => OiGrid(
      breakpoint: context.breakpoint,
      columns: columns == null ? null : OiResponsive<int>(columns),
      minColumnWidth: switch (block.minColumnWidthInPixels) {
        final double width => OiResponsive<double>(width),
        null => null,
      },
      gap: OiResponsive<double>(block.gapInPixels),
      children: [for (final child in block.children) _spanned(child)],
    );

    final columns = block.columns;
    if (columns == null || columns <= 1 || block.minChildWidthInPixels == 0) {
      return grid(columns);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth =
            (constraints.maxWidth - block.gapInPixels * (columns - 1)) /
            columns;
        final stack =
            constraints.hasBoundedWidth &&
            block.children.any((child) {
              final span = (child.span?.columns ?? 1).clamp(1, columns);
              final width = trackWidth * span + block.gapInPixels * (span - 1);
              return width < block.minChildWidthInPixels;
            });
        return grid(stack ? 1 : columns);
      },
    );
  }

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
    headerGap: block.headerGap,
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

  Widget _wizard(BeakWizardBlock block) => OiWizard(
    stepperStyle: block.stepperStyle,
    onComplete: block.onComplete == null
        ? null
        : (_) => block.onComplete!.call(),
    steps: [
      for (final step in block.steps)
        OiWizardStep(
          title: step.title,
          subtitle: step.subtitle,
          icon: step.icon,
          validate: step.canAdvance == null
              ? null
              : (_) => step.canAdvance!.call(),
          builder: (_) => BeakBlockHost(block: step.body),
        ),
    ],
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

  /// Renders one read-only field from the surrounding record scope.
  Widget _field(BuildContext context, BeakFieldBlock block) {
    final scope = BeakRecordScope.of(context);
    if (scope == null) {
      return const SizedBox.shrink();
    }
    final String label = block.label ?? block.column.label;
    final Widget value = renderBeakCell(
      context,
      column: block.column,
      record: scope.record,
      renderContext: BeakContext.detail,
    );
    return switch (block.layout) {
      BeakFieldLayout.stacked => OiColumn(
        breakpoint: context.breakpoint,
        gap: const OiResponsive<double>(4),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [OiLabel.caption(label), value],
      ),
      BeakFieldLayout.inline => OiRow(
        breakpoint: context.breakpoint,
        gap: const OiResponsive<double>(12),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 160, child: OiLabel.smallStrong(label)),
          Expanded(child: value),
        ],
      ),
    };
  }

  Widget _fieldGroup(BuildContext context, BeakFieldGroupBlock block) => OiGrid(
    breakpoint: context.breakpoint,
    columns: OiResponsive<int>(block.columnCount),
    gap: const OiResponsive<double>(16),
    children: [
      for (final column in block.columns)
        _field(context, BeakFieldBlock(column)),
    ],
  );

  Widget _relation(BuildContext context, BeakRelationBlock block) {
    final scope = BeakRecordScope.of(context);
    if (scope == null) {
      return const SizedBox.shrink();
    }
    final Object? id = scope.model.primaryKeyOf(scope.record);
    if (id == null) {
      return const SizedBox.shrink();
    }
    return BeakRelationManager(
      parentModel: scope.model,
      parentId: id,
      relationship: block.relationship,
      dataSource: beakDependencies(context)<BeakDataSource>(),
      // The page that loaded this record may have loaded its relations with
      // it; when it did, the manager paints without a query of its own.
      initialRecords: scope.record.relations[block.relationship.key],
    );
  }

  Widget _iconGallery(BuildContext context, BeakIconGalleryBlock block) =>
      OiGrid(
        breakpoint: context.breakpoint,
        columns: OiResponsive<int>(block.columns),
        gap: const OiResponsive<double>(12),
        children: [
          for (final item in block.items)
            OiCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OiIcon.decorative(icon: item.icon.icon, size: 26),
                  const SizedBox(height: 8),
                  OiLabel.caption(item.label),
                ],
              ),
            ),
        ],
      );

  Widget _alert(BeakAlertBlock block) => switch (block.level) {
    BeakAlertLevel.info => OiBanner.info(message: block.message),
    BeakAlertLevel.success => OiBanner.success(message: block.message),
    BeakAlertLevel.warning => OiBanner.warning(message: block.message),
    BeakAlertLevel.error => OiBanner.error(message: block.message),
  };

  Widget _badge(BeakBadgeBlock block) =>
      OiBadge.soft(label: block.label, color: _badgeColor(block.color));

  OiBadgeColor _badgeColor(BeakColor color) => switch (color) {
    BeakColor.primary => OiBadgeColor.primary,
    BeakColor.secondary => OiBadgeColor.accent,
    BeakColor.success => OiBadgeColor.success,
    BeakColor.warning => OiBadgeColor.warning,
    BeakColor.error => OiBadgeColor.error,
    BeakColor.info => OiBadgeColor.info,
    BeakColor.muted => OiBadgeColor.neutral,
  };

  Widget _progress(BeakProgressBlock block) =>
      OiProgress.linear(value: block.value, label: block.label);

  Widget _rating(BeakRatingBlock block) => OiStarRating(
    value: block.value,
    maxStars: block.maxStars,
    readOnly: block.readOnly,
    allowHalf: true,
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
