part of '../beak_block_host.dart';

/// Fetches a [BeakBubbleChartBlock]'s records and draws them on
/// `OiBubbleChart`.
class _BeakBubbleChartBlockView extends HookWidget {
  const _BeakBubbleChartBlockView({required this.block});

  final BeakBubbleChartBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakLocator<BeakDataSource>();
    final points = useState(const <BeakBubblePoint>[]);

    useEffect(() {
      var cancelled = false;
      Future<void> load() async {
        final result = await BeakResourceRepository(
          dataSource,
        ).query(block.query);
        if (cancelled) {
          return;
        }
        if (result case BeakOk(:final value)) {
          points.value = block.map(value.items);
        }
      }

      load();
      return () => cancelled = true;
    }, [dataSource, block]);

    return OiCard(
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
                  for (final point in points.value)
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
    );
  }
}
