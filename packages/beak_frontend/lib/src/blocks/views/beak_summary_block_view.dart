part of '../beak_block_host.dart';

class _BeakSummaryBlockView extends StatelessWidget {
  const _BeakSummaryBlockView({required this.block});
  final BeakSummaryBlock block;
  @override
  Widget build(BuildContext context) {
    final controller = BeakQueryScope.maybeOf(context);
    return Watch.builder(
      builder: (_) {
        final inherited = switch (block.scope) {
          BeakSummaryScope.active => controller?.query,
          BeakSummaryScope.base => controller?.base,
          BeakSummaryScope.standalone => null,
        };
        return _SummaryQueryView(
          block: block,
          query: inherited == null
              ? block.query
              : block.query.withQuery(inherited),
        );
      },
    );
  }
}

class _SummaryQueryView extends HookWidget {
  const _SummaryQueryView({required this.block, required this.query});
  final BeakSummaryBlock block;
  final BeakSummarySpec query;
  @override
  Widget build(BuildContext context) {
    final source = beakDependencies(context)<BeakDataSource>();
    final revision = useBeakDataRevision(source, table: query.table);
    final attempt = useState(0);
    final table = useState(false);
    final result = useState<BeakSummaryResult?>(null);
    final error = useState<BeakException?>(null);
    final loading = useState(true);
    useEffect(() {
      var current = true;
      loading.value = true;
      error.value = null;
      BeakResourceRepository(source)
          .run(() async {
            if (source case final BeakSummaryDataSource summaries) {
              return summaries.summary(query);
            }
            throw const BeakConfigurationException(
              'This source does not support grouped summaries.',
            );
          })
          .then((response) {
            if (!current) return;
            switch (response) {
              case BeakOk(:final value):
                result.value = value;
              case BeakErr(error: final failure):
                error.value = failure;
            }
            loading.value = false;
          });
      return () => current = false;
    }, [source, jsonEncode(query.toJson()), revision, attempt.value]);
    final strings = BeakLocalizations.of(context);
    if (error.value case final BeakException failure) {
      return OiCard(
        title: OiLabel.h4(block.title),
        child: OiEmptyState.error(
          description: strings.errorMessage(failure),
          actionLabel: strings.retry,
          onAction: () => attempt.value++,
        ),
      );
    }
    if (loading.value) {
      return OiCard(
        title: block.presentation == BeakSummaryPresentation.strip
            ? null
            : OiLabel.h4(block.title),
        padding: block.presentation == BeakSummaryPresentation.strip
            ? EdgeInsets.zero
            : null,
        child: SizedBox(
          height: block.presentation == BeakSummaryPresentation.strip
              ? 56
              : block.heightInPixels,
          child: const Center(child: OiProgress.circular(indeterminate: true)),
        ),
      );
    }
    final summary = result.value;
    if (summary == null || summary.rows.isEmpty) {
      return OiCard(
        title: OiLabel.h4(block.title),
        child: OiLabel.caption(strings.noRecords),
      );
    }
    final formatting = BeakFormatting.of(context);
    String label(BeakSummaryRow row) =>
        block.groupStyle?.call(row).label ??
        (block.groupField == null
            ? row.group.raw?.toString() ?? formatting.emptyValue
            : formatting.formatCell(
                block.groupField!.column,
                BeakRecord(values: {block.groupField!.column.key: row.group}),
              ));
    String display(BeakSummaryRow row, BeakSummaryValue value) {
      final number = row.valueOf(value.measure);
      if (number == null) return formatting.emptyValue;
      if (value.minorUnits && number is int) {
        return formatting.format(
          BeakDecimal(number, scale: value.scale),
          value.format,
        );
      }
      return formatting.format(number, value.format);
    }

    final rows = [...summary.rows];
    if (block.groupOrder.isNotEmpty) {
      int rank(BeakSummaryRow row) {
        final raw = row.group.raw;
        final index = raw == null ? -1 : block.groupOrder.indexOf(raw);
        return index < 0 ? block.groupOrder.length : index;
      }

      rows.sort((a, b) => rank(a).compareTo(rank(b)));
    }
    final palette = [
      context.colors.primary.base,
      context.colors.warning.base,
      context.colors.info.base,
      context.colors.success.base,
      context.colors.error.base,
    ];
    Color color(int i) =>
        block.groupStyle?.call(rows[i]).color ?? palette[i % palette.length];
    final grouped = query.groupByKey != null;
    final segments = grouped
        ? [
            for (var i = 0; i < rows.length; i++)
              OiPieSegment(
                label: label(rows[i]),
                value: (rows[i].valueOf(block.values.first.measure) ?? 0)
                    .toDouble(),
                color: color(i),
              ),
          ]
        : [
            for (var i = 0; i < block.values.length; i++)
              OiPieSegment(
                label: block.values[i].label,
                value: (rows.first.valueOf(block.values[i].measure) ?? 0)
                    .toDouble(),
                color: block.values[i].color ?? palette[i % palette.length],
              ),
          ];
    num normalized(double value) =>
        value == value.truncateToDouble() ? value.toInt() : value;
    Widget legend() => OiChartLegend(
      valueList: true,
      items: [
        for (var i = 0; i < segments.length; i++)
          OiChartLegendItem(
            id: '$i',
            label: segments[i].label,
            color: segments[i].color!,
            value: formatting.format(
              normalized(segments[i].value),
              BeakValueFormat.number,
            ),
          ),
      ],
    );
    final presentation = table.value
        ? BeakSummaryPresentation.table
        : block.presentation;
    final body = switch (presentation) {
      BeakSummaryPresentation.strip => LayoutBuilder(
        builder: (context, constraints) {
          final entries = [
            for (final row in rows)
              for (final value in block.values) (row, value),
          ];
          if (entries.isEmpty) return const SizedBox.shrink();
          final columns = (constraints.maxWidth / 220).floor().clamp(
            1,
            entries.length,
          );
          return Wrap(
            children: [
              for (var i = 0; i < entries.length; i++)
                SizedBox(
                  width: constraints.maxWidth / columns,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        left: i % columns == 0
                            ? BorderSide.none
                            : BorderSide(color: context.colors.borderSubtle),
                        top: i < columns
                            ? BorderSide.none
                            : BorderSide(color: context.colors.borderSubtle),
                      ),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (entries[i].$2.icon case final icon?) ...[
                              OiIcon.raw(
                                icon,
                                size: 16,
                                color: switch (entries[i].$2.iconColor) {
                                  BeakColor.primary =>
                                    context.colors.primary.base,
                                  BeakColor.secondary =>
                                    context.colors.accent.base,
                                  BeakColor.success =>
                                    context.colors.success.base,
                                  BeakColor.warning =>
                                    context.colors.warning.base,
                                  BeakColor.error => context.colors.error.base,
                                  BeakColor.info => context.colors.info.base,
                                  BeakColor.muted ||
                                  null => context.colors.textMuted,
                                },
                              ),
                              const SizedBox(width: 8),
                            ],
                            OiLabel.h4(display(entries[i].$1, entries[i].$2)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: OiLabel.body(
                                entries[i].$2.label,
                                color: context.colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      BeakSummaryPresentation.metrics => Wrap(
        spacing: 24,
        runSpacing: 16,
        children: [
          for (final row in rows)
            for (final value in block.values)
              OiColumn(
                breakpoint: context.breakpoint,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OiLabel.caption(
                    query.groupByKey == null
                        ? value.label
                        : '${label(row)} · ${value.label}',
                  ),
                  OiLabel.h3(display(row, value)),
                ],
              ),
        ],
      ),
      BeakSummaryPresentation.bar => SizedBox(
        height: block.heightInPixels,
        child: OiBarChart(
          label: block.title,
          showValues: block.showValues,
          showLegend: false,
          yAxis: OiChartAxis<num>(
            min: 0,
            max: block.maximum,
            divisions: block.divisions,
          ),
          series: [
            for (var i = 0; i < block.values.length; i++)
              OiBarSeries(
                label: block.values[i].label,
                color: block.values[i].color ?? palette[i % palette.length],
              ),
          ],
          categories: [
            for (final row in rows)
              OiBarCategory(
                label: label(row),
                group: block.groupStyle?.call(row).section,
                emphasized: block.groupStyle?.call(row).emphasized ?? false,
                colors: block.groupStyle?.call(row).color == null
                    ? null
                    : [
                        for (final _ in block.values)
                          block.groupStyle!.call(row).color!,
                      ],
                patterns: [
                  for (final _ in block.values)
                    block.groupStyle?.call(row).hatched == true
                        ? OiBarPattern.diagonal
                        : OiBarPattern.solid,
                ],
                values: [
                  for (final value in block.values)
                    (row.valueOf(value.measure) ?? 0).toDouble(),
                ],
              ),
          ],
        ),
      ),
      BeakSummaryPresentation.donut => SizedBox(
        height: block.heightInPixels,
        child: OiColumn(
          breakpoint: context.breakpoint,
          gap: const OiResponsive<double>(16),
          children: [
            Expanded(
              child: OiDonutChart(
                label: block.title,
                segments: segments,
                innerRadiusFraction: .76,
                showLabels: false,
                showPercentages: false,
                showLegend: false,
                center: block.centerLabel == null
                    ? null
                    : OiColumn(
                        breakpoint: context.breakpoint,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OiLabel.variant(
                            formatting.format(
                              normalized(
                                segments.fold<double>(
                                  0,
                                  (sum, segment) => sum + segment.value,
                                ),
                              ),
                              BeakValueFormat.number,
                            ),
                            variant: OiLabelVariant.h2,
                            style: context.components.chart?.centerValueStyle,
                          ),
                          OiLabel.caption(block.centerLabel!),
                        ],
                      ),
              ),
            ),
            legend(),
          ],
        ),
      ),
      BeakSummaryPresentation.capacity => SizedBox(
        height: block.heightInPixels,
        child: Padding(
          padding: EdgeInsets.only(
            top: context.components.chart?.density?.padding?.top ?? 0,
          ),
          child: OiColumn(
            breakpoint: context.breakpoint,
            gap: const OiResponsive<double>(16),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final row in rows)
                OiCapacityIndicator(
                  label: label(row),
                  subtitle: block.groupStyle?.call(row).section,
                  horizontal: true,
                  trackWidth: 110,
                  height: block.capacity!.trackHeight,
                  value: row.valueOf(block.capacity!.used) ?? 0,
                  max: row.valueOf(block.capacity!.total) ?? 0,
                  color: block.groupStyle?.call(row).color,
                  warningThreshold: block.capacity!.warningThreshold,
                  warningColor: block.capacity!.warningColor,
                  warningText: block.capacity!.warning?.call(row),
                ),
            ],
          ),
        ),
      ),
      BeakSummaryPresentation.table => OiColumn(
        breakpoint: context.breakpoint,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        gap: const OiResponsive<double>(8),
        children: [
          for (final row in rows)
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                OiLabel.bodyStrong(label(row)),
                for (final value in block.values)
                  OiLabel.body('${value.label}: ${display(row, value)}'),
              ],
            ),
        ],
      ),
    };
    if (presentation == BeakSummaryPresentation.strip) {
      return Semantics(
        label: block.title,
        container: true,
        child: OiCard(padding: EdgeInsets.zero, child: body),
      );
    }
    return OiCard(
      title: OiLabel.h4(block.title),
      headerGap: 16,
      subtitle: block.subtitle == null
          ? null
          : OiLabel.body(block.subtitle!, color: context.colors.textMuted),
      trailing: !block.showTableToggle
          ? null
          : OiSegmentedControl<bool>(
              showLabels: false,
              size: OiSegmentedControlSize.small,
              semanticLabel: '${block.title} presentation',
              selected: table.value,
              onChanged: (value) => table.value = value,
              segments: const [
                OiSegment(
                  value: false,
                  label: 'Chart view',
                  icon: OiIcons.chartColumn,
                ),
                OiSegment(
                  value: true,
                  label: 'Table view',
                  icon: OiIcons.table,
                ),
              ],
            ),
      child: OiColumn(
        breakpoint: context.breakpoint,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        gap: const OiResponsive<double>(8),
        children: [
          if (summary.truncated)
            const OiLabel.caption(
              'Only the first groups are shown. Narrow the filters to see every group.',
            ),
          if (block.legend.isNotEmpty)
            OiChartLegend(
              items: [
                for (var i = 0; i < block.legend.length; i++)
                  OiChartLegendItem(
                    id: '$i',
                    label: block.legend[i].label,
                    color: block.legend[i].color,
                    markerShape: block.legend[i].hatched
                        ? OiLegendMarkerShape.hatched
                        : OiLegendMarkerShape.square,
                  ),
              ],
            ),
          body,
          if (block.footer != null) OiLabel.caption(block.footer!(summary)),
        ],
      ),
    );
  }
}
