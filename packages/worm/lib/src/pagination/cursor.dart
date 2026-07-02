/// Opaque cursor for cursor-based pagination.
library;

import 'dart:convert';

/// Immutable cursor anchored at a `(field, value, id)`
/// triple from the previous page.
///
/// The `field` identifies the ordered column; `value`
/// is the value of that column on the last visible row;
/// `id` is the primary-key value of that row, used as a
/// stable tiebreaker when the ordered column is not
/// unique. The triple is serialized as URL-safe
/// base64-of-JSON so consumers can persist or transport
/// the cursor without inspecting its contents.
final class Cursor {
  /// Creates a [Cursor] from the triple
  /// `(field, value, id)`.
  const Cursor({required this.field, required this.value, required this.id});

  /// Ordered column the cursor advances against.
  final String field;

  /// Value of [field] on the last row of the previous
  /// page.
  final Object value;

  /// Primary-key value of the last row on the previous
  /// page. Used as a tiebreaker for stable ordering.
  final Object id;

  /// Encodes this cursor into a stable URL-safe token.
  String encode() {
    final payload = jsonEncode(<String, Object?>{
      'field': field,
      'value': value,
      'id': id,
    });
    return base64Url.encode(utf8.encode(payload));
  }

  /// Decodes a token produced by [encode].
  ///
  /// Returns `null` when [token] is `null`, empty, or
  /// fails to decode into a `(field, value, id)`
  /// triple. Pattern matching on the JSON map guarantees
  /// type-safe access without `as` casts or `dynamic`.
  static Cursor? decode(String? token) {
    if (token == null || token.isEmpty) return null;
    final Map<String, Object?> map;
    try {
      final raw = utf8.decode(base64Url.decode(token));
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      map = decoded;
    } on FormatException {
      return null;
    }
    final rawField = map['field'];
    final rawValue = map['value'];
    final rawId = map['id'];
    if (rawField is! String) return null;
    if (rawValue == null) return null;
    if (rawId == null) return null;
    return Cursor(field: rawField, value: rawValue, id: rawId);
  }
}
