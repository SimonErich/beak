part of 'beak_rule.dart';

/// Caps a string's length at [maxLength] characters.
final class BeakMaxLength extends BeakRule {
  /// Creates a rule rejecting strings longer than [maxLength].
  const BeakMaxLength(this.maxLength);

  /// Highest accepted number of characters.
  final int maxLength;

  @override
  String get id => 'max_length';

  @override
  String? validate(Object? value) => switch (value) {
    final String text when text.length > maxLength =>
      'Must be at most $maxLength characters.',
    _ => null,
  };
}
