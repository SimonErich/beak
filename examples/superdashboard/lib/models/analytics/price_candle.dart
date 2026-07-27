import 'package:beak_core/beak_core.dart';

import '../shared/shared_columns.dart';

/// Typed columns of the price-candles resource — one OHLC bar of a daily
/// price series, feeding the candlestick chart.
abstract final class PriceCandleColumns {
  /// The bar's label (e.g. the day).
  static const label = BeakStringColumn(
    key: 'label',
    label: 'Day',
    searchable: true,
  );

  /// The opening price.
  static const open = BeakDecimalColumn(
    key: 'open',
    label: 'Open',
    prefix: r'$',
  );

  /// The session high.
  static const high = BeakDecimalColumn(
    key: 'high',
    label: 'High',
    prefix: r'$',
  );

  /// The session low.
  static const low = BeakDecimalColumn(key: 'low', label: 'Low', prefix: r'$');

  /// The closing price.
  static const close = BeakDecimalColumn(
    key: 'close',
    label: 'Close',
    prefix: r'$',
  );

  /// Ordering within the series.
  static const sortIndex = BeakIntColumn(
    key: 'sort_index',
    label: 'Order',
    min: 0,
    sortable: true,
  );

  /// All columns, in display order.
  static const List<BeakColumn> values = [
    SharedColumns.id,
    label,
    open,
    high,
    low,
    close,
    sortIndex,
  ];
}

/// The price-candles resource — the OHLC series behind the candlestick chart.
final class PriceCandleModel extends BeakModel {
  /// Creates the price-candles model.
  const PriceCandleModel();

  @override
  String get table => 'price_candles';

  @override
  String get displayColumnKey => 'label';

  @override
  List<BeakColumn> get columns => PriceCandleColumns.values;
}
