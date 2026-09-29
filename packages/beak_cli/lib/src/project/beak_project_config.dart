import 'dart:io';

import 'package:yaml/yaml.dart';

import '../agents/beak_skill_installer.dart';
import 'beak_discovery.dart';

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
  const BeakApiSettings({this.baseUrl = defaultBaseUrl});

  /// Origin the panel calls, compiled in.
  ///
  /// `auto` means "the origin the panel was served from", which is what a
  /// deployment fronting both halves behind one host wants.
  final String baseUrl;

  /// Whether [baseUrl] resolves at runtime rather than being a fixed origin.
  bool get isAuto => baseUrl == 'auto';

  /// Whether [baseUrl] is the origin `BeakPanel` already defaults to, so an
  /// authored entrypoint need not say it.
  bool get isDefault => baseUrl == defaultBaseUrl;

  /// Where the panel calls when nothing says otherwise.
  static const String defaultBaseUrl = 'http://localhost:8080';

  /// A Dart expression evaluating to the base URL.
  String get expression => isAuto
      ? "kIsWeb ? Uri.base.origin : 'http://localhost:8080'"
      : "const String.fromEnvironment('BEAK_API_BASE_URL', "
            "defaultValue: '$baseUrl')";
}

/// Where the server listens, when the project wants something other than
/// Beak's defaults.
///
/// These are *defaults*: a real `PORT` or `HOST` in the environment still
/// wins, because a deployment decides where its own process binds.
final class BeakServerSettings {
  /// Creates server settings.
  const BeakServerSettings({this.port, this.host});

  /// Port the server binds, or null for Beak's default (8080).
  final int? port;

  /// Interface the server binds, or null for Beak's default.
  final String? host;

  /// Whether anything here differs from Beak's defaults.
  bool get isDefault => port == null && host == null;

  /// The environment entries the generated host seeds itself with.
  Map<String, String> get environmentDefaults => {
    if (port != null) 'PORT': '$port',
    if (host != null) 'HOST': '$host',
  };
}

/// Where the panel's entrypoint lives, when the app is not Beak's alone.
///
/// A Beak project owns `lib/main.dart`, so `beak prepare` writes it. An
/// existing Flutter app cannot give that file up: `beak init` embeds the
/// panel next to the app, boots it from a file of its own, and records the
/// path here so `beak prepare` leaves `lib/main.dart` alone and `beak dev` and
/// `beak doctor` know which file starts the panel.
final class BeakPanelSettings {
  /// Creates panel settings.
  const BeakPanelSettings({this.entrypoint});

  /// The Dart file, relative to the project root, that boots the panel, or
  /// null for a project whose `lib/main.dart` is Beak's.
  final String? entrypoint;

  /// The file that boots the panel: [entrypoint], else `lib/main.dart`.
  String get entrypointPath => entrypoint ?? defaultEntrypoint;

  /// The entrypoint of a project that sets none.
  static const String defaultEntrypoint = 'lib/main.dart';
}

/// Which `AGENTS.md` files `beak prepare` and `beak agents` may write.
enum BeakAgentInstructions {
  /// The project's own, and the workspace root's when it is a member of one.
  all,

  /// The project's own only; a workspace root is left alone.
  package,

  /// None: Beak never touches `AGENTS.md` or `CLAUDE.md`.
  none,
}

/// What Beak writes for coding agents, and where.
///
/// Every default is on. A project that would rather keep agent files out of
/// its tree says so here and Beak stops, rather than writing and hoping
/// nobody minds.
final class BeakAgentSettings {
  /// Creates agent settings.
  const BeakAgentSettings({
    this.instructions = BeakAgentInstructions.all,
    this.docs = true,
    this.skills,
  });

  /// Which `AGENTS.md` files Beak keeps its block in.
  final BeakAgentInstructions instructions;

  /// Whether `beak prepare` copies the version-matched docs into
  /// `.dart_tool/beak/docs`.
  final bool docs;

  /// The folders `beak agents` installs skills into, or `null` to use the
  /// agent folders the workspace already has. An empty list installs none.
  final List<BeakSkillTarget>? skills;
}

/// Per-resource presentation the panel reads before falling back to defaults.
final class BeakResourceOverride {
  /// Creates an override for one table.
  const BeakResourceOverride({
    this.icon,
    this.label,
    this.section,
    this.hidden = false,
  });

  /// `OiIcons` identifier to show in the navigation.
  final String? icon;

  /// Navigation label; defaults to a title-cased table name.
  final String? label;

  /// Navigation group this resource belongs to.
  final String? section;

