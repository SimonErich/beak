part of 'beak_rule.dart';

/// Requires a number to be at most [max].
final class BeakMax extends BeakRule {
  /// Creates a rule rejecting numbers above [max].
  // --8<-- [start:BeakMax]
  const BeakMax(this.max);

  /// Highest accepted value (inclusive).
  final num max;
  // --8<-- [end:BeakMax]

  @override
  String get id => 'max';

  @override
  String? validate(Object? value) => switch (value) {
    final num number when number > max => 'Must be at most $max.',
    final BeakDecimal amount when _compareDecimalBound(amount, max) > 0 =>
      'Must be at most $max.',
    _ => null,
  };
}
