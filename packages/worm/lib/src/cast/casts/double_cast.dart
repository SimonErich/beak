/// Cast for [double] columns.
library;

import '../attribute_cast.dart';

/// Casts to and from [double]. Accepts native numbers and parseable
/// numeric strings.
final class DoubleCast extends AttributeCast {
  /// Creates a [DoubleCast].
  const DoubleCast({this.field = 'value'});

  /// Field name reported in `CastException`s when conversion fails.
  final String field;

  @override
  String get name => 'double';

  @override
  double? decode(Object? raw) {
    if (raw == null) return null;
    if (raw is double) return raw;
    if (raw is int) return raw.toDouble();
    if (raw is String) {
      final parsed = double.tryParse(raw);
      if (parsed != null) return parsed;
    }
    throw castError(
      field: field,
      source: raw,
      reason: 'Cannot decode value as double.',
      targetType: 'double',
    );
  }

  @override
  Object? encode(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    throw castError(
      field: field,
      source: value,
      reason: 'Cannot encode value as double.',
      targetType: 'double',
    );
  }
}
