/// Engine that runs validation rules against attribute maps.
library;

import 'dart:async';

import '../exception/validation_exception.dart';
import 'validatable.dart';
import 'validation_result.dart';
import 'validation_rule.dart';

/// Runs [ValidationRule]s against an attribute map.
///
/// Rules are declared as a `Map<String, List<ValidationRule>>` keyed
/// by field name. All rules for every field are executed even when
/// earlier rules fail, so the caller receives a complete picture of
/// every invalid field.
///
/// Use [validate] to collect a `Map<String, List<String>>` of errors,
/// or [validateOrThrow] to surface them as a [ValidationException].
final class Validator {
  /// Creates a [Validator] for the given [rules].
  const Validator(this.rules);

  /// Per-field rules. The same field can declare multiple rules; all
  /// are evaluated in order.
  final Map<String, List<ValidationRule>> rules;

  /// Run every rule for every declared field.
  ///
  /// Returns an empty map when every value satisfies its rules.
  Future<Map<String, List<String>>> validate(
    Map<String, Object?> values,
  ) async {
    final errors = <String, List<String>>{};
    for (final entry in rules.entries) {
      final field = entry.key;
      final value = values[field];
      final messages = <String>[];
      for (final rule in entry.value) {
        final outcome = await rule.validate(value);
        final reason = outcome.message;
        if (reason != null) messages.add(reason);
      }
      if (messages.isNotEmpty) errors[field] = messages;
    }
    return errors;
  }

  /// Validate and throw [ValidationException.fromMap] on failure.
  Future<void> validateOrThrow(Map<String, Object?> values) async {
    final errors = await validate(values);
    if (errors.isNotEmpty) throw ValidationException.fromMap(errors);
  }

  /// Synchronous variant for callers that know every configured rule
  /// is synchronous. Throws [StateError] if a rule returns a
  /// `Future` so the caller can fall back to [validate].
  Map<String, List<String>> validateSync(Map<String, Object?> values) {
    final errors = <String, List<String>>{};
    for (final entry in rules.entries) {
      final field = entry.key;
      final value = values[field];
      final messages = <String>[];
      for (final rule in entry.value) {
        final outcome = rule.validate(value);
        if (outcome is Future<ValidationResult>) {
          throw StateError(
            'Rule "${rule.name}" is async; use validate() instead.',
          );
        }
        final reason = outcome.message;
        if (reason != null) messages.add(reason);
      }
      if (messages.isNotEmpty) errors[field] = messages;
    }
    return errors;
  }
}

/// Validate a [Validatable] by composing its rules and values.
///
/// Builds a [Validator] from `validatable.validationRules()` and
/// delegates to [Validator.validateOrThrow] with
/// `validatable.validationValues()`. Throws [ValidationException]
/// when any rule fails.
Future<void> validateModel(Validatable validatable) {
  final validator = Validator(validatable.validationRules());
  return validator.validateOrThrow(validatable.validationValues());
}
