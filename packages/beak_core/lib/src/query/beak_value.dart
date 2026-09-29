import 'package:meta/meta.dart';

import '../common/beak_exception.dart';
import '../common/list_equality.dart';

/// A typed wrapper around a filter comparison operand, so query specs
/// serialize losslessly without ever exposing `dynamic`.
///
/// Wire encoding: [BeakNullValue], [BeakBoolValue], [BeakIntValue],
/// [BeakDoubleValue], and [BeakStringValue] serialize as the raw JSON
/// primitive; [BeakListValue] as a JSON array; [BeakDateTimeValue] as a
/// tagged object `{"type": "dateTime", "value": <ISO-8601>}` so decoding
/// never confuses timestamps with plain strings.
@immutable
sealed class BeakValue {
  const BeakValue();

  /// Wraps [raw] in the matching variant.
  ///
  /// Supports `null`, [bool], [int], [double], [String], [DateTime], and
  /// [List] (recursively); an existing [BeakValue] passes through unchanged.
  /// Throws a [BeakConfigurationException] for any other type.
  ///
  /// This is the ergonomic way to build filter operands from plain Dart
  /// without naming a variant by hand:
  ///
  /// ```dart
  /// BeakValue.of('active');          // BeakStringValue
  /// BeakValue.of(42);                // BeakIntValue
  /// BeakValue.of([1, 2, 3]);         // BeakListValue of BeakIntValues
  /// BeakValue.of(DateTime.utc(2026)); // BeakDateTimeValue
  /// ```
  // --8<-- [start:of]
  static BeakValue of(Object? raw) => switch (raw) {
    null => const BeakNullValue(),
    final BeakValue value => value,
    final bool value => BeakBoolValue(value),
    final int value => BeakIntValue(value),
    final double value => BeakDoubleValue(value),
    final String value => BeakStringValue(value),
    final DateTime value => BeakDateTimeValue(value),
    final List<Object?> values => BeakListValue([
      for (final value in values) BeakValue.of(value),
    ]),
    _ => throw BeakConfigurationException(
      'BeakValue does not support ${raw.runtimeType} values (got $raw).',
    ),
  };
  // --8<-- [end:of]

  /// Decodes [json] (produced by [toJson]) back into a typed value.
  ///
  /// Throws a [BeakConfigurationException] on malformed input.
  // --8<-- [start:fromJson]
  static BeakValue fromJson(Object? json) => switch (json) {
    null => const BeakNullValue(),
    final bool value => BeakBoolValue(value),
    final int value => BeakIntValue(value),
    final double value => BeakDoubleValue(value),
    final String value => BeakStringValue(value),
    final List<Object?> values => BeakListValue([
      for (final value in values) BeakValue.fromJson(value),
    ]),
    {'type': 'dateTime', 'value': final String iso} => BeakDateTimeValue(
      _parseInstant(iso),
    ),
    _ => throw BeakConfigurationException('Malformed BeakValue JSON: $json.'),
  };
  // --8<-- [end:fromJson]

  static DateTime _parseInstant(String iso) {
    final DateTime? parsed = DateTime.tryParse(iso);
    if (parsed == null) {
      throw BeakConfigurationException('"$iso" is not an ISO-8601 timestamp.');
    }
    return parsed;
  }

  /// This value as plain Dart (the inverse of [BeakValue.of]) — unlike
  /// [toJson], a [BeakDateTimeValue] unwraps to a [DateTime], not a tagged
  /// object.
  Object? get raw;

  /// This value as a plain JSON-encodable structure.
  Object? toJson();
}

/// A string comparison operand.
final class BeakStringValue extends BeakValue {
  /// Creates a string operand holding [value].
  const BeakStringValue(this.value);

  /// The wrapped string.
  final String value;

  @override
  Object? get raw => value;

  @override
  Object? toJson() => value;

  @override
  bool operator ==(Object other) =>
      other is BeakStringValue && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'BeakStringValue($value)';
}

/// An integer comparison operand.
final class BeakIntValue extends BeakValue {
  /// Creates an integer operand holding [value].
  const BeakIntValue(this.value);

  /// The wrapped integer.
  final int value;

  @override
  Object? get raw => value;

  @override
  Object? toJson() => value;

  @override
  bool operator ==(Object other) =>
      other is BeakIntValue && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'BeakIntValue($value)';
}

/// A floating-point comparison operand.
final class BeakDoubleValue extends BeakValue {
  /// Creates a floating-point operand holding [value].
  const BeakDoubleValue(this.value);

  /// The wrapped double.
  final double value;

  @override
  Object? get raw => value;

  @override
  Object? toJson() => value;

  @override
  bool operator ==(Object other) =>
      other is BeakDoubleValue && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'BeakDoubleValue($value)';
}

/// A boolean comparison operand.
final class BeakBoolValue extends BeakValue {
  /// Creates a boolean operand holding [value].
  const BeakBoolValue(this.value);

  /// The wrapped boolean.
  final bool value;

  @override
  Object? get raw => value;

  @override
  Object? toJson() => value;

  @override
  bool operator ==(Object other) =>
      other is BeakBoolValue && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'BeakBoolValue($value)';
}

/// A timestamp comparison operand, encoded as a tagged ISO-8601 object.
final class BeakDateTimeValue extends BeakValue {
  /// Creates a timestamp operand holding [value].
  const BeakDateTimeValue(this.value);

  /// The wrapped timestamp.
  final DateTime value;

  @override
  Object? get raw => value;

  @override
  Object? toJson() => {'type': 'dateTime', 'value': value.toIso8601String()};

  @override
  bool operator ==(Object other) =>
      other is BeakDateTimeValue && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'BeakDateTimeValue($value)';
}

/// The absent comparison operand, used by operand-less operators.
final class BeakNullValue extends BeakValue {
  /// Creates the null operand.
  const BeakNullValue();

  @override
  Object? get raw => null;

  @override
  Object? toJson() => null;

  @override
  bool operator ==(Object other) => other is BeakNullValue;

  @override
  int get hashCode => null.hashCode;

  @override
  String toString() => 'BeakNullValue()';
}

/// A list comparison operand (for `inList`, `between`, and friends).
final class BeakListValue extends BeakValue {
  /// Creates a list operand over [values].
  const BeakListValue(this.values);

  /// The wrapped elements, in order.
  final List<BeakValue> values;

  @override
  List<Object?> get raw => [for (final value in values) value.raw];

  @override
  Object? toJson() => [for (final value in values) value.toJson()];

  @override
  bool operator ==(Object other) =>
      other is BeakListValue && listEquals(other.values, values);

  @override
  int get hashCode => Object.hashAll(values);

  @override
  String toString() => 'BeakListValue($values)';
}
