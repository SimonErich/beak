part of 'beak_rule.dart';

/// Requires a value to be one of [allowed].
final class BeakInList<T> extends BeakRule {
  /// Creates a rule accepting only values from [allowed].
  const BeakInList(this.allowed);

  /// The accepted values.
  final List<T> allowed;

  @override
  String get id => 'in_list';

  @override
  String? validate(Object? value) {
    if (value == null || allowed.contains(value)) {
      return null;
    }
    return 'Must be one of: ${allowed.join(', ')}.';
  }
}
