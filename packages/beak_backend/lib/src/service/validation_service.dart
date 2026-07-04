import 'package:beak_core/beak_core.dart';

/// Runs a model's declarative column rules over an incoming record — the
/// single validation boundary of the backend, invoked by the resource
/// service (never by handlers).
///
/// Semantics: unknown keys are rejected; a mistyped value fails its type
/// check and skips the column's rules; [BeakRequired] columns must be
/// present on create, while updates validate only the provided fields
/// (partial semantics — an explicit `null` still runs the rules).
///
/// ```dart
/// const validation = ValidationService();
/// try {
///   validation.validate(model, record, isCreate: true);
/// } on BeakValidationException catch (error) {
///   // error.fieldErrors maps each offending column key to its messages.
/// }
/// ```
final class ValidationService {
  /// Creates the stateless validation boundary.
  const ValidationService();

  /// Validates [input] against [model]'s columns.
  ///
  /// Set [isCreate] to enforce [BeakRequired] presence (create) or to
  /// validate only the provided fields (update). Throws a
  /// [BeakValidationException] whose `fieldErrors` aggregates every
  /// violation under its column key; returns normally when [input] is valid.
  void validate(BeakModel model, BeakRecord input, {required bool isCreate}) {
    final fieldErrors = <String, List<String>>{};
    void report(String columnKey, String message) {
      fieldErrors.putIfAbsent(columnKey, () => []).add(message);
    }

    for (final key in input.values.keys) {
      if (model.columnByKey(key) == null) {
        report(key, 'Unknown field "$key" on "${model.table}".');
      }
    }

    for (final column in model.columns) {
      final BeakValue? provided = input[column.key];
      if (provided == null && !(isCreate && _isRequired(column))) {
        continue;
      }
      if (provided != null) {
        final String? typeError = _typeError(column, provided);
        if (typeError != null) {
          report(column.key, typeError);
          continue;
        }
      }
      final Object? raw = provided?.raw;
      for (final rule in column.rules) {
        final String? message = rule.validate(raw);
        if (message != null) {
          report(column.key, message);
        }
      }
    }

    if (fieldErrors.isNotEmpty) {
      throw BeakValidationException(
        'Validation failed for "${model.table}".',
        fieldErrors: fieldErrors,
      );
    }
  }

  bool _isRequired(BeakColumn column) =>
      column.rules.whereType<BeakRequired>().isNotEmpty;

  String? _typeError(BeakColumn column, BeakValue value) {
    if (value is BeakNullValue) {
      return null; // Presence is BeakRequired's job alone.
    }
    return switch (column) {
      BeakIntColumn() => value is BeakIntValue ? null : 'Must be an integer.',
      BeakDecimalColumn() =>
        value is BeakIntValue || value is BeakDoubleValue
            ? null
            : 'Must be a number.',
      BeakBoolColumn() => value is BeakBoolValue ? null : 'Must be a boolean.',
      BeakDateTimeColumn() =>
        value is BeakDateTimeValue ? null : 'Must be a timestamp.',
      BeakStringColumn() ||
      BeakTextColumn() ||
      BeakRichTextColumn() ||
      BeakColorColumn() ||
      BeakFileColumn() ||
      BeakImageColumn() =>
        value is BeakStringValue ? null : 'Must be a string.',
      final BeakEnumColumn<Enum> enumColumn => _enumError(enumColumn, value),
      BeakJsonColumn() || BeakCustomColumn() => null,
    };
  }

  String? _enumError(BeakEnumColumn<Enum> column, BeakValue value) {
    final names = [for (final option in column.values) option.name];
    return switch (value) {
      BeakStringValue(:final value) when names.contains(value) => null,
      _ => 'Must be one of: ${names.join(', ')}.',
    };
  }
}
