part of 'beak_block.dart';

/// A data-bound candlestick (OHLC) chart. Renders onto `OiCandlestickChart`.
final class BeakCandlestickChartBlock extends BeakBlock {
  /// Creates a candlestick chart titled [title] over [query].
  const BeakCandlestickChartBlock({
    required this.title,
    required this.query,
    required this.map,
    this.heightInPixels = 320,
    super.span,
  });

  /// The chart heading.
  final String title;

  /// The query supplying the records.
  final BeakQuerySpec query;

  /// Maps the records to OHLC candles.
  final BeakCandleMapper map;

  /// The chart height in pixels.
  final double heightInPixels;
}
