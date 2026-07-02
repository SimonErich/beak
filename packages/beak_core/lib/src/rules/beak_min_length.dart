part of 'beak_rule.dart';

/// Requires a string to be at least [minLength] characters long.
///
/// The empty string fails like any other short string; pair with
/// [BeakRequired] when presence should be enforced too.
final class BeakMinLength extends BeakRule {
  /// Creates a rule rejecting strings shorter than [minLength].
  const BeakMinLength(this.minLength);

  /// Lowest accepted number of characters.
  final int minLength;

  @override
  String get id => 'min_length';

  @override
  String? validate(Object? value) => switch (value) {
    final String text when text.length < minLength =>
      'Must be at least $minLength characters.',
    _ => null,
  };
}
