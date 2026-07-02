/// Manages per-field attribute casts for a model.
library;

import 'attribute_cast.dart';

/// Maps model field names to their [AttributeCast].
///
/// A [CastManager] is a thin coordinator: each registered cast
/// converts a raw column value into its domain type on read, and
/// back into a storage representation on write. Fields without a
/// registered cast are returned untouched.
final class CastManager {
  /// Creates a [CastManager] seeded with [casts] keyed by field name.
  CastManager([Map<String, AttributeCast>? casts])
    : _casts = <String, AttributeCast>{...?casts};

  final Map<String, AttributeCast> _casts;

  /// Whether [field] has a cast registered.
  bool hasCast(String field) => _casts.containsKey(field);

  /// Field names that have a cast registered.
  Iterable<String> get registeredFields => _casts.keys;

  /// Registers [cast] for [field], replacing any existing entry.
  void register(String field, AttributeCast cast) {
    _casts[field] = cast;
  }

  /// Removes the cast registered for [field], if any.
  void unregister(String field) {
    _casts.remove(field);
  }

  /// Decode every entry of [row] using the registered casts.
  ///
  /// Fields without a registered cast pass through unchanged.
  Map<String, Object?> decodeAll(Map<String, Object?> row) {
    final out = <String, Object?>{};
    for (final entry in row.entries) {
      out[entry.key] = decodeOne(entry.key, entry.value);
    }
    return out;
  }

  /// Encode every entry of [values] using the registered casts.
  Map<String, Object?> encodeAll(Map<String, Object?> values) {
    final out = <String, Object?>{};
    for (final entry in values.entries) {
      out[entry.key] = encodeOne(entry.key, entry.value);
    }
    return out;
  }

  /// Decode a single value for [field].
  Object? decodeOne(String field, Object? raw) {
    final cast = _casts[field];
    if (cast == null) return raw;
    return cast.decode(raw);
  }

  /// Encode a single value for [field].
  Object? encodeOne(String field, Object? value) {
    final cast = _casts[field];
    if (cast == null) return value;
    return cast.encode(value);
  }
}
