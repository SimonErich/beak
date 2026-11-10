import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'generate_issue.dart';
import 'generate_settings.dart';
import 'inventory_model.dart';
import 'yaml_reading.dart';

const Set<String> _fileKeys = {'area', 'resources', 'inputs'};
const Set<String> _resourceKeys = {
  'operations',
  'write',
  'writeFields',
  'ownedRelations',
  'scalarRelations',
  'display',
  'exclude',
  'hidden',
  'defaults',
  'area',
  'access',
  'reason',
  'restoreKey',
  'fields',
};
const Set<String> _fieldKeys = {
  'label',
  'min',
  'max',
  'maxLength',
  'format',
  'semantic',
  'text',
  'name',
};
const Set<String> _inputFieldKeys = {
  'belongsTo',
  'foreignKey',
  'type',
  'required',
  'label',
};

/// Reads every `*.yaml` inventory file under [directory], in path order.
///
/// The inventory is the reviewed admission list: which Serverpod models the
/// panel exposes, what may be written, and why a write is closed. Unknown keys
/// are an error, so a typo never silently drops a review decision.
Inventory readInventory(Directory directory, BeakGenerateSettings settings) {
  if (!directory.existsSync()) {
    throw BeakGenerateException.single(
      'beak.yaml',
      'generate.inventory names "${settings.inventory}", which is not a '
          'folder relative to beak.yaml.',
    );
  }
  final issues = BeakIssueSink();
  final resources = <String, InventoryResource>{};
  final inputs = <String, InventoryInput>{};
  final files = [
    for (final entity in directory.listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.yaml')) entity,
  ]..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final path = p.posix.joinAll(
      p.split(p.relative(file.path, from: directory.parent.path)),
    );
    final Object? document;
    try {
      document = loadYaml(file.readAsStringSync());
    } on YamlException catch (error) {
      issues.add(path, 'not valid YAML: ${error.message}');
      continue;
    }
    if (document is! YamlMap) {
      issues.add(path, 'an inventory file is a mapping.');
      continue;
    }
    rejectUnknownYamlKeys(document, _fileKeys, '');
    final String? area = optionalYamlString(document['area'], 'area');
    final YamlMap? declared = optionalYamlMap(
      document['resources'],
      'resources',
    );
    if (declared != null) {
      for (final entry in declared.nodes.entries) {
        final String name = '${entry.key}';
        final YamlMap map = requireYamlMap(entry.value.value, name);
        final resource = _resource(name, path, area, map, settings, issues);
        if (resource == null) continue;
        if (resources.containsKey(name)) {
          issues.add(path, '$name is admitted twice.');
          continue;
        }
        resources[name] = resource;
      }
    }
    final YamlMap? declaredInputs = optionalYamlMap(
      document['inputs'],
      'inputs',
    );
    if (declaredInputs != null) {
      for (final entry in declaredInputs.nodes.entries) {
        final String name = '${entry.key}';
        final input = _input(name, path, entry.value.value, issues);
        if (input != null) inputs[name] = input;
      }
    }
  }
  issues.throwIfAny();
  return Inventory(resources: resources, inputs: inputs);
}

InventoryResource? _resource(
  String name,
  String path,
  String? fileArea,
  YamlMap map,
  BeakGenerateSettings settings,
  BeakIssueSink issues,
) {
  rejectUnknownYamlKeys(map, _resourceKeys, '$name.');
  final List<String>? operations = optionalYamlStringList(
    map['operations'],
    '$name.operations',
  );
  final String? write = optionalYamlString(map['write'], '$name.write');
  final List<String>? writeFields = optionalYamlStringList(
    map['writeFields'],
    '$name.writeFields',
  );
  final area = optionalYamlString(map['area'], '$name.area') ?? fileArea;
  final writes = operations?.any((operation) => operation != 'read') ?? false;
  if (writes) {
    if (write == null) {
      issues.add(path, '$name opens writes but names no write binding.');
    } else if (!settings.writes.contains(write)) {
      issues.add(
        path,
        '$name.write "$write" is not one of generate.writes '
        '(${settings.writes.join(', ')}).',
      );
    }
    if (writeFields == null) {
      issues.add(
        path,
        '$name opens writes but does not review writeFields. Use an empty '
        'list when every change goes through a command.',
      );
    }
    if (area == null) {
      issues.add(path, '$name opens writes but belongs to no area.');
    }
  }
  if (write != null && !settings.writes.contains(write)) {
    issues.add(
      path,
      '$name.write "$write" is not one of generate.writes '
      '(${settings.writes.join(', ')}).',
    );
  }
  if (area != null && !settings.areas.containsKey(area)) {
    issues.add(path, '$name.area "$area" is not declared in generate.areas.');
  }
  if (!writes && (map['reason'] == null || '${map['reason']}'.trim().isEmpty)) {
    issues.add(
      path,
      '$name opens no writes, so a reason for the closed write is required.',
    );
  }
  return InventoryResource(
    name: name,
    path: path,
    area: area,
    operations: operations ?? const ['read'],
    write: write,
    writeFields: writeFields,
    ownedRelations:
        optionalYamlStringList(map['ownedRelations'], '$name.ownedRelations') ??
        const [],
    scalarRelations:
        optionalYamlStringList(
          map['scalarRelations'],
          '$name.scalarRelations',
        ) ??
        const [],
    display: optionalYamlString(map['display'], '$name.display'),
    exclude:
        optionalYamlStringList(map['exclude'], '$name.exclude') ?? const [],
    hidden: optionalYamlStringList(map['hidden'], '$name.hidden') ?? const [],
    defaults: _defaults(name, map['defaults']),
    access: _access(name, map['access']),
    reason: optionalYamlString(map['reason'], '$name.reason'),
    restoreKey: optionalYamlStringList(map['restoreKey'], '$name.restoreKey'),
    fields: _fields(name, map['fields']),
  );
}

