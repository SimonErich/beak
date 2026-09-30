part of '../beak_block_host.dart';

/// Runs a [BeakChartBlock]'s query through the data source, maps the records
/// to typed points, and draws the configured chart family inside a card.
class _BeakChartBlockView extends HookWidget {
  const _BeakChartBlockView({required this.block});

  final BeakChartBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakDependencies(context)<BeakDataSource>();
    final points = _useBlockRead(
      dataSource,
      block.query,
      identity: block,
      initial: const <BeakChartPoint>[],
      map: (page) => block.map(page.items),
    );

    return _withReadFailure(
      context,
      points,
      OiCard(
        title: OiLabel.smallStrong(block.title),
        child: SizedBox(
          height: block.heightInPixels,
          child: beakChartWidget(block.type, block.title, points.data),
        ),
      ),
    );
  }
}
