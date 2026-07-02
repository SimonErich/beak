/// Cast for [Enum] columns.
library;

import '../attribute_cast.dart';

/// Casts between [Enum] values and their `name` string.
///
/// `EnumCast<MyEnum>(MyEnum.values)` round-trips an enum through a
/// `TEXT` column without losing the case in which the value was
/// declared.
final class EnumCast<T extends Enum> extends AttributeCast {
  /// Creates an [EnumCast] for [values].
  const EnumCast(this.values, {this.field = 'value'});

  /// Allowed enum values, typically `MyEnum.values`.
  final List<T> values;

  /// Field name reported in `CastException`s when conversion fails.
  final String field;

  @override
  String get name => 'enum';

  @override
  T? decode(Object? raw) {
    if (raw == null) return null;
    if (raw is T) return raw;
    if (raw is String) {
      for (final v in values) {
        if (v.name == raw) return v;
      }
    }
    if (raw is int && raw >= 0 && raw < values.length) {
      return values[raw];
    }
    throw castError(
      field: field,
      source: raw,
      reason: 'Cannot decode value as enum.',
      targetType: 'Enum',
    );
  }

  @override
  Object? encode(Object? value) {
    if (value == null) return null;
    if (value is T) return value.name;
    throw castError(
      field: field,
      source: value,
      reason: 'Cannot encode value as enum.',
      targetType: 'Enum',
    );
  }
}
