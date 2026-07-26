import 'dart:io';

import 'package:yaml/yaml.dart';

/// Thrown when `beak.yaml` cannot be understood.
///
/// Unknown keys are errors rather than silent no-ops: a typo in a config file
/// that quietly does nothing is worse than one that fails at generate time.
final class BeakProjectConfigException implements Exception {
  /// Creates a config failure described by [message].
  const BeakProjectConfigException(this.message);

  /// What is wrong, and how to fix it.
  final String message;

  @override
  String toString() => 'beak.yaml: $message';
}

/// Where the panel points its API calls.
final class BeakApiSettings {
  /// Creates API settings.
  const BeakApiSettings({this.baseUrl = 'http://localhost:8080'});

  /// Origin the panel calls, compiled in.
  ///
  /// `auto` means "the origin the panel was served from", which is what a
  /// deployment fronting both halves behind one host wants.
  final String baseUrl;

  /// Whether [baseUrl] resolves at runtime rather than being a fixed origin.
  bool get isAuto => baseUrl == 'auto';

  /// A Dart expression evaluating to the base URL.
  String get expression => isAuto
      ? "kIsWeb ? Uri.base.origin : 'http://localhost:8080'"
      : "const String.fromEnvironment('BEAK_API_BASE_URL', "
            "defaultValue: '$baseUrl')";
}

/// Per-resource presentation the panel reads before falling back to defaults.
final class BeakResourceOverride {
  /// Creates an override for one table.
  const BeakResourceOverride({this.icon, this.label, this.section});

  /// `OiIcons` identifier to show in the navigation.
  final String? icon;

  /// Navigation label; defaults to a title-cased table name.
  final String? label;

  /// Navigation group this resource belongs to.
  final String? section;
}

/// The decoded `beak.yaml`.
///
/// YAML carries scalars, enums and ordering; Dart carries anything that
/// references a symbol or holds a closure. Because this is read at *generate*
/// time and emitted as typed Dart literals, no map ever reaches runtime.
final class BeakProjectConfig {
  /// Creates a project configuration.
  const BeakProjectConfig({
    required this.name,
    this.api = const BeakApiSettings(),
    this.resources = const {},
    this.sidebarCollapsible = true,
    this.sidebarStartCollapsed = false,
  });

  /// The defaults applied when a project has no `beak.yaml` at all.
  ///
  /// Deleting the file is a supported state: the panel is titled after the
  /// package and everything else falls back.
  factory BeakProjectConfig.defaults({required String packageName}) =>
      BeakProjectConfig(name: titleCase(packageName));

  /// Parses [yamlSource].
  ///
  /// Throws a [BeakProjectConfigException] naming the offending key on
  /// anything it does not recognise.
  factory BeakProjectConfig.parse(
    String yamlSource, {
    required String packageName,
  }) {
    final Object? document = loadYaml(yamlSource);
    if (document == null) {
      return BeakProjectConfig.defaults(packageName: packageName);
    }
    final YamlMap root = _requireMap(document, 'the document root');
    _rejectUnknownKeys(root, const {'name', 'api', 'theme', 'resources'}, '');

    final YamlMap? api = _optionalMap(root['api'], 'api');
    if (api != null) {
      _rejectUnknownKeys(api, const {'baseUrl'}, 'api.');
    }
    final YamlMap? theme = _optionalMap(root['theme'], 'theme');
    if (theme != null) {
      _rejectUnknownKeys(theme, const {'sidebar'}, 'theme.');
    }
    final YamlMap? sidebar = _optionalMap(theme?['sidebar'], 'theme.sidebar');
    if (sidebar != null) {
      _rejectUnknownKeys(sidebar, const {
        'collapsible',
        'startCollapsed',
      }, 'theme.sidebar.');
    }

    final resources = <String, BeakResourceOverride>{};
    final YamlMap? declared = _optionalMap(root['resources'], 'resources');
    final Map<dynamic, YamlNode> declaredNodes =
        declared?.nodes ?? const <dynamic, YamlNode>{};
    for (final entry in declaredNodes.entries) {
      final String table = entry.key.toString();
      final YamlMap options = _requireMap(
        entry.value.value,
        'resources.$table',
      );
      _rejectUnknownKeys(options, const {
        'icon',
        'label',
        'section',
      }, 'resources.$table.');
      resources[table] = BeakResourceOverride(
        icon: _optionalString(options['icon'], 'resources.$table.icon'),
        label: _optionalString(options['label'], 'resources.$table.label'),
        section: _optionalString(
          options['section'],
          'resources.$table.section',
        ),
      );
    }

    return BeakProjectConfig(
      name: _optionalString(root['name'], 'name') ?? titleCase(packageName),
      api: BeakApiSettings(
        baseUrl:
            _optionalString(api?['baseUrl'], 'api.baseUrl') ??
            'http://localhost:8080',
      ),
      resources: resources,
      sidebarCollapsible:
          _optionalBool(sidebar?['collapsible'], 'theme.sidebar.collapsible') ??
          true,
      sidebarStartCollapsed:
          _optionalBool(
            sidebar?['startCollapsed'],
            'theme.sidebar.startCollapsed',
          ) ??
          false,
    );
  }

