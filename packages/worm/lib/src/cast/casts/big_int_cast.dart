/// Cast for [BigInt] columns.
library;

import '../attribute_cast.dart';

/// Casts between [BigInt] values and their canonical decimal string.
final class BigIntCast extends AttributeCast {
  /// Creates a [BigIntCast].
  const BigIntCast({this.field = 'value'});

  /// Field name reported in `CastException`s when conversion fails.
  final String field;

  @override
  String get name => 'bigint';

  @override
  BigInt? decode(Object? raw) {
    if (raw == null) return null;
    if (raw is BigInt) return raw;
    if (raw is int) return BigInt.from(raw);
    if (raw is String) {
      final parsed = BigInt.tryParse(raw);
      if (parsed != null) return parsed;
    }
    throw castError(
      field: field,
      source: raw,
      reason: 'Cannot decode value as BigInt.',
      targetType: 'BigInt',
    );
  }

  @override
  Object? encode(Object? value) {
    if (value == null) return null;
    if (value is BigInt) return value.toString();
    if (value is int) return BigInt.from(value).toString();
    if (value is String && BigInt.tryParse(value) != null) return value;
    throw castError(
      field: field,
      source: value,
      reason: 'Cannot encode value as BigInt.',
      targetType: 'BigInt',
    );
  }
}
