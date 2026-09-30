import 'package:beak_core/beak_core.dart';
import 'package:uuid/uuid_value.dart';
import 'package:uuid/validation.dart';

/// Generated conversion between an existing typed object and Beak records.
abstract class ServerpodCodec<T> {
  /// Enables constant generated codecs.
  const ServerpodCodec();

  /// Converts an existing object without JSON or a second entity model.
  BeakRecord encode(T value);

  /// Constructs typed command data, rejecting incompatible input values.
  T decode(BeakRecord record);
}

/// Lossless, typed conversion of one scalar or scalar-list value.
abstract class ServerpodValueCodec<T> {
  /// Enables constant scalar codecs.
  const ServerpodValueCodec();

  /// Encodes a value in Beak's wire vocabulary.
  BeakValue encode(T value);

  /// Reads a value or throws a typed validation failure.
  T decode(BeakValue? value);

  /// A codec that preserves explicit null values.
  ServerpodValueCodec<T?> get nullable => _NullableCodec(this);

  /// A codec for lists, retaining the element's nullability.
  ServerpodValueCodec<List<T>> get list => _ListCodec(this);

  /// A codec for typed sets represented as Beak lists.
  ServerpodValueCodec<Set<T>> get set => _SetCodec(this);
}

/// Built-in codecs used by generated companions and typed route identities.
abstract final class ServerpodCodecs {
  /// Text values; numbers are never implicitly stringified.
  static const ServerpodValueCodec<String> string = _StringCodec();

  /// Whole numbers; fractional doubles are never truncated.
  static const ServerpodValueCodec<int> integer = _IntCodec();

  /// Decimal values.
  static const ServerpodValueCodec<double> decimal = _DoubleCodec();

  /// Booleans, including false independently of null.
  static const ServerpodValueCodec<bool> boolean = _BoolCodec();

  /// Instants, preserving DateTime's own UTC/local semantics.
  static const ServerpodValueCodec<DateTime> dateTime = _DateTimeCodec();

  /// UUID values, validated at the string boundary.
  static const ServerpodValueCodec<UuidValue> uuid = _UuidCodec();

  /// URI values used by generated Serverpod profile models.
  static const ServerpodValueCodec<Uri> uri = _UriCodec();

  /// Existing enum values encoded by name, without redeclaring variants.
  static ServerpodValueCodec<E> enumeration<E extends Enum>(List<E> values) =>
      _EnumCodec(values);
}

Never _invalid(String type) =>
    throw BeakValidationException('Expected a valid $type value.');

final class _StringCodec extends ServerpodValueCodec<String> {
  const _StringCodec();
  @override
  BeakValue encode(String value) => BeakStringValue(value);
  @override
  String decode(BeakValue? value) => switch (value) {
    BeakStringValue(:final value) => value,
    _ => _invalid('string'),
  };
}

final class _IntCodec extends ServerpodValueCodec<int> {
  const _IntCodec();
  @override
  BeakValue encode(int value) => BeakIntValue(value);
  @override
  int decode(BeakValue? value) => switch (value) {
    BeakIntValue(:final value) => value,
    _ => _invalid('integer'),
  };
}

final class _DoubleCodec extends ServerpodValueCodec<double> {
  const _DoubleCodec();
  @override
  BeakValue encode(double value) => BeakDoubleValue(value);
  @override
  double decode(BeakValue? value) => switch (value) {
    BeakDoubleValue(:final value) => value,
    BeakIntValue(:final value) => value.toDouble(),
    _ => _invalid('decimal'),
  };
}

final class _BoolCodec extends ServerpodValueCodec<bool> {
  const _BoolCodec();
  @override
  BeakValue encode(bool value) => BeakBoolValue(value);
  @override
  bool decode(BeakValue? value) => switch (value) {
    BeakBoolValue(:final value) => value,
    _ => _invalid('boolean'),
  };
}

final class _DateTimeCodec extends ServerpodValueCodec<DateTime> {
  const _DateTimeCodec();
  @override
  BeakValue encode(DateTime value) => BeakDateTimeValue(value);
  @override
  DateTime decode(BeakValue? value) => switch (value) {
    BeakDateTimeValue(:final value) => value,
    _ => _invalid('date/time'),
  };
}

