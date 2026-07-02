/// Numeric minimum validation rule.
library;

import '../validation_result.dart';
import '../validation_rule.dart';

/// Rejects numeric values less than [bound].
final class Min extends ValidationRule {
  /// Creates a [Min] rule.
  const Min(this.bound, {this.message});

  /// Minimum permitted value, inclusive.
  final num bound;

  /// Override message reported when validation fails.
  final String? message;

  @override
  String get name => 'min';

  @override
  ValidationResult validate(Object? value) {
    if (value == null) return const ValidationResult.valid();
    if (value is! num || value < bound) {
      return ValidationResult.invalid(message ?? 'Must be at least $bound.');
    }
    return const ValidationResult.valid();
  }
}
