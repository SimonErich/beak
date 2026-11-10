import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'dart_literals.dart';
import 'generate_issue.dart';
import 'generate_settings.dart';
import 'spy_field_reader.dart';
import 'spy_model.dart';

const Set<String> _classKeys = {
  'class',
  'table',
  'extends',
  'fields',
  'indexes',
  'serverOnly',
  'sealed',
  'immutable',
  'serialized',
  'database',
  'managedMigration',
};

const Set<String> _enumKeys = {
  'enum',
  'values',
  'properties',
  'serialized',
  'default',
  'serverOnly',
};

const Set<String> _indexKeys = {
  'fields',
  'unique',
  'type',
  'nullsDistinct',
  'operatorClass',
  'distanceFunction',
  'parameters',
};

/// Reads the `*.spy.yaml` models of a Serverpod project.
final class SpyReader {
  /// Reads the models [settings] names, resolved from [serverRoot].
  const SpyReader(this.serverRoot, this.settings);

  /// The Serverpod server package.
  final Directory serverRoot;

  /// Which folders to scan and which to skip.
  final BeakServerpodSettings settings;

  /// Reads every model, or throws all the problems at once.
  SpyProject read() {
    final issues = BeakIssueSink();
    final classes = <String, SpyClass>{};
    final enums = <String, SpyEnum>{};
    for (final file in _files()) {
      final String path = p.posix.joinAll(
        p.split(p.relative(file.path, from: serverRoot.path)),
      );
      final Object? document;
      try {
        document = loadYaml(file.readAsStringSync());
      } on YamlException catch (error) {
        issues.add(path, 'not valid YAML: ${error.message}');
        continue;
      }
      if (document is! YamlMap) {
        issues.add(
          path,
          'a Serverpod model is a mapping with `class:` or `enum:`.',
        );
        continue;
      }
      if (document.containsKey('exception')) continue;
      if (document.containsKey('enum')) {
        // An excluded folder still declares the enums an admitted model uses.
        _readEnum(document, path, issues, enums);
      } else if (document.containsKey('class')) {
        if (_excluded(path)) continue;
        _readClass(document, path, issues, classes);
      } else {
        issues.add(path, 'has none of `class:`, `enum:` or `exception:`.');
      }
    }
    issues.throwIfAny();
    return SpyProject(classes: classes, enums: enums);
  }

  List<File> _files() {
    final files = <File>[];
    for (final model in settings.models) {
      final directory = Directory(p.join(serverRoot.path, model));
      if (!directory.existsSync()) {
        throw BeakGenerateException.single(
          'beak.yaml',
          'serverpod.models names "$model", which is not a folder of '
              '${serverRoot.path}.',
        );
      }
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.spy.yaml')) continue;
        files.add(entity);
      }
    }
    return files..sort((a, b) => a.path.compareTo(b.path));
  }

  bool _excluded(String path) => settings.exclude.any(
    (prefix) => path == prefix || path.startsWith('$prefix/'),
  );

  void _readClass(
    YamlMap document,
    String path,
    BeakIssueSink issues,
    Map<String, SpyClass> classes,
  ) {
    final Object? name = document['class'];
    if (name is! String) {
      issues.add(path, '`class:` must be a class name.');
      return;
    }
    for (final key in document.keys) {
      if (!_classKeys.contains('$key')) {
        issues.add(path, '$name: the key "$key" is not one Beak understands.');
      }
    }
    if (classes.containsKey(name)) {
      issues.add(
        path,
        'the class $name is declared twice (also in ${classes[name]!.path}).',
      );
      return;
    }
    classes[name] = SpyClass(
      name: name,
      path: path,
      table: _text(document['table']),
      parent: _text(document['extends']),
      serverOnly: document['serverOnly'] == true,
      fields: readSpyFields(document['fields'], path, name, issues),
      indexes: _indexes(document['indexes'], path, name, issues),
    );
  }

  List<SpyIndex> _indexes(
    Object? raw,
    String path,
    String owner,
    BeakIssueSink issues,
  ) {
    if (raw is! YamlMap) return const [];
    final result = <SpyIndex>[];
    for (final entry in raw.entries) {
      final Object? spec = entry.value;
      if (spec is! YamlMap) continue;
      for (final key in spec.keys) {
        if (!_indexKeys.contains('$key')) {
          issues.add(
            path,
            '$owner: the index "${entry.key}" has the unknown key "$key".',
          );
        }
      }
      final Object? fields = spec['fields'];
      result.add(
        SpyIndex(
          name: '${entry.key}',
          fields: switch (fields) {
            final String text => splitTopLevel(text),
            final YamlList list => [for (final item in list) '$item'],
            _ => const [],
          },
          unique: spec['unique'] == true,
        ),
      );
    }
    return result;
  }

  void _readEnum(
    YamlMap document,
    String path,
    BeakIssueSink issues,
    Map<String, SpyEnum> enums,
  ) {
    final Object? name = document['enum'];
    if (name is! String) {
      issues.add(path, '`enum:` must be an enum name.');
      return;
    }
    for (final key in document.keys) {
      if (!_enumKeys.contains('$key')) {
        issues.add(path, '$name: the key "$key" is not one Beak understands.');
      }
    }
    final properties = <String, String>{
      if (document['properties'] case final YamlMap map)
        for (final entry in map.entries) '${entry.key}': '${entry.value}',
    };
    final values = <SpyEnumValue>[];
    final Object? rawValues = document['values'];
    for (final raw in rawValues is YamlList ? rawValues : const <Object?>[]) {
      final (String, Map<Object?, Object?>)? parsed = switch (raw) {
        final String value => (value, const {}),
        final YamlMap map when map.length == 1 => (
          '${map.keys.single}',
          switch (map.values.single) {
            final YamlMap properties => properties,
            _ => const <Object?, Object?>{},
          },
        ),
        _ => null,
      };
      if (parsed == null) {
        issues.add(
          path,
          '$name: each value is a name, or a name with properties.',
        );
        continue;
      }
      final literals = <String>[];
      for (final property in properties.entries) {
        final String? literal = dartLiteral(parsed.$2[property.key]);
        if (literal == null || literal == 'null') {
          issues.add(
            path,
            '$name.${parsed.$1}: the property "${property.key}" needs a '
            '${property.value} value.',
          );
        } else {
          literals.add(literal);
        }
      }
      values.add(SpyEnumValue(parsed.$1, literals));
    }
    if (enums.containsKey(name)) {
      issues.add(path, 'the enum $name is declared twice.');
      return;
    }
    enums[name] = SpyEnum(
      name: name,
      path: path,
      values: values,
      properties: properties,
      serialized: _text(document['serialized']),
    );
  }
}

String? _text(Object? value) => value is String ? value : null;
