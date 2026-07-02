/// Cast for [bool] columns.
library;

import '../attribute_cast.dart';

/// Casts between [bool] and the common SQL representations
/// (`bool`, `int 0/1`, `'true'`/`'false'`).
final class BoolCast extends AttributeCast {
  /// Creates a [BoolCast].
  const BoolCast({this.field = 'value'});

  /// Field name reported in `CastException`s when conversion fails.
  final String field;

  @override
  String get name => 'bool';

  @override
  bool? decode(Object? raw) {
    if (raw == null) return null;
    if (raw is bool) return raw;
    if (raw is int) return raw != 0;
    if (raw is String) {
      final lower = raw.toLowerCase();
      if (lower == 'true' || lower == 't' || lower == '1') return true;
      if (lower == 'false' || lower == 'f' || lower == '0') return false;
    }
    throw castError(
      field: field,
      source: raw,
      reason: 'Cannot decode value as bool.',
      targetType: 'bool',
    );
  }

  @override
  Object? encode(Object? value) {
    if (value == null) return null;
    if (value is bool) return value;
    throw castError(
      field: field,
      source: value,
      reason: 'Cannot encode value as bool.',
      targetType: 'bool',
    );
  }
}
