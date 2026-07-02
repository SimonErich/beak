part of 'beak_rule.dart';

/// Requires a number to be at most [max].
final class BeakMax extends BeakRule {
  /// Creates a rule rejecting numbers above [max].
  const BeakMax(this.max);

  /// Highest accepted value (inclusive).
  final num max;

  @override
  String get id => 'max';

  @override
  String? validate(Object? value) => switch (value) {
    final num number when number > max => 'Must be at most $max.',
    _ => null,
  };
}
