/// Base contract for validation rules.
library;

import 'dart:async';

import 'validation_result.dart';

/// Contract every validation rule implements.
///
/// Rules are stateless value objects. Each rule exposes a stable
/// [name] used by the `Validator` for diagnostics and reports a
/// [ValidationResult] for a given value.
///
/// Rules may be synchronous or asynchronous: built-in rules return
/// `ValidationResult` directly, while rules such as `Unique` return a
/// `Future<ValidationResult>` because they query the database.
abstract class ValidationRule {
  /// Creates a [ValidationRule].
  const ValidationRule();

  /// Stable rule identifier reported back to callers.
  String get name;

  /// Evaluate [value] and report the outcome.
  FutureOr<ValidationResult> validate(Object? value);
}
