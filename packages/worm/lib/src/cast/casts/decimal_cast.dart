/// Cast for [Decimal] columns.
library;

import '../attribute_cast.dart';
import '../decimal.dart';

/// Casts between [Decimal] and the canonical string form stored in
/// the database / JSON payloads.
final class DecimalCast extends AttributeCast {
  /// Creates a [DecimalCast].
  const DecimalCast({this.field = 'value'});

  /// Field name reported in `CastException`s when conversion fails.
  final String field;

  @override
  String get name => 'decimal';

  @override
  Decimal? decode(Object? raw) {
    if (raw == null) return null;
    if (raw is Decimal) return raw;
    if (raw is String) {
      final parsed = Decimal.tryParse(raw);
      if (parsed != null) return parsed;
    }
    if (raw is int) return Decimal.fromInt(raw);
    throw castError(
      field: field,
      source: raw,
      reason: 'Cannot decode value as Decimal.',
      targetType: 'Decimal',
    );
  }

  @override
  Object? encode(Object? value) {
    if (value == null) return null;
    if (value is Decimal) return value.value;
    if (value is String) {
      final parsed = Decimal.tryParse(value);
      if (parsed != null) return parsed.value;
    }
    if (value is int) return Decimal.fromInt(value).value;
    throw castError(
      field: field,
      source: value,
      reason: 'Cannot encode value as Decimal.',
      targetType: 'Decimal',
    );
  }
}
