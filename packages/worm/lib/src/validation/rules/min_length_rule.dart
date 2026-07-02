/// Minimum length validation rule.
library;

import '../validation_result.dart';
import '../validation_rule.dart';

/// Rejects strings or iterables shorter than [length].
final class MinLength extends ValidationRule {
  /// Creates a [MinLength] rule.
  const MinLength(this.length, {this.message})
    : assert(length >= 0, 'length must be non-negative');

  /// Minimum permitted length, inclusive.
  final int length;

  /// Override message reported when validation fails.
  final String? message;

  @override
  String get name => 'minLength';

  @override
  ValidationResult validate(Object? value) {
    if (value == null) return const ValidationResult.valid();
    final actual = switch (value) {
      final String s => s.length,
      final Iterable<Object?> i => i.length,
      _ => null,
    };
    if (actual == null || actual < length) {
      return ValidationResult.invalid(
        message ?? 'Must be at least $length characters long.',
      );
    }
    return const ValidationResult.valid();
  }
}
