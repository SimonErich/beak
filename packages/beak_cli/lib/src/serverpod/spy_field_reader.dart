import 'package:yaml/yaml.dart';

import 'dart_literals.dart';
import 'generate_issue.dart';
import 'spy_model.dart';

/// Options a Serverpod 4 field accepts that change nothing Beak reads.
const Set<String> _ignoredFieldOptions = {
  'required',
  'serialized',
  'jsonKey',
  'tail',
  'defaultModel',
  'defaultPersist',
  'unique',
};

const Set<String> _relationKeys = {
  'parent',
  'field',
  'name',
  'onDelete',
  'onUpdate',
  'optional',
  'fk',
  'deferrable',
  'deferred',
};

/// Reads the `fields:` of one Serverpod model.
///
/// An option Serverpod does not know, or one this reader does not understand,
/// is an issue rather than a silent no-op: an option that changes a column and
/// is skipped would generate a schema that disagrees with the database.
List<SpyField> readSpyFields(
  Object? fields,
  String path,
  String owner,
  BeakIssueSink issues,
) {
  if (fields == null) return const [];
  if (fields is! YamlMap) {
    issues.add(path, '$owner: fields must be a mapping of name to type.');
    return const [];
  }
  final result = <SpyField>[];
  for (final entry in fields.entries) {
    final String name = '${entry.key}';
    final SpyField? field = switch (entry.value) {
      final String text => _fromText(name, text, path, owner, issues),
      final YamlMap map => _fromMap(name, map, path, owner, issues),
      _ => null,
    };
    if (field == null) {
      issues.add(
        path,
        '$owner.$name: the field must be a type, such as `String?`.',
      );
    } else {
      result.add(field);
    }
  }
  return result;
}

SpyField? _fromText(
  String name,
  String text,
  String path,
  String owner,
  BeakIssueSink issues,
) {
  final parts = splitTopLevel(text);
  if (parts.isEmpty) return null;
  final options = <String, String>{};
  var persist = true;
  SpyRelation? relation;
  for (final part in parts.skip(1)) {
    if (part == '!persist') {
      persist = false;
    } else if (part == 'persist') {
      persist = true;
    } else if (part == 'relation' || part.startsWith('relation(')) {
      relation = _relationOf(
        part == 'relation' ? '' : part.substring(9, part.lastIndexOf(')')),
        path,
        '$owner.$name',
        issues,
      );
    } else {
      final int equals = part.indexOf('=');
      final String key = equals < 0 ? part : part.substring(0, equals).trim();
      options[key] = equals < 0 ? '' : part.substring(equals + 1).trim();
    }
  }
  return _build(
    name,
    parts.first,
    options,
    persist,
    relation,
    path,
    owner,
    issues,
  );
}

SpyField? _fromMap(
  String name,
  YamlMap map,
  String path,
  String owner,
  BeakIssueSink issues,
) {
  final Object? type = map['type'];
  if (type is! String) return null;
  final options = <String, String>{};
  var persist = true;
  SpyRelation? relation;
  for (final entry in map.entries) {
    final String key = '${entry.key}';
    if (key == 'type') continue;
    if (key == 'persist') {
      persist = entry.value != false;
    } else if (key == 'relation') {
      final Object? value = entry.value;
      relation = value is YamlMap
          ? _relationOfMap(value, path, '$owner.$name', issues)
          : const SpyRelation();
    } else {
      options[key] = '${entry.value ?? ''}';
    }
  }
  return _build(
    name,
    type.trim(),
    options,
    persist,
    relation,
    path,
    owner,
    issues,
  );
}

SpyField _build(
  String name,
  String type,
  Map<String, String> options,
  bool persist,
  SpyRelation? relation,
  String path,
  String owner,
  BeakIssueSink issues,
) {
  for (final key in options.keys) {
    if (_ignoredFieldOptions.contains(key) ||
        const {'scope', 'default', 'column'}.contains(key)) {
      continue;
    }
    issues.add(
      path,
      '$owner.$name: the option "$key" is not one Beak understands. '
      'Remove it, or report it to Beak if Serverpod accepts it.',
    );
  }
  final String? scope = options['scope'];
  if (scope != null && !const {'all', 'serverOnly', 'none'}.contains(scope)) {
    issues.add(
      path,
      '$owner.$name: scope=$scope is not all, serverOnly or none.',
    );
  }
  return SpyField(
    name: name,
    type: type,
    relation: relation,
    scope: scope,
    persist: persist,
    defaultValue: options['default'],
    hasDefault: const {
      'default',
      'defaultModel',
      'defaultPersist',
    }.any(options.containsKey),
    column: options['column'],
  );
}

SpyRelation _relationOf(
  String inner,
  String path,
  String where,
  BeakIssueSink issues,
) {
  final values = <String, Object?>{};
  for (final part in splitTopLevel(inner)) {
    final int equals = part.indexOf('=');
    if (equals < 0) {
      values[part] = true;
    } else {
      values[part.substring(0, equals).trim()] = part
          .substring(equals + 1)
          .trim();
    }
  }
  return _relationFrom(values, path, where, issues);
}

SpyRelation _relationOfMap(
  YamlMap map,
  String path,
  String where,
  BeakIssueSink issues,
) => _relationFrom(
  {for (final entry in map.entries) '${entry.key}': entry.value},
  path,
  where,
  issues,
);

SpyRelation _relationFrom(
  Map<String, Object?> values,
  String path,
  String where,
  BeakIssueSink issues,
) {
  for (final key in values.keys) {
    if (!_relationKeys.contains(key)) {
      issues.add(path, '$where: relation(...) has the unknown option "$key".');
    }
  }
  String? text(String key) => values[key] == null ? null : '${values[key]}';
  return SpyRelation(
    parent: text('parent'),
    field: text('field'),
    name: text('name'),
    onDelete: text('onDelete'),
    optional: values['optional'] == true,
  );
}
