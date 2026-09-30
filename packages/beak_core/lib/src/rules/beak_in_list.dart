part of 'beak_rule.dart';

/// Requires a value to be one of [allowed].
///
/// `null` passes (leave presence to [BeakRequired]); any non-null value
/// outside [allowed] fails. The type parameter [T] keeps the accepted set
/// type-safe.
///
/// ```dart
/// static const size = BeakStringColumn(
///   key: 'size',
///   label: 'Size',
///   rules: [BeakInList<String>(['S', 'M', 'L'])],
/// );
/// ```
final class BeakInList<T> extends BeakRule {
  /// Creates a rule accepting only values from [allowed].
  // --8<-- [start:BeakInList]
  const BeakInList(this.allowed);

  /// The accepted values.
  final List<T> allowed;
  // --8<-- [end:BeakInList]

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
