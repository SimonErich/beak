import 'dart:convert';
import 'dart:math' as math;

import '../columns/beak_column.dart';
import '../columns/beak_semantic.dart';
import '../columns/beak_semantic_values.dart';
import '../columns/beak_json.dart';
import '../model/beak_model.dart';
import '../query/beak_record.dart';
import '../query/beak_value.dart';
import '../rules/beak_rule.dart';
import 'beak_record_rule.dart';

/// Shared, deterministic validation of model metadata on client and server.
final class BeakValidation {
  /// Creates a stateless validator.
  const BeakValidation();

  /// Applies declared defaults to omitted values, preserving explicit nulls.
  /// Nested object replacements receive their child defaults as well.
  BeakRecord applyDefaults(
    BeakModel model,
    BeakRecord input, {
    bool includeMissing = true,
  }) {
    final values = {...input.values};
    for (final column in model.columns) {
      if (!values.containsKey(column.key) &&
          includeMissing &&
          column.defaultValue != null) {
        values[column.key] = beakValueForColumn(column, column.defaultValue);
      }
      if (values.containsKey(column.key)) {
        values[column.key] = _objectDefaults(column, values[column.key]!);
      }
    }
    return BeakRecord(values: values, relations: input.relations);
  }

  BeakValue _objectDefaults(BeakColumn column, BeakValue value) {
    final schema = column.semantic.objectSchema;
    if (schema == null || value.raw == null) return value;
    try {
      final decoded = column.semantic.decode(value);
      if (decoded is! BeakJsonObject) return value;
      var object = decoded;
      for (final child in schema.columns) {
        if (!object.entries.containsKey(child.key) &&
            child.defaultValue != null) {
          object = schema.write(child, object, child.defaultValue);
        }
        if (object.entries.containsKey(child.key) &&
            child.semantic.objectSchema != null) {
          final encoded = child.semantic.encode(
            object.entries[child.key]!.toEncodable(),
          );
          object = schema.write(child, object, _objectDefaults(child, encoded));
        }
      }
      return column.semantic.encode(object);
    } on FormatException {
      // Preserve malformed input for the structured validation boundary.
      return value;
    } on ArgumentError {
      return value;
    }
  }

  /// Validates submitted fields and shared rules on the complete merged record.
  /// Existing values and relations must be supplied for partial updates.
  Map<String, List<String>> validate(
    BeakModel model,
    BeakRecord input, {
    bool isCreate = true,
    BeakRecord? initial,
    bool includeRecordRules = true,
  }) {
    if (isCreate) input = applyDefaults(model, input);
    final errors = <String, List<String>>{};
    void add(String key, Iterable<String> messages) {
      if (messages.isEmpty) return;
      errors[key] = {...?errors[key], ...messages}.toList(growable: false);
    }

    for (final key in input.values.keys) {
      if (model.columnByKey(key) == null) {
        add(key, ['Unknown field "$key" on "${model.table}".']);
      }
    }
    for (final column in model.columns) {
      if (input.values.containsKey(column.key) ||
          (isCreate && column.rules.any((rule) => rule is BeakRequired))) {
        add(column.key, columnErrors(column, input[column.key]?.raw));
      }
    }
    final candidate = BeakRecord(
      values: {...?initial?.values, ...input.values},
      relations: {...?initial?.relations, ...input.relations},
    );
    for (final rule
        in includeRecordRules
            ? model.validationRules
            : const <BeakRecordRule>[]) {
      for (final entry in rule.validate(candidate).entries) {
        add(entry.key, entry.value);
      }
    }
    return errors;
  }

