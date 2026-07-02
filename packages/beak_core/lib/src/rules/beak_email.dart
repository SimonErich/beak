part of 'beak_rule.dart';

/// Requires a string to look like an email address
/// (`local@domain.tld`, no whitespace).
final class BeakEmail extends BeakRule {
  /// Creates the email-format rule.
  const BeakEmail();

  static final RegExp _pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  String get id => 'email';

  @override
  String? validate(Object? value) => switch (value) {
    final String text when !_pattern.hasMatch(text) =>
      'Must be a valid email address.',
    _ => null,
  };
}
