import 'package:yaml/yaml.dart';

import '../project/beak_project_config.dart' show BeakProjectConfigException;
import 'yaml_reading.dart';

/// Where `beak generate` finds the Serverpod project (`serverpod:` in
/// `beak.yaml`).
final class BeakServerpodSettings {
  /// Creates the settings.
  const BeakServerpodSettings({
    required this.server,
    this.models = const ['lib/src'],
    this.exclude = const [],
    this.migrations = 'migrations',
  });

  /// The Serverpod server package, relative to `beak.yaml`.
  final String server;

  /// The folders scanned for `*.spy.yaml`, relative to [server].
  final List<String> models;

  /// Path prefixes, relative to [server], whose models are skipped.
  final List<String> exclude;

  /// The migrations folder, relative to [server]. Its newest
  /// `definition_project.json` is the physical truth.
  final String migrations;

  /// These settings as plain data, for the inputs stamp.
  Map<String, Object?> toJson() => {
    'server': server,
    'models': models,
    'exclude': exclude,
    'migrations': migrations,
  };
}

/// The roles that read and change an area: every role listed must be held.
final class BeakAreaRoles {
  /// Creates the roles of an area.
  const BeakAreaRoles({required this.read, required this.write});

  /// Roles that read the area's models.
  final List<String> read;

  /// Roles that create, update and (unless overridden) delete.
  final List<String> write;

  /// These roles as plain data, for the inputs stamp.
  Map<String, Object?> toJson() => {'read': read, 'write': write};
}

/// The default presentation rules `beak generate` applies by column name.
final class BeakGenerateConventions {
  /// Creates the conventions.
  const BeakGenerateConventions({
    this.dateOnly = defaultDateOnly,
    this.money,
    this.detailOnly = const [],
  });

  /// The `dateOnly` patterns used when `beak.yaml` names none.
  static const List<String> defaultDateOnly = ['*Date', '*On'];

  /// `DateTime` column names (patterns with `*`) that show a date, no time.
  final List<String> dateOnly;

  /// Integer minor-unit columns that carry a money semantic, if any.
  final BeakMoneyConvention? money;

  /// Column name patterns that appear on the detail view only. The primary
  /// key and the audit columns always do.
  final List<String> detailOnly;

  /// These conventions as plain data, for the inputs stamp.
  Map<String, Object?> toJson() => {
    'dateOnly': dateOnly,
    'money': money?.toJson(),
    'detailOnly': detailOnly,
  };
}

/// Which integer columns hold money in minor units, and in what currency.
final class BeakMoneyConvention {
  /// Creates the convention.
  const BeakMoneyConvention({
    required this.fields,
    required this.currency,
    this.scale = 2,
  });

  /// Column name patterns (`*Cents`).
  final List<String> fields;

  /// The ISO 4217 code every matching column is stored in.
  final String currency;

  /// Decimal places of one major unit: 2 for cents.
  final int scale;

  /// This convention as plain data, for the inputs stamp.
  Map<String, Object?> toJson() => {
    'fields': fields,
    'currency': currency,
    'scale': scale,
  };
}

/// What to generate and where (`generate:` in `beak.yaml`).
final class BeakGenerateSettings {
  /// Creates the settings.
  const BeakGenerateSettings({
    required this.output,
    this.inventory = 'definitions/resources',
    this.prefix,
    this.roles,
    this.areas = const {},
    this.writes = const [],
    this.conventions = const BeakGenerateConventions(),
  });

  /// The generated package, relative to `beak.yaml`.
  final String output;

  /// The folder of inventory files, relative to `beak.yaml`.
  final String inventory;

  /// The `UpperCamelCase` prefix of the generated names, or `null` for the
  /// output package's name without `_generated`.
  final String? prefix;

  /// The Serverpod enum every role name is checked against, if any.
  final String? roles;

  /// The roles of each area, by area name.
  final Map<String, BeakAreaRoles> areas;

  /// The write bindings, emitted as `enum <Prefix>Write`.
  final List<String> writes;

  /// The presentation conventions.
  final BeakGenerateConventions conventions;

  /// These settings as plain data, for the inputs stamp.
  Map<String, Object?> toJson() => {
    'output': output,
    'inventory': inventory,
    'prefix': prefix,
    'roles': roles,
    'areas': {for (final e in areas.entries) e.key: e.value.toJson()},
    'writes': writes,
    'conventions': conventions.toJson(),
  };
}

/// Reads `serverpod:` from [root], or `null` when it is not written.
BeakServerpodSettings? parseServerpodSettings(Object? raw) {
  if (raw == null) return null;
  final YamlMap map = requireYamlMap(raw, 'serverpod');
  rejectUnknownYamlKeys(map, const {
    'server',
    'models',
    'exclude',
    'migrations',
  }, 'serverpod.');
  final String? server = optionalYamlPath(map['server'], 'serverpod.server');
  if (server == null) {
    throw const BeakProjectConfigException(
      'serverpod.server is required: the path of the Serverpod server '
      'package, relative to beak.yaml (such as ../server).',
    );
  }
  return BeakServerpodSettings(
    server: server,
    models:
        optionalYamlPathList(map['models'], 'serverpod.models') ??
        const ['lib/src'],
    exclude:
        optionalYamlPathList(map['exclude'], 'serverpod.exclude') ?? const [],
    migrations:
        optionalYamlPath(map['migrations'], 'serverpod.migrations') ??
        'migrations',
  );
}

