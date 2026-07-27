import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'price_candle.beak.dart';

/// The price-candles resource — the OHLC series behind the candlestick chart.
@Resource()
final class PriceCandle extends BeakSchema {
  /// The bar's label (e.g. the day).
  @Display()
  @Column(label: 'Day', searchable: true)
  late final String? label;

  /// The opening price.
  @Column(prefix: r'$')
  late final double? open;

  /// The session high.
  @Column(prefix: r'$')
  late final double? high;

  /// The session low.
  @Column(prefix: r'$')
  late final double? low;

  /// The closing price.
  @Column(prefix: r'$')
  late final double? close;

  /// Ordering within the series.
  @Column(label: 'Order', sortable: true, min: 0)
  late final int? sortIndex;
}
