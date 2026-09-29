import 'package:beak/panel.dart';

import '../resources/habitats/models/habitat.dart';
import '../resources/candles/models/price_candle.dart';
import '../resources/sightings/models/sighting.dart';
import '../resources/specimens/models/specimen.dart';

/// A page large enough to hold every seeded row, so a chart never draws a
/// silently truncated first page (a query returns 25 rows by default).
const BeakPagination chartPage = BeakPagination(perPage: 500);

/// The weekday names a heat map labels its rows with, Monday first.
const List<String> weekdayLabels = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// Every day's sightings, oldest first.
BeakQuerySpec sightingsByDay() => const SightingModel().query(
  sorts: [SightingModel.spottedOn.ascending()],
  pagination: chartPage,
);

/// The four largest habitats, largest first.
///
/// Four, because a pie chart lays its legend out in the height it reserves
/// for one row, and more names than one row holds would overflow it.
BeakQuerySpec habitatsByCapacity() => const HabitatModel().query(
  sorts: [HabitatModel.capacity.descending()],
  pagination: const BeakPagination(perPage: 4),
);

/// Every specimen with a recorded wingspan.
BeakQuerySpec specimensBySize() =>
    const SpecimenModel().query(pagination: chartPage);

/// Every trading day, oldest first.
BeakQuerySpec candlesByDay() => const PriceCandleModel().query(
  sorts: [PriceCandleModel.tradedOn.ascending()],
  pagination: chartPage,
);

String _dayLabel(DateTime day) =>
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// One line point per sighting day.
List<BeakChartPoint> sightingPoints(List<BeakRecord> records) => [
  for (final record in records)
    if (SightingModel.spottedOn.readFrom(record) case final DateTime day)
      BeakChartPoint(
        label: _dayLabel(day),
        value: (SightingModel.birdsSeen.readFrom(record) ?? 0).toDouble(),
      ),
];

/// One category per habitat, sized by capacity.
List<BeakChartPoint> habitatPoints(List<BeakRecord> records) => [
  for (final record in records)
    BeakChartPoint(
      label: HabitatModel.name.readFrom(record) ?? '',
      value: (HabitatModel.capacity.readFrom(record) ?? 0).toDouble(),
    ),
];

/// One bubble per specimen: wingspan by weight, sized by clutch.
List<BeakBubblePoint> specimenBubbles(List<BeakRecord> records) => [
  for (final record in records)
    BeakBubblePoint(
      x: (SpecimenModel.wingspanInCentimeters.readFrom(record) ?? 0).toDouble(),
      y: SpecimenModel.weightInGrams.readFrom(record) ?? 0,
      size: (SpecimenModel.clutchSize.readFrom(record) ?? 1).toDouble(),
      label: SpecimenModel.commonName.readFrom(record),
    ),
];

/// One candle per trading day, numbered from the first.
List<BeakCandle> priceCandles(List<BeakRecord> records) => [
  for (final (index, record) in records.indexed)
    BeakCandle(
      x: index.toDouble(),
      open: PriceCandleModel.open.readFrom(record) ?? 0,
      high: PriceCandleModel.high.readFrom(record) ?? 0,
      low: PriceCandleModel.low.readFrom(record) ?? 0,
      close: PriceCandleModel.close.readFrom(record) ?? 0,
    ),
];

/// The columns of the sightings heat map: one per week since the first count.
List<String> weekLabels(int weekCount) => [
  for (var week = 1; week <= weekCount; week++) 'Week $week',
];

/// Heat-map cells: weekday against week, valued by birds seen.
List<BeakMatrixCell> sightingCells(List<BeakRecord> records) {
  final days = [
    for (final record in records)
      if (SightingModel.spottedOn.readFrom(record) case final DateTime day)
        (day: day, birds: SightingModel.birdsSeen.readFrom(record) ?? 0),
  ];
  if (days.isEmpty) return const [];
  final first = days
      .map((entry) => entry.day)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  return [
    for (final (:day, :birds) in days)
      BeakMatrixCell(
        row: weekdayLabels[day.weekday - 1],
        column: 'Week ${day.difference(first).inDays ~/ 7 + 1}',
        value: birds.toDouble(),
      ),
  ];
}
