/// UUID validation rule.
library;

import '../validation_result.dart';
import '../validation_rule.dart';

/// Validates that a value is a canonical UUID string.
///
/// Accepts versions 1-8 in the 8-4-4-4-12 hex layout.
final class Uuid extends ValidationRule {
  /// Creates a [Uuid] rule.
  const Uuid({this.message = 'Must be a valid UUID.'});

  /// Override message reported when validation fails.
  final String message;

  static final RegExp _pattern = RegExp(
    r'^[0-9a-fA-F]{8}-'
    r'[0-9a-fA-F]{4}-'
    r'[1-8][0-9a-fA-F]{3}-'
    r'[89abAB][0-9a-fA-F]{3}-'
    r'[0-9a-fA-F]{12}$',
  );

  @override
  String get name => 'uuid';

  @override
  ValidationResult validate(Object? value) {
    if (value == null) return const ValidationResult.valid();
    if (value is! String || !_pattern.hasMatch(value)) {
      return ValidationResult.invalid(message);
    }
    return const ValidationResult.valid();
  }
}
