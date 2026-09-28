import 'package:beak/beak.dart';

/// Reproducible demo clock. Inject a UTC clock to test cutoff boundaries.
final class FoodioClock {
  /// Pins the prototype to Monday morning unless a test supplies a clock.
  const FoodioClock({
    this.read = demoNow,
    this.kitchenPreparationStart = const BeakTime(8, 0),
  });

  /// Daily planned preparation window; starting kitchen remains a separate action.
  final BeakTime kitchenPreparationStart;

  /// Source of UTC instants, shared by reservations, audit and demo effects.
  final DateTime Function() read;

  /// The reference Monday at 09:42 Vienna summer time.
  static DateTime demoNow() => DateTime.utc(2026, 9, 28, 7, 42);

  /// Current instant normalized for persistence.
  DateTime get now => read().toUtc();

  /// Local time in the reference week, which uses Central European Summer Time.
  DateTime get local => now.add(const Duration(hours: 2));

  /// Delivery calendar date without a time-zone conversion at the UI boundary.
  BeakDate get today =>
      BeakDate.parse(local.toIso8601String().substring(0, 10));

  /// Past dates and same-day changes at or after 10:30 are closed.
  bool changesClosed(BeakDate date) =>
      date.toString().compareTo(today.toString()) < 0 ||
      date == today && (local.hour * 60 + local.minute) >= 630;
}