  /// Validates a raw value against its declared type, constraints and rules.
  /// Null values run presence rules only; omitted update fields are handled by
  /// the record-level validator rather than changing scalar semantics.
  List<String> columnErrors(BeakColumn column, Object? value) {
    final errors = <String>{};
    Object? decoded = value;
    if (column.semantic.hasCodec && value != null) {
      try {
        final encoded = column.semantic.encode(value);
        decoded = column.semantic.decode(encoded);
        value = encoded.raw;
      } on FormatException catch (error) {
        return [error.message];
      } on ArgumentError {
        return ['Invalid ${column.semantic.kind.name} value.'];
      }
    }
    if (value != null) {
      final typeError = _typeError(column, value);
      if (typeError != null) return [typeError];
      switch (column) {
        case BeakIntColumn(:final min, :final max):
          if (value case final int number) {
            if (min != null) {
              if (BeakMin(min).validate(
                    decoded is num || decoded is BeakDecimal ? decoded : number,
                  )
                  case final String message) {
                errors.add(message);
              }
            }
            if (max != null) {
              if (BeakMax(max).validate(
                    decoded is num || decoded is BeakDecimal ? decoded : number,
                  )
                  case final String message) {
                errors.add(message);
              }
            }
          }
        case BeakStringColumn(:final maxLength):
          if (value case final String text
              when maxLength != null && text.length > maxLength) {
            errors.add('Must be at most $maxLength characters.');
          }
        case BeakDecimalColumn(:final precision, :final totalDigits):
          if (value case final num number) {
            if (!number.isFinite) {
              errors.add('Must be a finite number.');
            } else {
              final scale = math.pow(10, precision);
              final scaled = number * scale;
              if (!scaled.isFinite ||
                  (scaled - scaled.round()).abs() > 0.000001) {
                errors.add('Use at most $precision decimal places.');
              }
              final integerDigits = totalDigits - precision;
              if (number.abs() >= math.pow(10, integerDigits)) {
                errors.add('Must have at most $integerDigits integer digits.');
              }
            }
          }
        case BeakJsonColumn():
          if (value case final String text) {
            try {
              jsonDecode(text);
            } on FormatException {
              errors.add('Must be valid JSON.');
            }
          }
        case BeakColorColumn():
          if (value case final String text
              when !RegExp(
                r'^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
              ).hasMatch(text)) {
            errors.add('Use a hexadecimal color such as #663399.');
          }
        default:
          break;
      }
    }
    errors.addAll(_semanticErrors(column.semantic, decoded));
    for (final rule in column.rules) {
      final message = rule.validate(decoded);
      if (message != null) errors.add(message);
    }
    return errors.toList(growable: false);
  }

  List<String> _semanticErrors(BeakSemantic semantic, Object? value) {
    if (value == null) return const [];
    final errors = <String>[];
    final formatError = switch (semantic.kind) {
      BeakSemanticKind.email => const BeakEmail().validate(value),
      BeakSemanticKind.url => const BeakUrl().validate(value),
      BeakSemanticKind.phone =>
        value is String &&
                RegExp(r'^\+?[0-9 ()-]{5,25}$').hasMatch(value) &&
                value.replaceAll(RegExp(r'[^0-9]'), '').length >= 5
            ? null
            : 'Must be a valid phone number.',
      BeakSemanticKind.slug =>
        value is String && RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(value)
            ? null
            : 'Use lowercase letters, numbers and single hyphens.',
      BeakSemanticKind.uuid =>
        value is String &&
                RegExp(
                  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
                ).hasMatch(value)
            ? null
            : 'Must be a UUID.',
      BeakSemanticKind.fileSize =>
        value is int && value >= 0
            ? null
            : 'Must be a nonnegative number of bytes.',
      _ => null,
    };
    if (formatError != null) errors.add(formatError);
    if (value is num && !value.isFinite) errors.add('Must be a finite number.');
    if (value is List<Object?> &&
        semantic.kind == BeakSemanticKind.primitiveList) {
      if (semantic.minItems case final int min when value.length < min) {
        errors.add('Must contain at least $min items.');
      }
      if (semantic.maxItems case final int max when value.length > max) {
        errors.add('Must contain at most $max items.');
      }
      if (semantic.distinctItems && value.toSet().length != value.length) {
        errors.add('Items must be distinct.');
      }
      for (var i = 0; i < value.length; i++) {
        for (final rule in semantic.itemRules) {
          if (rule.validate(value[i]) case final String message) {
            errors.add('Item ${i + 1}: $message');
          }
        }
      }
    }
    if (value is BeakJsonObject && semantic.objectSchema != null) {
      final schema = semantic.objectSchema!;
      if (!schema.allowUnknown) {
        for (final key in value.entries.keys) {
          if (!schema.columns.any((column) => column.key == key)) {
            errors.add('Unknown property "$key".');
          }
        }
      }
      for (final child in schema.columns) {
        final raw = value.entries.containsKey(child.key)
            ? value.entries[child.key]!.toEncodable()
            : child.defaultValue;
        for (final message in columnErrors(child, raw)) {
          errors.add('${child.label}: $message');
        }
      }
    }
    return errors;
  }

  String? _typeError(BeakColumn column, Object value) => switch (column) {
    BeakIntColumn() => value is int ? null : 'Must be an integer.',
    BeakDecimalColumn() => value is num ? null : 'Must be a number.',
    BeakBoolColumn() => value is bool ? null : 'Must be a boolean.',
    BeakDateTimeColumn() => value is DateTime ? null : 'Must be a timestamp.',
    final BeakEnumColumn<Enum> enumeration => _enumError(enumeration, value),
    BeakCustomColumn() => null,
    _ => value is String ? null : 'Must be a string.',
  };

  String? _enumError(BeakEnumColumn<Enum> column, Object value) {
    final names = [for (final option in column.values) option.name];
    final token = value is Enum ? value.name : value;
    return names.contains(token)
        ? null
        : 'Must be one of: ${names.join(', ')}.';
  }
}
