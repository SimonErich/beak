part of 'beak_rule.dart';

/// Requires a value to be present: non-null and, for strings and
/// collections, non-empty (whitespace-only strings count as empty).
///
/// `false` and `0` are present values and pass.
final class BeakRequired extends BeakRule {
  /// Creates the presence rule.
  // --8<-- [start:BeakRequired]
  const BeakRequired({this.allowEmpty = false});

  /// Whether a present empty string or collection is valid. Null still fails.
  final bool allowEmpty;
  // --8<-- [end:BeakRequired]

  static const String _message = 'This field is required.';

  @override
  String get id => 'required';

  @override
  String? validate(Object? value) => switch (value) {
    null => _message,
    final String text when !allowEmpty && text.trim().isEmpty => _message,
    final Iterable<Object?> items when !allowEmpty && items.isEmpty => _message,
    final Map<Object?, Object?> items when !allowEmpty && items.isEmpty =>
      _message,
    final BeakJsonObject object when !allowEmpty && object.entries.isEmpty =>
      _message,
    _ => null,
  };
}
