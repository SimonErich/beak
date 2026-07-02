import 'dart:convert';

import 'package:meta/meta.dart';

/// A typed, immutable JSON value tree.
///
/// Beak never exposes `Map<String, dynamic>`: JSON-valued columns carry this
/// sealed tree instead, so every consumer pattern-matches variants and the
/// type system rules out non-JSON payloads.
@immutable
sealed class BeakJson {
  const BeakJson();

  /// Parses [source] (a JSON document) into a typed tree.
  ///
  /// Throws a [FormatException] when [source] is not valid JSON.
  static BeakJson decode(String source) {
    final Object? raw = jsonDecode(source);
    return BeakJson.fromEncodable(raw);
  }

  /// Converts an already-decoded JSON structure (`null`, [bool], [num],
  /// [String], [List], or string-keyed [Map]) into a typed tree.
  ///
  /// Throws an [ArgumentError] for values outside the JSON data model.
  static BeakJson fromEncodable(Object? encodable) => switch (encodable) {
    null => const BeakJsonNull(),
    final bool value => BeakJsonBool(value),
    final num value => BeakJsonNumber(value),
    final String value => BeakJsonString(value),
    final List<Object?> items => BeakJsonArray([
      for (final item in items) BeakJson.fromEncodable(item),
    ]),
    final Map<Object?, Object?> entries => BeakJsonObject({
      for (final entry in entries.entries)
        _stringKey(entry.key): BeakJson.fromEncodable(entry.value),
    }),
    _ => throw ArgumentError.value(
      encodable,
      'encodable',
      'is not a JSON value',
    ),
  };

  static String _stringKey(Object? key) => switch (key) {
    final String value => value,
    _ => throw ArgumentError.value(
      key,
      'key',
      'JSON object keys must be strings',
    ),
  };

  /// This tree as the plain Dart structure `jsonEncode` understands.
  Object? toEncodable();

  /// Serializes this tree to a compact JSON document.
  String encode() => jsonEncode(toEncodable());
}

/// A JSON object: string keys mapping to nested [BeakJson] values.
final class BeakJsonObject extends BeakJson {
  /// Creates an object node over [entries].
  const BeakJsonObject(this.entries);

  /// The object's members, in declaration order.
  final Map<String, BeakJson> entries;

  @override
  Object? toEncodable() => {
    for (final entry in entries.entries) entry.key: entry.value.toEncodable(),
  };

  @override
  bool operator ==(Object other) {
    if (other is! BeakJsonObject || other.entries.length != entries.length) {
      return false;
    }
    for (final entry in entries.entries) {
      if (other.entries[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered([
    for (final entry in entries.entries) Object.hash(entry.key, entry.value),
  ]);

  @override
  String toString() => 'BeakJsonObject($entries)';
}

/// A JSON array of nested [BeakJson] values.
final class BeakJsonArray extends BeakJson {
  /// Creates an array node over [items].
  const BeakJsonArray(this.items);

  /// The array's elements, in order.
  final List<BeakJson> items;

  @override
  Object? toEncodable() => [for (final item in items) item.toEncodable()];

  @override
  bool operator ==(Object other) {
    if (other is! BeakJsonArray || other.items.length != items.length) {
      return false;
    }
    for (var i = 0; i < items.length; i += 1) {
      if (other.items[i] != items[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(items);

  @override
  String toString() => 'BeakJsonArray($items)';
}

/// A JSON string value.
final class BeakJsonString extends BeakJson {
  /// Creates a string node holding [value].
  const BeakJsonString(this.value);

  /// The wrapped string.
  final String value;

  @override
  Object? toEncodable() => value;

  @override
  bool operator ==(Object other) =>
      other is BeakJsonString && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'BeakJsonString($value)';
}

/// A JSON number value (integral or fractional).
final class BeakJsonNumber extends BeakJson {
  /// Creates a number node holding [value].
  const BeakJsonNumber(this.value);

  /// The wrapped number.
  final num value;

  @override
  Object? toEncodable() => value;

  @override
  bool operator ==(Object other) =>
      other is BeakJsonNumber && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'BeakJsonNumber($value)';
}

/// A JSON boolean value.
final class BeakJsonBool extends BeakJson {
  /// Creates a boolean node holding [value].
  const BeakJsonBool(this.value);

  /// The wrapped boolean.
  final bool value;

  @override
  Object? toEncodable() => value;

  @override
  bool operator ==(Object other) =>
      other is BeakJsonBool && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'BeakJsonBool($value)';
}

/// The JSON `null` value.
final class BeakJsonNull extends BeakJson {
  /// Creates a null node.
  const BeakJsonNull();

  @override
  Object? toEncodable() => null;

  @override
  bool operator ==(Object other) => other is BeakJsonNull;

  @override
  int get hashCode => null.hashCode;

  @override
  String toString() => 'BeakJsonNull()';
}
