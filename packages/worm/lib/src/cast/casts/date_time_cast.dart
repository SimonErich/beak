/// Cast for [DateTime] columns.
library;

import '../attribute_cast.dart';

/// Casts between [DateTime] and ISO-8601 strings or epoch
/// millisecond integers.
final class DateTimeCast extends AttributeCast {
  /// Creates a [DateTimeCast].
  const DateTimeCast({this.field = 'value'});

  /// Field name reported in `CastException`s when conversion fails.
  final String field;

  @override
  String get name => 'datetime';

  @override
  DateTime? decode(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
    }
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed.toUtc();
    }
    throw castError(
      field: field,
      source: raw,
      reason: 'Cannot decode value as DateTime.',
      targetType: 'DateTime',
    );
  }

  @override
  Object? encode(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc().toIso8601String();
    throw castError(
      field: field,
      source: value,
      reason: 'Cannot encode value as DateTime.',
      targetType: 'DateTime',
    );
  }
}
