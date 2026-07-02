/// Blacklist exclusion validation rule.
library;

import '../validation_result.dart';
import '../validation_rule.dart';

/// Validates that a value is not contained in [forbidden].
final class NotIn extends ValidationRule {
  /// Creates a [NotIn] rule.
  const NotIn(this.forbidden, {this.message});

  /// Blacklist of rejected values.
  final List<Object?> forbidden;

  /// Override message reported when validation fails.
  final String? message;

  @override
  String get name => 'notIn';

  @override
  ValidationResult validate(Object? value) {
    if (value == null) return const ValidationResult.valid();
    if (forbidden.contains(value)) {
      return ValidationResult.invalid(
        message ?? 'Must not be one of: ${forbidden.join(', ')}.',
      );
    }
    return const ValidationResult.valid();
  }
}
