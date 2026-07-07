import 'package:beak_core/beak_core.dart';
import 'package:beak_frontend/beak_frontend.dart';

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
