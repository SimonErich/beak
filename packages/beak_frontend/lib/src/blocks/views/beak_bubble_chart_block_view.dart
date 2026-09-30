part of '../beak_block_host.dart';

/// Fetches a [BeakBubbleChartBlock]'s records and draws them on
/// `OiBubbleChart`.
class _BeakBubbleChartBlockView extends HookWidget {
  const _BeakBubbleChartBlockView({required this.block});

  final BeakBubbleChartBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakDependencies(context)<BeakDataSource>();
    final points = _useBlockRead(
      dataSource,
      block.query,
      identity: block,
      initial: const <BeakBubblePoint>[],
      map: (page) => block.map(page.items),
    );

    return _withReadFailure(
      context,
      points,
      OiCard(
        title: OiLabel.smallStrong(block.title),
        child: SizedBox(
          height: block.heightInPixels,
          child: OiBubbleChart(
            label: block.title,
            data: OiBubbleChartData(
              series: [
                OiBubbleSeries(
                  name: block.title,
                  points: [
                    for (final point in points.data)
                      OiBubblePoint(
                        x: point.x,
                        y: point.y,
                        size: point.size,
                        label: point.label,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
