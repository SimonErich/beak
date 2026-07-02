/// Cast for [Duration] columns stored as millisecond integers.
library;

import '../attribute_cast.dart';

/// Round-trips a [Duration] domain value as an integer number of
/// milliseconds in the database.
///
/// `null` passes through unchanged. Integer-typed and numeric-string
/// representations are accepted on decode so storage backends that
/// surface counts as strings (e.g. some Mongo BSON paths) still
/// round-trip cleanly.
final class DurationCast extends AttributeCast {
  /// Creates a [DurationCast].
  const DurationCast({this.field = 'duration'});

  /// Field name reported in `CastException`s when conversion fails.
  final String field;

  @override
  String get name => 'duration';

  @override
  Duration? decode(Object? raw) {
    if (raw == null) return null;
    if (raw is Duration) return raw;
    if (raw is int) return Duration(milliseconds: raw);
    if (raw is BigInt) return Duration(milliseconds: raw.toInt());
    if (raw is double && raw == raw.truncateToDouble()) {
      return Duration(milliseconds: raw.toInt());
    }
    if (raw is String) {
      final parsed = int.tryParse(raw);
      if (parsed != null) return Duration(milliseconds: parsed);
    }
    throw castError(
      field: field,
      source: raw,
      reason: 'Cannot decode value as Duration milliseconds.',
      targetType: 'Duration',
    );
  }

  @override
  Object? encode(Object? value) {
    if (value == null) return null;
    if (value is Duration) return value.inMilliseconds;
    if (value is int) return value;
    throw castError(
      field: field,
      source: value,
      reason: 'Cannot encode value as Duration milliseconds.',
      targetType: 'int',
    );
  }
}
