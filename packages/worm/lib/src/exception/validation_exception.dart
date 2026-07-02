/// Exception for model validation failures.
library;

import 'model_exception.dart';
import 'unique_constraint_exception.dart';

/// Thrown when one or more model fields fail
/// validation.
///
/// Two construction paths exist:
///
/// * Single-field constructor — the original const
///   form used for one validation failure.
/// * [ValidationException.fromMap] — aggregate
///   multiple field errors into a single exception
///   suitable for JSON API responses.
///
/// [errors] always returns a
/// `Map<String, List<String>>` shaped like a typical
/// JSON validation error response.
final class ValidationException extends ModelException {
  /// Creates a [ValidationException] for a single
  /// failing field.
  const ValidationException({
    required this.field,
    required this.rule,
    required String message,
    this.value,
    this.model,
  }) : _errors = null,
       super(message);

  /// Creates a [ValidationException] aggregating
  /// multiple field errors keyed by field name.
  ValidationException.fromMap(Map<String, List<String>> errors, {this.model})
    : field = '',
      rule = '',
      value = null,
      _errors = _freeze(errors),
      super(_combine(errors));

  /// Creates a [ValidationException] from a
  /// database [UniqueConstraintException].
  ///
  /// The resulting [errors] map keys on the
  /// violated column and contains a human-readable
  /// message.
  factory ValidationException.fromUniqueConstraint(
    UniqueConstraintException violation, {
    String? message,
    String? model,
  }) {
    final column = violation.column;
    final text = message ?? 'The $column has already been taken.';
    return ValidationException.fromMap(<String, List<String>>{
      column: <String>[text],
    }, model: model);
  }

  /// The first field that failed validation, or an
  /// empty string when constructed with
  /// [ValidationException.fromMap].
  final String field;

  /// The validation rule that was violated, or an
  /// empty string when constructed with
  /// [ValidationException.fromMap].
  final String rule;

  /// The value that failed validation, when known.
  final Object? value;

  /// The model name carrying the failing field,
  /// when known.
  final String? model;

  final Map<String, List<String>>? _errors;

  /// All field errors as a JSON-API friendly map.
  ///
  /// Always returns an unmodifiable
  /// `Map<String, List<String>>` — including the
  /// inner lists — so the JSON-API error shape is
  /// safe to expose to callers.
  ///
  /// When constructed with the single-field
  /// constructor, this returns
  /// `{field: [message]}` so callers can use one
  /// API shape in both cases.
  Map<String, List<String>> get errors {
    final stored = _errors;
    if (stored != null) return stored;
    return Map<String, List<String>>.unmodifiable(<String, List<String>>{
      field: List<String>.unmodifiable(<String>[message]),
    });
  }

  @override
  Map<String, Object?> get context => <String, Object?>{
    'model': model,
    if (field.isNotEmpty) 'field': field,
    if (rule.isNotEmpty) 'rule': rule,
  };

  @override
  String toString() {
    final parts = <String>[];
    final modelName = model;
    if (modelName != null) parts.add('model: $modelName');
    if (field.isNotEmpty) parts.add('field: $field');
    if (rule.isNotEmpty) parts.add('rule: $rule');
    if (parts.isEmpty) return 'ValidationException: $message';
    return 'ValidationException: $message (${parts.join(', ')})';
  }

  static Map<String, List<String>> _freeze(Map<String, List<String>> errors) =>
      Map<String, List<String>>.unmodifiable(<String, List<String>>{
        for (final entry in errors.entries)
          entry.key: List<String>.unmodifiable(entry.value),
      });

  static String _combine(Map<String, List<String>> errors) {
    final lines = <String>[];
    for (final entry in errors.entries) {
      for (final message in entry.value) {
        lines.add('${entry.key}: $message');
      }
    }
    return lines.isEmpty ? 'Validation failed' : lines.join('; ');
  }
}
