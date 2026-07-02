/// Cast for JSON list columns.
library;

import 'dart:convert';

import '../attribute_cast.dart';

/// Casts between `List<Object?>` and a JSON-encoded string.
final class JsonListCast extends AttributeCast {
  /// Creates a [JsonListCast].
  const JsonListCast({this.field = 'value'});

  /// Field name reported in `CastException`s when conversion fails.
  final String field;

  @override
  String get name => 'json-list';

  @override
  List<Object?>? decode(Object? raw) {
    if (raw == null) return null;
    if (raw is List<Object?>) return List<Object?>.from(raw);
    if (raw is String) {
      final decoded = jsonDecode(raw);
      if (decoded is List<Object?>) return List<Object?>.from(decoded);
    }
    throw castError(
      field: field,
      source: raw,
      reason: 'Cannot decode value as JSON list.',
      targetType: 'List<Object?>',
    );
  }

  @override
  Object? encode(Object? value) {
    if (value == null) return null;
    if (value is List<Object?>) return jsonEncode(value);
    if (value is String) {
      jsonDecode(value);
      return value;
    }
    throw castError(
      field: field,
      source: value,
      reason: 'Cannot encode value as JSON list.',
      targetType: 'List<Object?>',
    );
  }
}
