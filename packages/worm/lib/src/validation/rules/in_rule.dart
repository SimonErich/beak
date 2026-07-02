/// Whitelist membership validation rule.
library;

import '../validation_result.dart';
import '../validation_rule.dart';

/// Validates that a value is contained in [allowed].
final class In extends ValidationRule {
  /// Creates an [In] rule.
  const In(this.allowed, {this.message});

  /// Whitelist of accepted values.
  final List<Object?> allowed;

  /// Override message reported when validation fails.
  final String? message;

  @override
  String get name => 'in';

  @override
  ValidationResult validate(Object? value) {
    if (value == null) return const ValidationResult.valid();
    if (!allowed.contains(value)) {
      return ValidationResult.invalid(
        message ?? 'Must be one of: ${allowed.join(', ')}.',
      );
    }
    return const ValidationResult.valid();
  }
}
