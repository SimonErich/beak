import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../project/beak_project_config.dart';
import 'beak_block_renderer.dart';
import 'beak_workspace.dart';

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

  /// The message of a command run in a package that only holds schema
  /// classes, where there is no app to write agent files for.
  static const String modelsOnlyPackage =
      'models-only package (beak_core without an app): no Beak app here, '
      'nothing to do';

  /// The Beak packages that make a project more than its schema classes.
  static const Set<String> _appPackages = {
    'beak',
    'beak_frontend',
    'beak_backend',
    'beak_serverpod_flutter',
  };

  /// The kind of the project at [root], or `null` without a Beak app.
  ///
  /// In this order: a dependency on `beak_serverpod_flutter` together with the
  /// tunnel to a Serverpod server is a Serverpod admin (a client bridge app
  /// depends on the package for its sign-in screens alone, and is not one); a
  /// `panel.entrypoint` in `beak.yaml` other than `lib/main.dart` is
  /// an embedded panel; any other Beak dependency is a standalone app. A
  /// package that depends on `beak_core` alone has none of them: see
  /// [isModelsOnly].
  static BeakProjectKind? detect(
    Directory root, {
    required BeakProjectConfig config,
  }) {
    final Set<String> dependencies = dependenciesOf(root);
    if (dependencies.contains('beak_serverpod_flutter') &&
        _opensServerpodTunnel(root)) {
      return serverpodAdmin;
    }
    if (!dependencies.any(_isBeakPackage) || _isModelsOnly(dependencies)) {
      return null;
    }
    final String? entrypoint = config.panel.entrypoint;
    return entrypoint != null &&
            entrypoint != BeakPanelSettings.defaultEntrypoint
        ? embedded
        : standalone;
  }

  /// The word that marks the admin app's data source, which reaches Beak's
  /// API through the Serverpod endpoint.
  static const String _tunnelSymbol = 'serverpodBeakDataSource';

  /// The package that mounts Beak's API in a Serverpod server.
  static const String _tunnelServerPackage = 'beak_serverpod_server';

  /// Whether the app at [root] reaches a Serverpod server through the tunnel.
  ///
  /// True when a file under its `lib/` uses `serverpodBeakDataSource`, or a
  /// sibling package of its pub workspace depends on `beak_serverpod_server`,
  /// which is where the tunnel's other end lives.
  static bool _opensServerpodTunnel(Directory root) =>
      _usesTunnelDataSource(root) || _hasTunnelServerInWorkspace(root);

  static bool _usesTunnelDataSource(Directory root) {
    final lib = Directory(p.join(root.path, 'lib'));
    if (!lib.existsSync()) {
      return false;
    }
    return lib
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .any((file) => file.readAsStringSync().contains(_tunnelSymbol));
  }

  static bool _hasTunnelServerInWorkspace(Directory root) {
    final workspace = BeakWorkspace.locate(root);
    return workspace.memberDirectories
        .where((member) => !p.equals(member.path, root.path))
        .any((member) => dependenciesOf(member).contains(_tunnelServerPackage));
  }

  /// Whether the package at [root] only holds Beak schema classes.
  ///
  /// True when its pubspec depends on `beak_core` and on none of `beak`,
  /// `beak_frontend`, `beak_backend` and `beak_serverpod_flutter`. Such a
  /// package is pure Dart, shared by a server and an admin that live
  /// elsewhere, so `beak prepare` writes its schema parts and registry and
  /// nothing else, and `beak agents` has no app to describe.
  static bool isModelsOnly(Directory root) =>
      _isModelsOnly(dependenciesOf(root));

  static bool _isModelsOnly(Set<String> dependencies) =>
      dependencies.contains('beak_core') &&
      dependencies.intersection(_appPackages).isEmpty;

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
