/// Email validation rule.
library;

import '../validation_result.dart';
import '../validation_rule.dart';

/// Validates that a value is a well-formed email address.
///
/// Pragmatic, RFC 5321-inspired pattern: one local part, a single
/// `@`, a dot-separated domain. Null and missing values pass — chain
/// with `Required` to reject them.
final class Email extends ValidationRule {
  /// Creates an [Email] rule.
  const Email({this.message = 'Must be a valid email address.'});

  /// Override message reported when validation fails.
  final String message;

  static final RegExp _pattern = RegExp(
    r'^[A-Za-z0-9._%+\-]+@'
    r'[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?'
    r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$',
  );

  @override
  String get name => 'email';

  @override
  ValidationResult validate(Object? value) {
    if (value == null) return const ValidationResult.valid();
    if (value is! String || !_pattern.hasMatch(value)) {
      return ValidationResult.invalid(message);
    }
    return const ValidationResult.valid();
  }
}
