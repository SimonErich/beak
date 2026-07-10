part of '../beak_block_host.dart';

/// Fetches a [BeakCandlestickChartBlock]'s records and draws them on
/// `OiCandlestickChart`.
class _BeakCandlestickChartBlockView extends HookWidget {
  const _BeakCandlestickChartBlockView({required this.block});

  final BeakCandlestickChartBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakLocator<BeakDataSource>();
    final candles = useState(const <BeakCandle>[]);

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
          candles.value = block.map(value.items);
        }
      }

      load();
      return () => cancelled = true;
    }, [dataSource, block]);

    return OiCard(
      title: OiLabel.smallStrong(block.title),
      child: SizedBox(
        height: block.heightInPixels,
        child: OiCandlestickChart<BeakCandle>(
          label: block.title,
          series: [
            OiCandlestickSeries<BeakCandle>(
              id: block.title,
              label: block.title,
              data: candles.value,
              xMapper: (candle) => candle.x,
              openMapper: (candle) => candle.open,
              highMapper: (candle) => candle.high,
              lowMapper: (candle) => candle.low,
              closeMapper: (candle) => candle.close,
            ),
          ],
        ),
      ),
    );
  }
}
