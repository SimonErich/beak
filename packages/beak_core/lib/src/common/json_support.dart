/// Internal strict-decoding helpers shared by `fromJson` constructors across
/// the package. Not exported by the barrel.
///
/// Every helper throws a [BeakConfigurationException] naming the decoding
/// `context` (the Beak type being decoded) so malformed wire input fails
/// loudly and precisely.
library;

import 'beak_exception.dart';

/// Returns the value stored under [key] in [json], throwing when the key is
/// absent.
Object? requireJsonKey(Map<String, Object?> json, String key, String context) {
  if (!json.containsKey(key)) {
    throw BeakConfigurationException(
      '$context JSON is missing the "$key" key.',
    );
  }
  return json[key];
}

/// Returns the string stored under [key] in [json], throwing when the key is
/// absent or not a string.
String requireJsonString(
  Map<String, Object?> json,
  String key,
  String context,
) => switch (requireJsonKey(json, key, context)) {
  final String value => value,
  final Object? other => throw BeakConfigurationException(
    '$context JSON key "$key" must be a string, got $other.',
  ),
};

/// Returns the boolean stored under [key] in [json], throwing when the key
/// is absent or not a boolean.
bool requireJsonBool(Map<String, Object?> json, String key, String context) =>
    switch (requireJsonKey(json, key, context)) {
      final bool value => value,
      final Object? other => throw BeakConfigurationException(
        '$context JSON key "$key" must be a boolean, got $other.',
      ),
    };

/// Returns the integer stored under [key] in [json], throwing when the key
/// is absent or not an integer.
int requireJsonInt(Map<String, Object?> json, String key, String context) =>
    switch (requireJsonKey(json, key, context)) {
      final int value => value,
      final Object? other => throw BeakConfigurationException(
        '$context JSON key "$key" must be an integer, got $other.',
      ),
    };

/// Returns the integer stored under [key] in [json], throwing when the key
/// is absent or holds neither an integer nor `null`.
int? requireJsonIntOrNull(
  Map<String, Object?> json,
  String key,
  String context,
) => switch (requireJsonKey(json, key, context)) {
  null => null,
  final int value => value,
  final Object other => throw BeakConfigurationException(
    '$context JSON key "$key" must be an integer or null, got $other.',
  ),
};

/// Returns the JSON object stored under [key] in [json], throwing when the
/// key is absent or not a JSON object.
Map<String, Object?> requireJsonMap(
  Map<String, Object?> json,
  String key,
  String context,
) => switch (requireJsonKey(json, key, context)) {
  final Map<String, Object?> value => value,
  final Object? other => throw BeakConfigurationException(
    '$context JSON key "$key" must be a JSON object, got $other.',
  ),
};

/// Validates that [value] (stored under [key] in a [context] JSON object) is
/// a list of JSON objects and returns it typed.
List<Map<String, Object?>> requireJsonMapList(
  Object? value,
  String key,
  String context,
) {
  if (value is! List<Object?>) {
    throw BeakConfigurationException(
      '$context JSON key "$key" must be a list, got $value.',
    );
  }
  final maps = <Map<String, Object?>>[];
  for (final element in value) {
    if (element is! Map<String, Object?>) {
      throw BeakConfigurationException(
        '$context JSON key "$key" must contain only JSON objects, '
        'got $element.',
      );
    }
    maps.add(element);
  }
  return maps;
}
