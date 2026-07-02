/// URL validation rule.
library;

import '../validation_result.dart';
import '../validation_rule.dart';

/// Validates that a value is a parseable absolute URL.
///
/// Requires a scheme and host. `mailto:`, opaque URIs without
/// a host, or relative paths are rejected.
final class Url extends ValidationRule {
  /// Creates a [Url] rule.
  const Url({this.message = 'Must be a valid URL.'});

  /// Override message reported when validation fails.
  final String message;

  @override
  String get name => 'url';

  @override
  ValidationResult validate(Object? value) {
    if (value == null) return const ValidationResult.valid();
    if (value is! String) {
      return ValidationResult.invalid(message);
    }
    final parsed = Uri.tryParse(value);
    if (parsed == null ||
        !parsed.isAbsolute ||
        parsed.host.isEmpty ||
        parsed.scheme.isEmpty) {
      return ValidationResult.invalid(message);
    }
    return const ValidationResult.valid();
  }
}
