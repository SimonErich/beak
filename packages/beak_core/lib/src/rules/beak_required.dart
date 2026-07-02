part of 'beak_rule.dart';

/// Requires a value to be present: non-null and, for strings and
/// collections, non-empty (whitespace-only strings count as empty).
///
/// `false` and `0` are present values and pass.
final class BeakRequired extends BeakRule {
  /// Creates the presence rule.
  const BeakRequired();

  static const String _message = 'This field is required.';

  @override
  String get id => 'required';

  @override
  String? validate(Object? value) => switch (value) {
    null => _message,
    final String text when text.trim().isEmpty => _message,
    final Iterable<Object?> items when items.isEmpty => _message,
    _ => null,
  };
}
