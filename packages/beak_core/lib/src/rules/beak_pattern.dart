part of 'beak_rule.dart';

/// Requires a string to match [regex].
final class BeakPattern extends BeakRule {
  /// Creates a rule matching strings against [regex]; [message] overrides
  /// the default error text.
  const BeakPattern(this.regex, {this.message});

  /// Regular-expression source the value must match.
  final String regex;

  /// Custom error message, if any.
  final String? message;

  @override
  String get id => 'pattern';

  @override
  String? validate(Object? value) => switch (value) {
    final String text when !RegExp(regex).hasMatch(text) =>
      message ?? 'Must match the expected format.',
    _ => null,
  };
}
