import 'package:yaml/yaml.dart';

import '../project/beak_project_config.dart' show BeakProjectConfigException;

/// [value] as a mapping, or a [BeakProjectConfigException] naming [context].
YamlMap requireYamlMap(Object? value, String context) {
  final Object? raw = value is YamlNode ? value.value : value;
  if (raw is YamlMap) return raw;
  throw BeakProjectConfigException('$context must be a mapping.');
}

/// Fails on every key of [map] that is not in [allowed].
void rejectUnknownYamlKeys(YamlMap map, Set<String> allowed, String prefix) {
  for (final key in map.keys) {
    final String name = '$key';
    if (!allowed.contains(name)) {
      throw BeakProjectConfigException(
        'unknown key "$prefix$name". Expected one of: '
        '${(allowed.toList()..sort()).join(', ')}.',
      );
    }
  }
}

/// A string value, or `null` when the key is not written.
String? optionalYamlString(Object? value, String key) {
  final Object? raw = value is YamlNode ? value.value : value;
  if (raw == null) return null;
  if (raw is String && raw.trim().isNotEmpty) return raw;
  throw BeakProjectConfigException('$key must be a non-empty string.');
}

/// A relative path: no root, no backslash, no empty text.
String? optionalYamlPath(Object? value, String key) {
  final String? path = optionalYamlString(value, key);
  if (path == null) return null;
  if (path.startsWith('/') || path.contains(r'\')) {
    throw BeakProjectConfigException(
      '$key must be a relative path with forward slashes (got "$path").',
    );
  }
  return path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
}

/// A list of strings, or `null` when the key is not written.
List<String>? optionalYamlStringList(Object? value, String key) {
  if (value == null) return null;
  if (value is! YamlList) {
    throw BeakProjectConfigException('$key must be a list of strings.');
  }
  return [
    for (final item in value)
      if (item is String && item.trim().isNotEmpty)
        item
      else
        throw BeakProjectConfigException(
          '$key must hold non-empty strings (got "$item").',
        ),
  ];
}

/// A list of relative paths, or `null` when the key is not written.
List<String>? optionalYamlPathList(Object? value, String key) {
  final List<String>? paths = optionalYamlStringList(value, key);
  if (paths == null) return null;
  return [for (final path in paths) optionalYamlPath(path, key) ?? path];
}

/// A role name or a non-empty list of them.
List<String> requiredRoles(Object? value, String key) {
  if (value is String && value.trim().isNotEmpty) return [value];
  if (value is YamlList && value.isNotEmpty) {
    return optionalYamlStringList(value, key)!;
  }
  throw BeakProjectConfigException(
    '$key must name a role, or list the roles that are all required.',
  );
}

/// [value] as a mapping, or `null` when the key is not written.
YamlMap? optionalYamlMap(Object? value, String context) {
  final Object? raw = value is YamlNode ? value.value : value;
  if (raw == null) return null;
  if (raw is YamlMap) return raw;
  throw BeakProjectConfigException('$context must be a mapping.');
}
