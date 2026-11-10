import 'package:yaml/yaml.dart';

import '../project/beak_project_config.dart' show BeakProjectConfigException;
import 'yaml_reading.dart';

part 'generate_settings_parse.dart';

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
    this.definitions = 'definitions',
    this.handlers,
    this.prefix,
    this.roles,
    this.areas = const {},
    this.conventions = const BeakGenerateConventions(),
  });

  /// The pure-Dart package of `@Resource` definition classes, relative to
  /// `beak.yaml`. Parts go next to each class, support libraries into its
  /// `lib/src/generated/`.
  final String definitions;

  /// The folder of the Serverpod server the handler base classes go into,
  /// relative to `beak.yaml`, or `null` when no model runs custom code.
  final String? handlers;

  /// The `UpperCamelCase` prefix of the generated names, or `null` for the
  /// definitions package's name without `_definitions`.
  final String? prefix;

  /// The Serverpod enum every role name is checked against, if any.
  final String? roles;

  /// The roles of each area, by area name.
  final Map<String, BeakAreaRoles> areas;

  /// The presentation conventions.
  final BeakGenerateConventions conventions;

  /// These settings as plain data, for the inputs stamp.
  Map<String, Object?> toJson() => {
    'definitions': definitions,
    'handlers': handlers,
    'prefix': prefix,
    'roles': roles,
    'areas': {for (final e in areas.entries) e.key: e.value.toJson()},
    'conventions': conventions.toJson(),
  };
}
