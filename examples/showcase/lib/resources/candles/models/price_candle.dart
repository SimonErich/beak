import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'price_candle.beak.dart';

/// One trading day of the birdseed price, as open, high, low and close.
@Resource()
final class PriceCandle extends BeakSchema {
  /// The trading day.
  @Display()
  @Column(sortable: true)
  late final DateTime tradedOn;

  /// Price at the open, per kilogram.
  @Column(prefix: '€', precision: 2)
  late final double open;

  /// Highest price of the day.
  @Column(prefix: '€', precision: 2)
  late final double high;

  /// Lowest price of the day.
  @Column(prefix: '€', precision: 2)
  late final double low;

  /// Price at the close.
  @Column(prefix: '€', precision: 2)
  late final double close;
}
