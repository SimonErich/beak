import 'package:beak/panel.dart';
import 'package:superdashboard/models/models.dart';

/// The page size for analytics-bound blocks: comfortably above every seeded
/// analytics table, so a chart never renders a silently truncated page
/// (`BeakQuerySpec` defaults to 25 rows per page).
const BeakPagination analyticsPage = BeakPagination(perPage: 500);

/// A chart mapper that keeps only the `time_series_points` rows of [series]
/// and turns them into ordered points — so one tall table feeds every chart.
///
/// Every field is read through the generated record view, which returns each
/// column's declared Dart type and parses the wire shapes a source may send
/// (Postgres hands decimals over as strings).
BeakChartMapper seriesPoints(String series) => (records) {
  final points = [
    for (final point in records.map(TimeSeriesPointRecord.of))
      if (point.series == series)
        (
          index: point.sortIndex ?? 0,
          label: point.label,
          value: point.value ?? 0,
        ),
  ]..sort((a, b) => a.index.compareTo(b.index));
  return [
    for (final point in points)
      BeakChartPoint(label: point.label, value: point.value),
  ];
};

/// Maps `purchase_sources` rows onto donut segments sized by revenue.
List<BeakChartPoint> purchaseSourcePoints(List<BeakRecord> records) => [
  for (final source in records.map(PurchaseSourceRecord.of))
    BeakChartPoint(label: source.label, value: source.total ?? 0),
];

/// Maps `products` rows onto bubble points: price × stock, sized by cost.
List<BeakBubblePoint> productBubblePoints(List<BeakRecord> records) => [
  for (final product in records.map(ProductRecord.of))
    BeakBubblePoint(
      x: product.price,
      y: (product.stock ?? 0).toDouble(),
      size: product.cost ?? 0,
      label: product.name,
    ),
];

/// Maps `price_candles` rows onto ordered OHLC candles.
List<BeakCandle> priceCandles(List<BeakRecord> records) {
  final candles = records.map(PriceCandleRecord.of).toList()
    ..sort((a, b) => (a.sortIndex ?? 0).compareTo(b.sortIndex ?? 0));
  return [
    for (final (index, candle) in candles.indexed)
      BeakCandle(
        x: index.toDouble(),
        open: candle.open ?? 0,
        high: candle.high ?? 0,
        low: candle.low ?? 0,
        close: candle.close ?? 0,
      ),
  ];
}

/// Maps `activity_heatmap` rows onto matrix cells.
List<BeakMatrixCell> activityHeatCells(List<BeakRecord> records) => [
  for (final cell in records.map(ActivityHeatCellRecord.of))
    BeakMatrixCell(
      row: cell.rowLabel ?? '',
      column: cell.columnLabel ?? '',
      value: (cell.value ?? 0).toDouble(),
    ),
];
