/// Cast for [Uri] columns.
library;

import '../attribute_cast.dart';

/// Casts between [Uri] values and their string form.
final class UriCast extends AttributeCast {
  /// Creates a [UriCast].
  const UriCast({this.field = 'value'});

  /// Field name reported in `CastException`s when conversion fails.
  final String field;

  @override
  String get name => 'uri';

  @override
  Uri? decode(Object? raw) {
    if (raw == null) return null;
    if (raw is Uri) return raw;
    if (raw is String) {
      final parsed = Uri.tryParse(raw);
      if (parsed != null) return parsed;
    }
    throw castError(
      field: field,
      source: raw,
      reason: 'Cannot decode value as Uri.',
      targetType: 'Uri',
    );
  }

  @override
  Object? encode(Object? value) {
    if (value == null) return null;
    if (value is Uri) return value.toString();
    if (value is String && Uri.tryParse(value) != null) return value;
    throw castError(
      field: field,
      source: value,
      reason: 'Cannot encode value as Uri.',
      targetType: 'Uri',
    );
  }
}