  /// Reads `beak.yaml` from [projectRoot], or returns the defaults when the
  /// file does not exist.
  factory BeakProjectConfig.load(
    Directory projectRoot, {
    required String packageName,
  }) {
    final file = File('${projectRoot.path}/beak.yaml');
    return file.existsSync()
        ? BeakProjectConfig.parse(
            file.readAsStringSync(),
            packageName: packageName,
          )
        : BeakProjectConfig.defaults(packageName: packageName);
  }

  /// Panel title.
  final String name;

  /// Where the panel calls its API.
  final BeakApiSettings api;

  /// Per-table presentation overrides, keyed by table name.
  final Map<String, BeakResourceOverride> resources;

  /// Whether the sidebar can be collapsed.
  final bool sidebarCollapsible;

  /// Whether the sidebar starts collapsed.
  final bool sidebarStartCollapsed;

  static YamlMap _requireMap(Object? value, String context) {
    if (value is YamlMap) {
      return value;
    }
    throw BeakProjectConfigException('$context must be a mapping.');
  }

  static YamlMap? _optionalMap(Object? value, String context) {
    if (value == null) {
      return null;
    }
    return _requireMap(value is YamlNode ? value.value : value, context);
  }

  static String? _optionalString(Object? value, String key) {
    final Object? raw = value is YamlNode ? value.value : value;
    if (raw == null) {
      return null;
    }
    if (raw is String) {
      return raw;
    }
    throw BeakProjectConfigException('$key must be a string (got $raw).');
  }

  static bool? _optionalBool(Object? value, String key) {
    final Object? raw = value is YamlNode ? value.value : value;
    if (raw == null) {
      return null;
    }
    if (raw is bool) {
      return raw;
    }
    throw BeakProjectConfigException('$key must be true or false (got $raw).');
  }

  static void _rejectUnknownKeys(
    YamlMap map,
    Set<String> allowed,
    String prefix,
  ) {
    for (final key in map.keys) {
      final String name = key.toString();
      if (!allowed.contains(name)) {
        throw BeakProjectConfigException(
          'unknown key "$prefix$name". Expected one of: '
          '${(allowed.toList()..sort()).join(', ')}.',
        );
      }
    }
  }

  /// The `name:` a project's pubspec declares, or `beak_app` when it has
  /// none.
  ///
  /// Read with a line scan rather than a YAML parse: a pubspec may not be
  /// valid YAML mid-edit, and a missing name should not stop generation.
  static String packageNameOf(Directory projectRoot) {
    final file = File('${projectRoot.path}/pubspec.yaml');
    return file.existsSync()
        ? packageNameIn(file.readAsStringSync())
        : 'beak_app';
  }

  /// The `name:` declared in [pubspecSource].
  static String packageNameIn(String pubspecSource) {
    for (final line in pubspecSource.split('\n')) {
      final match = RegExp(r'^name:\s*(\S+)\s*$').firstMatch(line);
      if (match != null) {
        return match.group(1)!;
      }
    }
    return 'beak_app';
  }

  /// `acme_admin` -> `Acme Admin`.
  static String titleCase(String snake) => snake
      .split(RegExp('[_-]'))
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}
