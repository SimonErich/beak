/// Date / parseable-date validation rule.
library;

import '../validation_result.dart';
import '../validation_rule.dart';

/// Validates that a value is a [DateTime] or an ISO-8601 date string.
final class DateRule extends ValidationRule {
  /// Creates a [DateRule].
  const DateRule({this.message = 'Must be a valid date.'});

  /// Override message reported when validation fails.
  final String message;

  @override
  String get name => 'date';

  @override
  ValidationResult validate(Object? value) {
    if (value == null) return const ValidationResult.valid();
    if (value is DateTime) return const ValidationResult.valid();
    if (value is String && DateTime.tryParse(value) != null) {
      return const ValidationResult.valid();
    }
    return ValidationResult.invalid(message);
  }
}