/// Reads `generate:`, or `null` when it is not written.
BeakGenerateSettings? parseGenerateSettings(
  Object? raw, {
  required bool hasServerpod,
}) {
  if (raw == null) return null;
  final YamlMap map = requireYamlMap(raw, 'generate');
  if (!hasServerpod) {
    throw const BeakProjectConfigException(
      'generate: needs a serverpod: section that says where the Serverpod '
      'models are, such as `serverpod: {server: ../server}`.',
    );
  }
  rejectUnknownYamlKeys(map, const {
    'output',
    'inventory',
    'prefix',
    'roles',
    'areas',
    'writes',
    'conventions',
  }, 'generate.');
  final String? output = optionalYamlPath(map['output'], 'generate.output');
  if (output == null) {
    throw const BeakProjectConfigException(
      'generate.output is required: the pure-Dart package `beak generate` '
      'writes, relative to beak.yaml (such as generated).',
    );
  }
  final String? prefix = optionalYamlString(map['prefix'], 'generate.prefix');
  if (prefix != null && !RegExp(r'^[A-Z][A-Za-z0-9]*$').hasMatch(prefix)) {
    throw BeakProjectConfigException(
      'generate.prefix must be an UpperCamelCase name (got "$prefix").',
    );
  }
  final String? roles = optionalYamlString(map['roles'], 'generate.roles');
  if (roles != null && !RegExp(r'^[A-Z][A-Za-z0-9]*$').hasMatch(roles)) {
    throw BeakProjectConfigException(
      'generate.roles names a Serverpod enum, so it must be an '
      'UpperCamelCase name (got "$roles").',
    );
  }
  return BeakGenerateSettings(
    output: output,
    inventory:
        optionalYamlPath(map['inventory'], 'generate.inventory') ??
        'definitions/resources',
    prefix: prefix,
    roles: roles,
    areas: _areasOf(map['areas']),
    writes: _writesOf(map['writes']),
    conventions: _conventionsOf(map['conventions']),
  );
}

Map<String, BeakAreaRoles> _areasOf(Object? raw) {
  if (raw == null) return const {};
  final YamlMap areas = requireYamlMap(raw, 'generate.areas');
  final result = <String, BeakAreaRoles>{};
  for (final entry in areas.nodes.entries) {
    final String name = '${entry.key}';
    final String path = 'generate.areas.$name';
    if (!RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(name)) {
      throw BeakProjectConfigException(
        '$path: an area name is lowerCamelCase (got "$name").',
      );
    }
    final YamlMap roles = requireYamlMap(entry.value.value, path);
    rejectUnknownYamlKeys(roles, const {'read', 'write'}, '$path.');
    result[name] = BeakAreaRoles(
      read: requiredRoles(roles['read'], '$path.read'),
      write: requiredRoles(roles['write'], '$path.write'),
    );
  }
  return result;
}

List<String> _writesOf(Object? raw) {
  final List<String> names =
      optionalYamlStringList(raw, 'generate.writes') ?? const [];
  final seen = <String>{};
  for (final name in names) {
    if (!RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(name)) {
      throw BeakProjectConfigException(
        'generate.writes: "$name" must be a lowerCamelCase name, because it '
        'becomes a value of the generated Write enum.',
      );
    }
    if (!seen.add(name)) {
      throw BeakProjectConfigException('generate.writes lists "$name" twice.');
    }
  }
  return names;
}

BeakGenerateConventions _conventionsOf(Object? raw) {
  if (raw == null) return const BeakGenerateConventions();
  final YamlMap map = requireYamlMap(raw, 'generate.conventions');
  rejectUnknownYamlKeys(map, const {
    'dateOnly',
    'money',
    'detailOnly',
  }, 'generate.conventions.');
  return BeakGenerateConventions(
    dateOnly:
        optionalYamlStringList(
          map['dateOnly'],
          'generate.conventions.dateOnly',
        ) ??
        BeakGenerateConventions.defaultDateOnly,
    money: _moneyOf(map['money']),
    detailOnly:
        optionalYamlStringList(
          map['detailOnly'],
          'generate.conventions.detailOnly',
        ) ??
        const [],
  );
}

BeakMoneyConvention? _moneyOf(Object? raw) {
  if (raw == null) return null;
  const String path = 'generate.conventions.money';
  final YamlMap map = requireYamlMap(raw, path);
  rejectUnknownYamlKeys(map, const {'fields', 'currency', 'scale'}, '$path.');
  final List<String> fields =
      optionalYamlStringList(map['fields'], '$path.fields') ?? const [];
  final String? currency = optionalYamlString(
    map['currency'],
    '$path.currency',
  );
  if (fields.isEmpty) {
    throw const BeakProjectConfigException(
      '$path.fields must list at least one column name pattern, such as '
      "['*Cents'].",
    );
  }
  if (currency == null || !RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
    throw BeakProjectConfigException(
      '$path.currency must be a three-letter ISO 4217 code, such as EUR '
      '(got ${currency == null ? 'nothing' : '"$currency"'}).',
    );
  }
  final Object? scale = map['scale'];
  if (scale != null && (scale is! int || scale < 0 || scale > 6)) {
    throw BeakProjectConfigException(
      '$path.scale must be a whole number from 0 to 6 (got "$scale").',
    );
  }
  return BeakMoneyConvention(
    fields: fields,
    currency: currency,
    scale: scale is int ? scale : 2,
  );
}
