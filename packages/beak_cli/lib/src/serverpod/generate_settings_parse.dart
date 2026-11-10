part of 'generate_settings.dart';

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
  for (final removed in const ['output', 'inventory', 'writes']) {
    if (map.containsKey(removed)) {
      throw BeakProjectConfigException(
        'generate.$removed is gone: the definition classes in '
        'generate.definitions say what is exposed and how it is written. '
        'See docs/serverpod/admin-app/generate.md.',
      );
    }
  }
  rejectUnknownYamlKeys(map, const {
    'definitions',
    'handlers',
    'prefix',
    'roles',
    'areas',
    'conventions',
  }, 'generate.');
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
    definitions:
        optionalYamlPath(map['definitions'], 'generate.definitions') ??
        'definitions',
    handlers: optionalYamlPath(map['handlers'], 'generate.handlers'),
    prefix: prefix,
    roles: roles,
    areas: _areasOf(map['areas']),
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
