part of '../beak_block_host.dart';

/// Fetches a [BeakMetricBlock]'s aggregate (and optional prior period)
/// through the panel's data source and renders it on an `OiCard`, with a
/// delta against the prior period and progress towards the target.
///
/// Loading and failures are explicit, a failed load can be retried, and
/// writes to the aggregated tables refetch the numbers.
class _BeakMetricBlockView extends HookWidget {
  const _BeakMetricBlockView({required this.block});

  final BeakMetricBlock block;

  @override
  Widget build(BuildContext context) {
    // --8<-- [start:metricState]
    final dataSource = beakDependencies(context)<BeakDataSource>();
    final loaded = useState<({num value, num? previous})?>(null);
    final loading = useState(true);
    final error = useState<BeakException?>(null);
    final attempt = useState(0);
    final revision = useBeakDataRevision(
      dataSource,
      table: block.aggregate.table,
    );
    // --8<-- [end:metricState]
    final priorTable = block.previous?.table;
    final priorRevision = useBeakDataRevision(
      priorTable == null || priorTable == block.aggregate.table
          ? null
          : dataSource,
      table: priorTable,
    );
    useEffect(
      () {
        var cancelled = false;
        Future<void> load() async {
          final result = await BeakResourceRepository(dataSource).run(
            () async => (
              value: await dataSource.aggregate(block.aggregate),
              previous: switch (block.previous) {
                final BeakAggregateSpec prior => await dataSource.aggregate(
                  prior,
                ),
                null => null,
              },
            ),
          );
          if (cancelled) {
            return;
          }
          loading.value = false;
          switch (result) {
            case BeakOk(:final value):
              loaded.value = value;
              error.value = null;
            case BeakErr(error: final failure):
              error.value = failure;
          }
        }

        loading.value = true;
        load();
        return () => cancelled = true;
      },
      [
        dataSource,
        block.aggregate,
        block.previous,
        revision,
        priorRevision,
        attempt.value,
      ],
    );

    final strings = BeakLocalizations.of(context);
    final formatting = BeakFormatting.of(context);
    return OiCard(
      child: OiColumn(
        breakpoint: context.breakpoint,
        gap: const OiResponsive<double>(8),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OiRow(
            breakpoint: context.breakpoint,
            gap: const OiResponsive<double>(8),
            children: [
              if (block.icon case final IconData icon)
                OiIcon.decorative(icon: icon),
              Expanded(child: OiLabel.small(block.label)),
            ],
          ),
          if (loading.value)
            OiProgress.linear(indeterminate: true, label: strings.loading)
          else if (error.value case final BeakException failure) ...[
            OiLabel.small(strings.errorMessage(failure)),
            OiButton.ghost(label: strings.retry, onTap: () => attempt.value++),
          ] else if (loaded.value case (:final value, :final previous)) ...[
            OiLabel.h2(_formatted(formatting, value)),
            if (previous case final num prior when prior != 0)
              _delta(context, formatting, (value - prior) / prior.abs()),
            if (block.target case final num target when target > 0)
              OiProgress.linear(
                value: (value / target).clamp(0, 1).toDouble(),
                label:
                    '${_formatted(formatting, value)} / '
                    '${_formatted(formatting, target)}',
              ),
          ],
        ],
      ),
    );
  }

  /// [value] in the block's display format followed by its unit, scaling
  /// minor units first.
  ///
  /// Integral minor units stay exact as a [BeakDecimal] for number and
  /// currency, the formats that render one; a percentage takes the scaled
  /// rate.
  String _formatted(BeakFormatting formatting, num value) {
    final Object display = switch ((block.minorUnits, value, block.format)) {
      (false, _, _) => value,
      (
        true,
        final int units,
        BeakValueFormat.number || BeakValueFormat.currency,
      ) =>
        BeakDecimal(units, scale: block.scale),
      _ => value / math.pow(10, block.scale),
    };
    final text = formatting.format(display, block.format);
    return switch (block.unit) {
      final String unit => '$text $unit',
      null => text,
    };
  }

  /// The signed percentage change, coloured and marked by its direction.
  Widget _delta(BuildContext context, BeakFormatting formatting, num change) {
    final text = '${change > 0 ? '+' : ''}${formatting.percent(change)}';
    if (change == 0) {
      return OiLabel.small(text, color: context.colors.textMuted);
    }
    final rising = change > 0;
    final color = rising
        ? context.colors.success.base
        : context.colors.error.base;
    return OiRow(
      breakpoint: context.breakpoint,
      gap: const OiResponsive<double>(4),
      children: [
        OiIcon.decorative(
          icon: rising ? OiIcons.trendingUp : OiIcons.trendingDown,
          size: 16,
          color: color,
        ),
        OiLabel.small(text, color: color),
      ],
    );
  }
}
