part of '../beak_block_host.dart';

/// Renders a [BeakMetricBlock] through the shared `BeakStatCard`, fetching
/// the aggregate live from the panel's data source.
class _BeakMetricBlockView extends StatelessWidget {
  const _BeakMetricBlockView({required this.block});

  final BeakMetricBlock block;

  @override
  Widget build(BuildContext context) => BeakStatCard(
    dataSource: beakDependencies(context)<BeakDataSource>(),
    stat: BeakStat(
      label: block.label,
      aggregate: block.aggregate,
      icon: block.icon,
      prefix: block.prefix,
      suffix: block.suffix,
    ),
  );
}