  /// Whether to keep this resource out of the navigation.
  ///
  /// The model is still registered, still has an API, and is still reachable
  /// as the far side of a relationship — it simply does not earn a sidebar
  /// entry. A real application has plenty of those: line items, pivots,
  /// lookup tables, anything only ever opened from its parent.
  ///
  /// Navigability is presentation, which is what this file already decides.
  final bool hidden;
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
    this.server = const BeakServerSettings(),
    this.panel = const BeakPanelSettings(),
    this.agents = const BeakAgentSettings(),
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
  /// anything it does not recognise, and the line and column of anything that
  /// is not YAML at all.
  factory BeakProjectConfig.parse(
    String yamlSource, {
    required String packageName,
  }) {
    final Object? document = _loadDocument(yamlSource);
    if (document == null) {
      return BeakProjectConfig.defaults(packageName: packageName);
    }
    final YamlMap root = _requireMap(document, 'the document root');
    _rejectUnknownKeys(root, const {
      'name',
      'api',
      'server',
      'panel',
      'agents',
      'theme',
      'resources',
    }, '');

    final YamlMap? api = _optionalMap(root['api'], 'api');
    if (api != null) {
      _rejectUnknownKeys(api, const {'baseUrl'}, 'api.');
    }
    final YamlMap? server = _optionalMap(root['server'], 'server');
    if (server != null) {
      _rejectUnknownKeys(server, const {'port', 'host'}, 'server.');
    }
    final YamlMap? panel = _optionalMap(root['panel'], 'panel');
    if (panel != null) {
      _rejectUnknownKeys(panel, const {'entrypoint'}, 'panel.');
    }
    final YamlMap? agents = _optionalMap(root['agents'], 'agents');
    if (agents != null) {
      _rejectUnknownKeys(agents, const {
        'instructions',
        'docs',
        'skills',
      }, 'agents.');
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
    // `YamlMap.nodes` is typed `Map<dynamic, YamlNode>` by the yaml package.
    // Widening the key to `Object?` accepts the same map and keeps `dynamic`
    // out of this file; a YAML key can be any scalar, including null.
    final Map<Object?, YamlNode> declaredNodes =
        declared?.nodes ?? const <Object?, YamlNode>{};
    for (final entry in declaredNodes.entries) {
      final String table = '${entry.key}';
      final YamlMap options = _requireMap(
        entry.value.value,
        'resources.$table',
      );
      _rejectUnknownKeys(options, const {
        'icon',
        'label',
        'section',
        'hidden',
      }, 'resources.$table.');
      resources[table] = BeakResourceOverride(
        icon: _optionalIcon(options['icon'], 'resources.$table.icon'),
        label: _optionalString(options['label'], 'resources.$table.label'),
        section: _optionalString(
          options['section'],
          'resources.$table.section',
        ),
        hidden:
            _optionalBool(options['hidden'], 'resources.$table.hidden') ??
            false,
      );
    }

    return BeakProjectConfig(
      name: _optionalString(root['name'], 'name') ?? titleCase(packageName),
      api: BeakApiSettings(
        baseUrl:
            _optionalString(api?['baseUrl'], 'api.baseUrl') ??
            BeakApiSettings.defaultBaseUrl,
      ),
      server: BeakServerSettings(
        port: _optionalPort(server?['port'], 'server.port'),
        host: _optionalString(server?['host'], 'server.host'),
      ),
      panel: BeakPanelSettings(
        entrypoint: _optionalEntrypoint(
          panel?['entrypoint'],
          'panel.entrypoint',
        ),
      ),
      agents: BeakAgentSettings(
        instructions: _instructionsOf(agents?['instructions']),
        docs: _optionalBool(agents?['docs'], 'agents.docs') ?? true,
        skills: _skillTargetsOf(agents?['skills']),
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

  /// Where the server binds, when the project asks for something specific.
  final BeakServerSettings server;

  /// Where the panel is booted from.
  final BeakPanelSettings panel;

  /// What Beak writes for coding agents.
  final BeakAgentSettings agents;

  /// Per-table presentation overrides, keyed by table name.
  final Map<String, BeakResourceOverride> resources;

  /// Whether the sidebar can be collapsed.
  final bool sidebarCollapsible;

  /// Whether the sidebar starts collapsed.
  final bool sidebarStartCollapsed;

  /// [yamlSource] as a YAML document.
  ///
  /// The scanner's exception carries a position but no idea which file it was
  /// reading, and `beak prepare`, `eject` and `doctor` all end up here, so it
  /// is translated once: 1-based, as an editor counts.
  static Object? _loadDocument(String yamlSource) {
    try {
      return loadYaml(yamlSource);
    } on YamlException catch (error) {
      throw BeakProjectConfigException(switch (error.span) {
        null => error.message,
        final span =>
          'line ${span.start.line + 1}, column ${span.start.column + 1}: '
              '${error.message}',
      });
    }
  }

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

  /// A port number, rejected by name when it is not one.
  static int? _optionalPort(Object? value, String path) {
    if (value == null) {
      return null;
    }
    if (value is int && value > 0 && value <= 65535) {
      return value;
    }
    throw BeakProjectConfigException(
      '$path must be a port number between 1 and 65535, got "$value".',
    );
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

  /// A Dart file path relative to the project root.
  ///
  /// Checked here because the path is used in three places that would each
  /// fail differently on a bad one: `flutter run -t`, the doctor's import
  /// walk, and the entrypoint `beak init` writes.
  static String? _optionalEntrypoint(Object? value, String key) {
    final String? path = _optionalString(value, key);
    if (path == null) {
      return null;
    }
    final bool isSafe =
        path.endsWith('.dart') &&
        !path.startsWith('/') &&
        !path.contains(r'\') &&
        !path.split('/').contains('..');
    if (!isSafe) {
      throw BeakProjectConfigException(
        '$key must be a Dart file path relative to the project, such as '
        '"lib/admin_main.dart" (got "$path").',
      );
    }
    return path;
  }

  /// An `OiIcons` identifier, checked as far as this package can check it.
  ///
  /// The value is spliced straight into `OiIcons.<name>` in generated Dart,
  /// and `beak_cli` is pure Dart so it cannot import obers_ui to confirm the
  /// name exists. It can insist on a lowerCamelCase identifier, which turns
  /// `icon: file-text` from a syntax error inside a generated file the header
  /// tells you not to edit into a named error about the line you wrote.
  static String? _optionalIcon(Object? value, String key) {
    final String? name = _optionalString(value, key);
    if (name == null) {
      return null;
    }
    if (!RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(name)) {
      throw BeakProjectConfigException(
        '$key must be a lowerCamelCase OiIcons name (got "$name").',
      );
    }
    return name;
  }

  /// The `agents.instructions` choice; `all` when it is not written.
  static BeakAgentInstructions _instructionsOf(Object? value) {
    final Object? raw = value is YamlNode ? value.value : value;
    if (raw == null) {
      return BeakAgentInstructions.all;
    }
    for (final choice in BeakAgentInstructions.values) {
      if (raw == choice.name) {
        return choice;
      }
    }
    throw BeakProjectConfigException(
      'agents.instructions must be one of: '
      '${BeakAgentInstructions.values.map((choice) => choice.name).join(', ')} '
      '(got "$raw").',
    );
  }

  /// The `agents.skills` targets, or `null` when the key is not written.
  static List<BeakSkillTarget>? _skillTargetsOf(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is! YamlList) {
      throw const BeakProjectConfigException(
        'agents.skills must be a list, such as [claude, agents].',
      );
    }
    final targets = <BeakSkillTarget>[];
    for (final entry in value) {
      final BeakSkillTarget? target = entry is String
          ? BeakSkillTarget.parse(entry)
          : null;
      if (target == null) {
        throw BeakProjectConfigException(
          'agents.skills has "$entry"; expected claude, agents or cursor.',
        );
      }
      if (!targets.contains(target)) {
        targets.add(target);
      }
    }
    return targets;
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

/// Problems in [config] that only the scan can see.
///
/// `beak.yaml` is written before the models exist and is keyed by table name,
/// so a typo — or a rename — leaves a block that silently applies to nothing.
/// The parser cannot catch that on its own; it needs the discovered tables.
///
/// ```dart
/// for (final issue in beakConfigIssues(config, discovery)) {
///   print('${issue.path}: ${issue.message}');
/// }
/// ```
List<BeakDiscoveryIssue> beakConfigIssues(
  BeakProjectConfig config,
  BeakDiscovery discovery,
) {
  final tables = <String>{
    for (final model in discovery.models)
      if (model.table case final String table) table,
  };
  if (tables.isEmpty) {
    // Nothing was discovered — a different problem, already reported.
    return const <BeakDiscoveryIssue>[];
  }
  return <BeakDiscoveryIssue>[
    for (final key in config.resources.keys)
      if (!tables.contains(key))
        BeakDiscoveryIssue(
          path: 'beak.yaml',
          message:
              'resources.$key names no discovered table'
              '${beakDidYouMean(key, tables)}.',
        ),
  ];
}

/// A ` — did you mean orders?` hint naming the table in [tables] closest to
/// [key], when one is close enough to be worth suggesting, and otherwise ''.
String beakDidYouMean(String key, Set<String> tables) {
  var best = '';
  var bestDistance = 1 << 30;
  for (final table in tables) {
    final distance = _editDistance(key, table);
    if (distance < bestDistance) {
      bestDistance = distance;
      best = table;
    }
  }
  // Beyond a third of the word the suggestion is noise, not help.
  return bestDistance <= key.length ~/ 3 + 1 ? ' — did you mean $best?' : '';
}

/// Levenshtein distance between [a] and [b].
int _editDistance(String a, String b) {
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = <int>[i, ...List<int>.filled(b.length, 0)];
    for (var j = 1; j <= b.length; j++) {
      final substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1);
      current[j] = [
        current[j - 1] + 1,
        previous[j] + 1,
        substitution,
      ].reduce((x, y) => x < y ? x : y);
    }
    previous = current;
  }
  return previous[b.length];
}
