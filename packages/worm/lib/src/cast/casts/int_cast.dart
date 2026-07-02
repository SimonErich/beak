/// Cast for [int] columns.
library;

import '../attribute_cast.dart';

/// Casts to and from [int]. Accepts native ints, numeric strings,
/// and floored doubles whose value already fits an integer.
final class IntCast extends AttributeCast {
  /// Creates an [IntCast].
  const IntCast({this.field = 'value'});

  /// Field name reported in `CastException`s when conversion fails.
  final String field;

  @override
  String get name => 'int';

  @override
  int? decode(Object? raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is double && raw == raw.truncateToDouble()) {
      return raw.toInt();
    }
    if (raw is String) {
      final parsed = int.tryParse(raw);
      if (parsed != null) return parsed;
    }
    throw castError(
      field: field,
      source: raw,
      reason: 'Cannot decode value as int.',
      targetType: 'int',
    );
  }

  @override
  Object? encode(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    throw castError(
      field: field,
      source: value,
      reason: 'Cannot encode value as int.',
      targetType: 'int',
    );
  }
}
