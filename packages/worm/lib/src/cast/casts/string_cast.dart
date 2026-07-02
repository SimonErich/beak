/// Cast for [String] columns.
library;

import '../attribute_cast.dart';

/// Casts to and from [String]. Non-null inputs are coerced via
/// `toString()` when possible.
final class StringCast extends AttributeCast {
  /// Creates a [StringCast].
  const StringCast({this.field = 'value'});

  /// Field name reported in `CastException`s when conversion fails.
  final String field;

  @override
  String get name => 'string';

  @override
  String? decode(Object? raw) {
    if (raw == null) return null;
    if (raw is String) return raw;
    if (raw is num || raw is bool || raw is BigInt || raw is Uri) {
      return raw.toString();
    }
    throw castError(
      field: field,
      source: raw,
      reason: 'Cannot decode value as String.',
      targetType: 'String',
    );
  }

  @override
  Object? encode(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    throw castError(
      field: field,
      source: value,
      reason: 'Cannot encode value as String.',
      targetType: 'String',
    );
  }
}
