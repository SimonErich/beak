/// Date-after validation rule.
library;

import '../validation_result.dart';
import '../validation_rule.dart';

/// Validates that a value is a [DateTime] strictly after [bound].
final class After extends ValidationRule {
  /// Creates an [After] rule.
  const After(this.bound, {this.message});

  /// Lower bound; the validated date must be strictly later.
  final DateTime bound;

  /// Override message reported when validation fails.
  final String? message;

  @override
  String get name => 'after';

  @override
  ValidationResult validate(Object? value) {
    if (value == null) return const ValidationResult.valid();
    final parsed = _coerce(value);
    if (parsed == null || !parsed.isAfter(bound)) {
      return ValidationResult.invalid(
        message ?? 'Must be a date after ${bound.toIso8601String()}.',
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
