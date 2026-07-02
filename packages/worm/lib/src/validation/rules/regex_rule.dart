/// Regular-expression validation rule.
library;

import '../validation_result.dart';
import '../validation_rule.dart';

/// Validates that a string matches [pattern].
final class Regex extends ValidationRule {
  /// Creates a [Regex] rule.
  const Regex(this.pattern, {this.message});

  /// Compiled regular expression to match against.
  final RegExp pattern;

  /// Override message reported when validation fails.
  final String? message;

  @override
  String get name => 'regex';

  @override
  ValidationResult validate(Object? value) {
    if (value == null) return const ValidationResult.valid();
    if (value is! String || !pattern.hasMatch(value)) {
      return ValidationResult.invalid(
        message ?? 'Does not match the required pattern.',
      );
    }
    return const ValidationResult.valid();
  }
}
