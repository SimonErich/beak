part of 'beak_rule.dart';

/// Requires a number to be at least [min].
final class BeakMin extends BeakRule {
  /// Creates a rule rejecting numbers below [min].
  const BeakMin(this.min);

  /// Lowest accepted value (inclusive).
  final num min;

  @override
  String get id => 'min';

  @override
  String? validate(Object? value) => switch (value) {
    final num number when number < min => 'Must be at least $min.',
    _ => null,
  };
}
