import 'package:beak/panel.dart';

/// The page size for analytics-bound blocks: comfortably above every seeded
/// analytics table, so a chart never renders a silently truncated page
/// (`BeakQuerySpec` defaults to 25 rows per page).
const BeakPagination analyticsPage = BeakPagination(perPage: 500);

/// Parses a value that may arrive as a number (in-memory) or a string
/// (Postgres decimals over HTTP).
double _asDouble(Object? raw) => switch (raw) {
  final num value => value.toDouble(),
  final String value => double.tryParse(value) ?? 0,
  _ => 0,
};

/// A chart mapper that keeps only the `time_series_points` rows of [series]
/// and turns them into ordered points — so one tall table feeds every chart.
BeakChartMapper seriesPoints(String series) => (records) {
  final points = [
    for (final record in records)
      if (record['series']?.raw == series)
        (
          index: (record['sort_index']?.raw as num?)?.toInt() ?? 0,
          label: record['label']?.raw?.toString() ?? '',
          value: _asDouble(record['value']?.raw),
        ),
  ]..sort((a, b) => a.index.compareTo(b.index));
  return [
    for (final point in points)
      BeakChartPoint(label: point.label, value: point.value),
  ];
};

/// Maps `purchase_sources` rows onto donut segments sized by revenue.
List<BeakChartPoint> purchaseSourcePoints(List<BeakRecord> records) => [
  for (final record in records)
    BeakChartPoint(
      label: record['label']?.raw?.toString() ?? '',
      value: _asDouble(record['total']?.raw),
    ),
];

/// Maps `products` rows onto bubble points: price × stock, sized by cost.
List<BeakBubblePoint> productBubblePoints(List<BeakRecord> records) => [
  for (final record in records)
    BeakBubblePoint(
      x: _asDouble(record['price']?.raw),
      y: _asDouble(record['stock']?.raw),
      size: _asDouble(record['cost']?.raw),
      label: record['name']?.raw?.toString(),
    ),
];

/// Maps `price_candles` rows onto ordered OHLC candles.
List<BeakCandle> priceCandles(List<BeakRecord> records) {
  final rows = [...records]
    ..sort((a, b) {
      final ai = (a['sort_index']?.raw as num?)?.toInt() ?? 0;
      final bi = (b['sort_index']?.raw as num?)?.toInt() ?? 0;
      return ai.compareTo(bi);
    });
  return [
    for (final (index, record) in rows.indexed)
      BeakCandle(
        x: index.toDouble(),
        open: _asDouble(record['open']?.raw),
        high: _asDouble(record['high']?.raw),
        low: _asDouble(record['low']?.raw),
        close: _asDouble(record['close']?.raw),
      ),
  ];
}

/// Maps `activity_heatmap` rows onto matrix cells.
List<BeakMatrixCell> activityHeatCells(List<BeakRecord> records) => [
  for (final record in records)
    BeakMatrixCell(
      row: record['row_label']?.raw?.toString() ?? '',
      column: record['column_label']?.raw?.toString() ?? '',
      value: _asDouble(record['value']?.raw),
    ),
];