final class _UuidCodec extends ServerpodValueCodec<UuidValue> {
  const _UuidCodec();
  @override
  BeakValue encode(UuidValue value) => BeakStringValue(value.uuid);
  @override
  UuidValue decode(BeakValue? value) => switch (value) {
    BeakStringValue(:final value)
        when UuidValidation.isValidUUID(fromString: value) =>
      UuidValue.fromString(value),
    _ => _invalid('UUID'),
  };
}

final class _EnumCodec<E extends Enum> extends ServerpodValueCodec<E> {
  const _EnumCodec(this.values);
  final List<E> values;
  @override
  BeakValue encode(E value) => BeakStringValue(value.name);
  @override
  E decode(BeakValue? value) {
    if (value case BeakStringValue(:final value)) {
      for (final option in values) {
        if (option.name == value) return option;
      }
    }
    return _invalid('enum');
  }
}

final class _NullableCodec<T> extends ServerpodValueCodec<T?> {
  const _NullableCodec(this.inner);
  final ServerpodValueCodec<T> inner;
  @override
  BeakValue encode(T? value) =>
      value == null ? const BeakNullValue() : inner.encode(value);
  @override
  T? decode(BeakValue? value) => switch (value) {
    null || BeakNullValue() => null,
    _ => inner.decode(value),
  };
}

final class _ListCodec<T> extends ServerpodValueCodec<List<T>> {
  const _ListCodec(this.inner);
  final ServerpodValueCodec<T> inner;
  @override
  BeakValue encode(List<T> values) =>
      BeakListValue([for (final value in values) inner.encode(value)]);
  @override
  List<T> decode(BeakValue? value) => switch (value) {
    BeakListValue(:final values) => [
      for (final item in values) inner.decode(item),
    ],
    _ => _invalid('list'),
  };
}

final class _SetCodec<T> extends ServerpodValueCodec<Set<T>> {
  const _SetCodec(this.inner);
  final ServerpodValueCodec<T> inner;
  @override
  BeakValue encode(Set<T> values) =>
      BeakListValue([for (final value in values) inner.encode(value)]);
  @override
  Set<T> decode(BeakValue? value) => switch (value) {
    BeakListValue(:final values) => {
      for (final item in values) inner.decode(item),
    },
    _ => _invalid('set'),
  };
}

final class _UriCodec extends ServerpodValueCodec<Uri> {
  const _UriCodec();
  @override
  BeakValue encode(Uri value) => BeakStringValue(value.toString());
  @override
  Uri decode(BeakValue? value) {
    if (value case BeakStringValue(:final value)) {
      final parsed = Uri.tryParse(value);
      if (parsed != null) return parsed;
    }
    return _invalid('URI');
  }
}

/// Flattens generated nested values for ordinary Beak form controls.
Map<String, BeakValue> serverpodFlatten(String key, BeakRecord record) => {
  for (final entry in record.values.entries) '$key.${entry.key}': entry.value,
};

/// Reads nested input, overlaying edited flat fields on a loaded relation.
///
/// Generated code supplies [key]; application code uses typed descriptors.
BeakRecord? serverpodNestedInput(BeakRecord record, String key) {
  if (record[key] is BeakNullValue) return null;
  final related = record.relations[key];
  if (related != null && related.length > 1) {
    throw const BeakValidationException('Expected one nested record.');
  }
  final base = related != null && related.isNotEmpty ? related.single : null;
  final prefix = '$key.';
  final values = <String, BeakValue>{
    if (base != null) ...base.values,
    for (final entry in record.values.entries)
      if (entry.key.startsWith(prefix))
        entry.key.substring(prefix.length): entry.value,
  };
  final relations = <String, List<BeakRecord>>{
    if (base != null) ...base.relations,
    for (final entry in record.relations.entries)
      if (entry.key.startsWith(prefix))
        entry.key.substring(prefix.length): entry.value,
  };
  if (base == null && values.isEmpty && relations.isEmpty) return null;
  return BeakRecord(values: values, relations: relations);
}

/// Required nested inputs fail rather than creating an empty command silently.
BeakRecord requireServerpodNestedInput(BeakRecord record, String key) =>
    serverpodNestedInput(record, key) ??
    (throw BeakValidationException(
      'A required nested input is missing.',
      fieldErrors: {
        key: ['This value must be supplied.'],
      },
    ));

/// Required nested lists, including a legitimately empty list.
List<BeakRecord> requireServerpodRelatedInputs(BeakRecord record, String key) =>
    record.relations[key] ??
    (throw BeakValidationException(
      'A required list input is missing.',
      fieldErrors: {
        key: ['This value must be supplied.'],
      },
    ));
