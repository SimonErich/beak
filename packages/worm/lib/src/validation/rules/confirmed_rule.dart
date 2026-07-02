/// Confirmation match validation rule.
library;

import '../validation_result.dart';
import '../validation_rule.dart';

/// Validates that the field equals the value supplied in [other].
///
/// Typical use: confirming a password by comparing against a
/// captured `password_confirmation` value.
final class Confirmed extends ValidationRule {
  /// Creates a [Confirmed] rule with the confirmation value to match.
  const Confirmed(this.other, {this.message});

  /// The confirmation value the field must equal.
  final Object? other;

  /// Override message reported when validation fails.
  final String? message;

  @override
  String get name => 'confirmed';

  @override
  ValidationResult validate(Object? value) {
    if (value == null) return const ValidationResult.valid();
    if (value != other) {
      return ValidationResult.invalid(
        message ?? 'Confirmation does not match.',
      );
    }
    return const ValidationResult.valid();
  }
}
