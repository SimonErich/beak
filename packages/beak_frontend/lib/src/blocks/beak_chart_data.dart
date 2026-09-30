import 'package:beak_core/beak_core.dart';

/// The chart families a `BeakChartBlock` can render as.
///
/// Every family here maps from the same `List<BeakChartPoint>` shape. Richer
/// shapes have blocks of their own: `BeakBubbleChartBlock` ([BeakBubblePoint]),
/// `BeakCandlestickChartBlock` ([BeakCandle]) and `BeakHeatmapChartBlock`
/// ([BeakMatrixCell]).
// --8<-- [start:BeakChartType]
enum BeakChartType {
  /// A line chart over the mapped points.
  line,

  /// A vertical bar chart, one category per point.
  bar,

  /// A pie chart, one segment per point.
  pie,

  /// A donut (ring) chart, one segment per point.
  donut,

  /// An area chart over the mapped points.
  area,

  /// A radar chart — one axis per point, a single series of their values.
  radar,

  /// A funnel chart — one stage per point.
  funnel,
}
// --8<-- [end:BeakChartType]

/// One typed chart data point — the shape [BeakChartMapper]s produce, so
/// mapping records to series never touches `dynamic`.
final class BeakChartPoint {
  /// Creates a point labelled [label] with [value]; [x] positions it on
  /// continuous axes (defaults to its index).
  const BeakChartPoint({required this.label, required this.value, this.x});

  /// The category/point label.
  final String label;

  /// The measured value.
  final double value;

  /// Explicit x position for line/area charts, if any.
  final double? x;
}

/// Maps a query's records onto typed chart points.
///
/// Implementations read fields through the model's generated field
/// references, never string keys:
///
/// ```dart
/// List<BeakChartPoint> stockPerVariant(List<BeakRecord> records) => [
///   for (final record in records)
///     BeakChartPoint(
///       label: ProductVariantModel.name.readFrom(record) ?? '',
///       value: (ProductVariantModel.stock.readFrom(record) ?? 0).toDouble(),
///     ),
/// ];
/// ```
// --8<-- [start:BeakChartMapper]
typedef BeakChartMapper =
    List<BeakChartPoint> Function(List<BeakRecord> records);
// --8<-- [end:BeakChartMapper]

/// One point of a bubble chart: a position ([x], [y]) plus a magnitude
/// ([size], the third dimension), optionally [label]led.
final class BeakBubblePoint {
  /// Creates a bubble at ([x], [y]) sized by [size].
  const BeakBubblePoint({
    required this.x,
    required this.y,
    required this.size,
    this.label,
  });

  /// The horizontal position.
  final double x;

  /// The vertical position.
  final double y;

  /// The bubble's magnitude (its area encodes this).
  final double size;

  /// An optional label for the point.
  final String? label;
}

/// Produces a bubble chart's points from a query's records.
typedef BeakBubbleMapper =
    List<BeakBubblePoint> Function(List<BeakRecord> records);

/// One candle of an OHLC chart at position [x] (a time or index).
final class BeakCandle {
  /// Creates a candle at [x] with the four prices.
  const BeakCandle({
    required this.x,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  /// The horizontal position (e.g. a day index or epoch millis).
  final double x;

  /// The opening price.
  final double open;

  /// The session high.
  final double high;

  /// The session low.
  final double low;

  /// The closing price.
  final double close;
}

/// Produces a candlestick chart's candles from a query's records.
typedef BeakCandleMapper = List<BeakCandle> Function(List<BeakRecord> records);

/// One cell of a heatmap matrix: a [value] at ([row], [column]).
final class BeakMatrixCell {
  /// Creates a heatmap cell.
  const BeakMatrixCell({
    required this.row,
    required this.column,
    required this.value,
  });

  /// The row key.
  final String row;

  /// The column key.
  final String column;

  /// The cell's magnitude.
  final double value;
}

/// Produces a heatmap's cells from a query's records.
typedef BeakMatrixMapper =
    List<BeakMatrixCell> Function(List<BeakRecord> records);