Map<String, Object?> _defaults(String name, Object? raw) {
  if (raw == null) return const {};
  final map = requireYamlMap(raw, '$name.defaults');
  return {
    for (final entry in map.nodes.entries) '${entry.key}': entry.value.value,
  };
}

InventoryAccess _access(String name, Object? raw) {
  if (raw == null) return const InventoryAccess();
  final map = requireYamlMap(raw, '$name.access');
  const operations = {'read', 'write', 'create', 'update', 'delete'};
  rejectUnknownYamlKeys(map, {
    ...operations,
    'operations',
    'actions',
  }, '$name.access.');
  List<String> roles(Object? value, String where) =>
      optionalYamlStringList(value, where) ?? const [];
  final direct = <String, List<String>>{
    for (final operation in operations)
      if (map[operation] != null)
        operation: roles(map[operation], '$name.access.$operation'),
  };
  final nested = <String, List<String>>{};
  if (map['operations'] case final Object value) {
    final entries = requireYamlMap(value, '$name.access.operations');
    for (final entry in entries.nodes.entries) {
      nested['${entry.key}'] = roles(
        entry.value.value,
        '$name.access.operations.${entry.key}',
      );
    }
  }
  final actions = <String, List<String>>{};
  if (map['actions'] case final Object value) {
    for (final entry in requireYamlMap(
      value,
      '$name.access.actions',
    ).nodes.entries) {
      actions['${entry.key}'] = roles(
        entry.value.value,
        '$name.access.actions.${entry.key}',
      );
    }
  }
  return InventoryAccess(operations: {...nested, ...direct}, actions: actions);
}

Map<String, InventoryField> _fields(String name, Object? raw) {
  if (raw == null) return const {};
  final map = requireYamlMap(raw, '$name.fields');
  final result = <String, InventoryField>{};
  for (final entry in map.nodes.entries) {
    final String field = '${entry.key}';
    final c = requireYamlMap(entry.value.value, '$name.fields.$field');
    rejectUnknownYamlKeys(c, _fieldKeys, '$name.fields.$field.');
    final Object? min = c['min'];
    final Object? max = c['max'];
    final Object? maxLength = c['maxLength'];
    result[field] = InventoryField(
      label: optionalYamlString(c['label'], '$name.fields.$field.label'),
      min: min is num ? min : null,
      max: max is num ? max : null,
      maxLength: maxLength is int ? maxLength : null,
      format: optionalYamlString(c['format'], '$name.fields.$field.format'),
      semantic: optionalYamlString(
        c['semantic'],
        '$name.fields.$field.semantic',
      ),
      text: c['text'] == true,
      name: optionalYamlString(c['name'], '$name.fields.$field.name'),
    );
  }
  return result;
}

InventoryInput? _input(
  String name,
  String path,
  Object? raw,
  BeakIssueSink issues,
) {
  final map = requireYamlMap(raw, name);
  rejectUnknownYamlKeys(map, const {'fields', 'table'}, '$name.');
  final fields = requireYamlMap(map['fields'], '$name.fields');
  return InventoryInput(
    name: name,
    path: path,
    table: optionalYamlString(map['table'], '$name.table'),
    fields: {
      for (final entry in fields.nodes.entries)
        '${entry.key}': _inputField(name, '${entry.key}', entry.value.value),
    },
  );
}

InventoryInputField _inputField(String input, String name, Object? raw) {
  final map = requireYamlMap(raw, '$input.fields.$name');
  rejectUnknownYamlKeys(map, _inputFieldKeys, '$input.fields.$name.');
  return InventoryInputField(
    belongsTo: optionalYamlString(
      map['belongsTo'],
      '$input.fields.$name.belongsTo',
    ),
    foreignKey: optionalYamlString(
      map['foreignKey'],
      '$input.fields.$name.foreignKey',
    ),
    type: optionalYamlString(map['type'], '$input.fields.$name.type'),
    required: map['required'] != false,
    label: optionalYamlString(map['label'], '$input.fields.$name.label'),
  );
}
