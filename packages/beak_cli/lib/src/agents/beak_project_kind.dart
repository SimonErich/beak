import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../project/beak_project_config.dart';
import 'beak_block_renderer.dart';

/// What sort of Beak project a directory holds, which decides the rules its
/// `AGENTS.md` carries.
enum BeakProjectKind {
  /// A Beak admin panel over a Serverpod server.
  serverpodAdmin(BeakBlockKind.serverpodAdmin),

  /// Beak added to an existing Flutter app, booting from its own entrypoint.
  embedded(BeakBlockKind.embedded),

  /// A `beak create` app, on Beak's own server.
  standalone(BeakBlockKind.standalone);

  const BeakProjectKind(this.block);

  /// The managed block written for this kind of project.
  final BeakBlockKind block;

  /// The message of a command run where no Beak dependency is declared.
  static const String notABeakProject =
      'no Beak dependency here; run `beak init`';

  /// The kind of the project at [root], or `null` without a Beak dependency.
  ///
  /// In this order: a dependency on `beak_serverpod_flutter` is a Serverpod
  /// admin; a `panel.entrypoint` in `beak.yaml` other than `lib/main.dart` is
  /// an embedded panel; any other Beak dependency is a standalone app.
  static BeakProjectKind? detect(
    Directory root, {
    required BeakProjectConfig config,
  }) {
    final Set<String> dependencies = dependenciesOf(root);
    if (dependencies.contains('beak_serverpod_flutter')) {
      return serverpodAdmin;
    }
    if (!dependencies.any(_isBeakPackage)) {
      return null;
    }
    final String? entrypoint = config.panel.entrypoint;
    return entrypoint != null &&
            entrypoint != BeakPanelSettings.defaultEntrypoint
        ? embedded
        : standalone;
  }

  /// The names in the `dependencies` and `dev_dependencies` of the pubspec in
  /// [root]; empty when there is none, or it does not parse.
  static Set<String> dependenciesOf(Directory root) {
    final file = File(p.join(root.path, 'pubspec.yaml'));
    if (!file.existsSync()) {
      return const {};
    }
    try {
      if (loadYaml(file.readAsStringSync()) case final YamlMap pubspec) {
        return {
          for (final section in const ['dependencies', 'dev_dependencies'])
            if (pubspec[section] case final YamlMap packages)
              for (final name in packages.keys) '$name',
        };
      }
    } on YamlException {
      return const {};
    }
    return const {};
  }

  static bool _isBeakPackage(String name) =>
      name == 'beak' ||
      const {
        'beak_core',
        'beak_frontend',
        'beak_backend',
        'beak_serverpod',
        'beak_serverpod_flutter',
      }.contains(name);
}
