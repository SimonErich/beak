/// Date-before validation rule.
library;

import '../validation_result.dart';
import '../validation_rule.dart';

/// Validates that a value is a [DateTime] strictly before [bound].
final class Before extends ValidationRule {
  /// Creates a [Before] rule.
  const Before(this.bound, {this.message});

  /// Upper bound; the validated date must be strictly earlier.
  final DateTime bound;

  /// Override message reported when validation fails.
  final String? message;

  @override
  String get name => 'before';

  @override
  ValidationResult validate(Object? value) {
    if (value == null) return const ValidationResult.valid();
    final parsed = _coerce(value);
    if (parsed == null || !parsed.isBefore(bound)) {
      return ValidationResult.invalid(
        message ?? 'Must be a date before ${bound.toIso8601String()}.',
      );
    }
    return const ValidationResult.valid();
  }

  static DateTime? _coerce(Object value) => switch (value) {
    final DateTime d => d,
    final String s => DateTime.tryParse(s),
    _ => null,
  };
}
