part of '../beak_block_host.dart';

/// Fetches a [BeakCandlestickChartBlock]'s records and draws them on
/// `OiCandlestickChart`.
class _BeakCandlestickChartBlockView extends HookWidget {
  const _BeakCandlestickChartBlockView({required this.block});

  final BeakCandlestickChartBlock block;

  @override
  Widget build(BuildContext context) {
    final dataSource = beakDependencies(context)<BeakDataSource>();
    final candles = _useBlockRead(
      dataSource,
      block.query,
      identity: block,
      initial: const <BeakCandle>[],
      map: (page) => block.map(page.items),
    );

    return _withReadFailure(
      context,
      candles,
      OiCard(
        title: OiLabel.smallStrong(block.title),
        child: SizedBox(
          height: block.heightInPixels,
          child: OiCandlestickChart<BeakCandle>(
            label: block.title,
            series: [
              OiCandlestickSeries<BeakCandle>(
                id: block.title,
                label: block.title,
                data: candles.data,
                xMapper: (candle) => candle.x,
                openMapper: (candle) => candle.open,
                highMapper: (candle) => candle.high,
                lowMapper: (candle) => candle.low,
                closeMapper: (candle) => candle.close,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
