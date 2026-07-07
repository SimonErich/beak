part of '../beak_block_host.dart';

/// Fetches a [BeakKpiBlock]'s value (and optional prior period) through the
/// data source and renders an `OiKpiCard` with a live delta.
class _BeakKpiBlockView extends HookWidget {
  const _BeakKpiBlockView({required this.block});

  final BeakKpiBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakLocator<BeakDataSource>();
    final value = useState<num?>(null);
    final previous = useState<num?>(null);

    useEffect(() {
      var cancelled = false;
      Future<void> load() async {
        final loaded = await dataSource.aggregate(block.value);
        final prior = block.previous == null
            ? null
            : await dataSource.aggregate(block.previous!);
        if (cancelled) {
          return;
        }
        value.value = loaded;
        previous.value = prior;
      }

      load();
      return () => cancelled = true;
    }, [dataSource, block]);

    return OiKpiCard(
      showSparkline: false,
      showDelta: block.previous != null,
      showTarget: block.target != null,
      metric: OiKpiMetric(
        id: block.title,
        title: block.title,
        value: value.value ?? 0,
        previousValue: previous.value,
        target: block.target,
        format: _formatOf(block),
      ),
    );
  }

  OiKpiFormat _formatOf(BeakKpiBlock block) => switch (block.format) {
    BeakKpiFormat.number => OiKpiFormat.number(decimals: block.decimals),
    BeakKpiFormat.currency => OiKpiFormat.currency(
      symbol: block.currencySymbol,
      decimals: block.decimals,
    ),
    BeakKpiFormat.percent => OiKpiFormat.percentage(decimals: block.decimals),
  };
}
