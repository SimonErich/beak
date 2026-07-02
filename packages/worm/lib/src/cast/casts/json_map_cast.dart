/// Cast for JSON map columns.
library;

import 'dart:convert';

import '../attribute_cast.dart';

/// Casts between `Map<String, Object?>` and a JSON-encoded string.
final class JsonMapCast extends AttributeCast {
  /// Creates a [JsonMapCast].
  const JsonMapCast({this.field = 'value'});

  /// Field name reported in `CastException`s when conversion fails.
  final String field;

  @override
  String get name => 'json-map';

  @override
  Map<String, Object?>? decode(Object? raw) {
    if (raw == null) return null;
    if (raw is Map<String, Object?>) return Map<String, Object?>.from(raw);
    if (raw is Map<Object?, Object?>) return _coerce(raw);
    if (raw is String) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<Object?, Object?>) return _coerce(decoded);
    }
    throw castError(
      field: field,
      source: raw,
      reason: 'Cannot decode value as JSON map.',
      targetType: 'Map<String, Object?>',
    );
  }

  @override
  Object? encode(Object? value) {
    if (value == null) return null;
    if (value is Map<String, Object?>) return jsonEncode(value);
    if (value is String) {
      jsonDecode(value);
      return value;
    }
    throw castError(
      field: field,
      source: value,
      reason: 'Cannot encode value as JSON map.',
      targetType: 'Map<String, Object?>',
    );
  }

  Map<String, Object?> _coerce(Map<Object?, Object?> raw) {
    final out = <String, Object?>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      if (key is! String) {
        throw castError(
          field: field,
          source: key,
          reason: 'JSON map key must be a string.',
          targetType: 'Map<String, Object?>',
        );
      }
      out[key] = entry.value;
    }
    return out;
  }
}
