part of 'beak_rule.dart';

/// Requires a date-time to be strictly after the current instant.
///
/// Handles both typed form values and ISO-8601 values received by the backend.
/// Presence remains the responsibility of [BeakRequired].
final class BeakFutureDate extends BeakRule {
  /// Creates a future-date rule with an optional translated message.
  const BeakFutureDate({this.message = 'Must be in the future.'});

  /// Message returned for past or present values.
  final String message;

  @override
  String get id => 'future_date';

  @override
  String? validate(Object? value) {
    final date = switch (value) {
      final DateTime instant => instant,
      final String text => DateTime.tryParse(text),
      _ => null,
    };
    return date != null && !date.isAfter(DateTime.now()) ? message : null;
  }
}
