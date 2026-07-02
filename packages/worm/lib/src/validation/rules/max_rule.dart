/// Numeric maximum validation rule.
library;

import '../validation_result.dart';
import '../validation_rule.dart';

/// Rejects numeric values greater than [bound].
final class Max extends ValidationRule {
  /// Creates a [Max] rule.
  const Max(this.bound, {this.message});

  /// Maximum permitted value, inclusive.
  final num bound;

  /// Override message reported when validation fails.
  final String? message;

  @override
  String get name => 'max';

  @override
  ValidationResult validate(Object? value) {
    if (value == null) return const ValidationResult.valid();
    if (value is! num || value > bound) {
      return ValidationResult.invalid(message ?? 'Must be at most $bound.');
    }
    return const ValidationResult.valid();
  }
}
