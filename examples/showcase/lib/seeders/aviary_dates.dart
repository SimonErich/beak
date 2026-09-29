/// The fixed days the seed data and the pages that filter by them agree on.
///
/// Pure constants with no imports, like `AviaryIds`. Counts and prices use
/// fixed days so the charts show the same figures whenever the demo runs;
/// only the tasks are relative to the day they were seeded, so the board and
/// the calendar are never empty.
abstract final class AviaryDates {
  /// The first day of the four-week bird count.
  static final countStart = DateTime.utc(2026, 9);

  /// The number of days counted.
  static const countDays = 28;

  /// The first day of the second half of the count, which the metric compares
  /// with the first half.
  static final secondFortnightStart = DateTime.utc(2026, 9, 15);

  /// The first trading day of the birdseed price history.
  static final pricesStart = DateTime.utc(2026, 9);

  /// The number of trading days recorded.
  static const priceDays = 20;
}
