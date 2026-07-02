/// Required field validation rule.
library;

import '../validation_result.dart';
import '../validation_rule.dart';

/// Rejects `null` values and empty collections / strings.
final class Required extends ValidationRule {
  /// Creates a [Required] rule.
  const Required({this.message = 'This field is required.'});

  /// Override message reported when validation fails.
  final String message;

  @override
  String get name => 'required';

  @override
  ValidationResult validate(Object? value) {
    final empty = switch (value) {
      null => true,
      final String s => s.isEmpty,
      final Iterable<Object?> i => i.isEmpty,
      final Map<Object?, Object?> m => m.isEmpty,
      _ => false,
    };
    if (empty) return ValidationResult.invalid(message);
    return const ValidationResult.valid();
  }
}
