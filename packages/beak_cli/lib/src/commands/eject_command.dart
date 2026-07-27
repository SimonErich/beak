import 'dart:io';

import 'package:args/command_runner.dart';

import '../cli_runner.dart';
import '../project/beak_discovery.dart';

/// Something a project can take ownership of.
///
/// Everything Beak generates has a default that stays invisible until it is
/// in the way. Ejecting writes the default out as a file the project owns, so
/// the first edit is a diff rather than a rewrite from the documentation.
enum BeakEjectTarget {
  /// Commit the generated entrypoints instead of ignoring them.
  main('main', 'lib/main.dart, bin/serve.dart and bin/migrate.dart'),

  /// `lib/panel.dart` — the last word on the whole panel config.
  panel('panel', 'lib/panel.dart'),

  /// `lib/resources/<table>.dart` — one resource, without the whole panel.
  resource('resource', 'lib/resources/<table>.dart (takes a table name)'),

  /// `lib/theme.dart` — the light and dark themes.
  theme('theme', 'lib/theme.dart'),

  /// `lib/auth.dart` — which auth routes exist and what they call.
  auth('auth', 'lib/auth.dart'),

  /// `lib/dashboard.dart` — the screen mounted at `/`.
  dashboard('dashboard', 'lib/dashboard.dart'),

  /// `lib/server.dart` — middleware, extra routes, policy.
  server('server', 'lib/server.dart');

  const BeakEjectTarget(this.name, this.describes);

  /// The word typed after `beak eject`.
  final String name;

  /// What ejecting it produces, for the usage text.
  final String describes;

  /// The override this target materialises, or `null` for [main].
  BeakOverrideKind? get override => switch (this) {
    main || resource => null,
    panel => BeakOverrideKind.panel,
    theme => BeakOverrideKind.theme,
    auth => BeakOverrideKind.auth,
    dashboard => BeakOverrideKind.dashboard,
    server => BeakOverrideKind.server,
  };

  /// The target named [name], or `null` when none matches.
  static BeakEjectTarget? byName(String name) {
    for (final target in values) {
      if (target.name == name) {
        return target;
      }
    }
    return null;
  }
}

/// Takes ownership of something Beak generates.
///
/// ```console
/// $ beak eject theme
///   created lib/theme.dart
///   run `beak prepare` to wire it up
/// ```
final class EjectCommand extends Command<int> {
  /// Creates the command against [environment].
  EjectCommand(this.environment) {
    argParser.addFlag(
      'force',
      help: 'Overwrite the file if it already exists.',
      negatable: false,
    );
  }

  /// The injected seams.
  final BeakCliEnvironment environment;

  @override
  String get name => 'eject';

  @override
  String get description =>
      'Write a Beak default out as a file this project owns.';

  @override
  String get invocation =>
      'beak eject <${BeakEjectTarget.values.map((t) => t.name).join('|')}>';

  @override
  Future<int> run() async {
    final List<String> rest = argResults?.rest ?? const [];
    if (rest.isEmpty || rest.length > 2) {
      throw UsageException(
        'Expected a target.\n\n'
        '${[for (final target in BeakEjectTarget.values) '  ${target.name.padRight(10)} ${target.describes}'].join('\n')}',
        invocation,
      );
    }
    final BeakEjectTarget? target = BeakEjectTarget.byName(rest.first);
    if (target == null) {
      throw UsageException(
        '"${rest.first}" is not a Beak eject target.',
        invocation,
      );
    }

    if (target == BeakEjectTarget.resource) {
      if (rest.length != 2) {
        throw UsageException(
          'Which resource? Name the table, e.g. `beak eject resource orders`.',
          invocation,
        );
      }
      return _write(
        'lib/${BeakProjectScanner.resourcesDir}/${rest.last}.dart',
        resourceSource(rest.last),
      );
    }
    // Only `resource` takes an argument; a stray second word is a typo
    // worth naming rather than ignoring.
    if (rest.length == 2) {
      throw UsageException(
        '`beak eject ${target.name}` takes no arguments.',
        invocation,
      );
    }

    if (target == BeakEjectTarget.main) {
      return _ejectEntrypoints();
    }

    final BeakOverrideKind kind = target.override!;
    return _write('lib/${kind.path}', ejectedSource(kind));
  }

  /// Writes [source] to [path] unless it exists, and says what to do next.
  int _write(String path, String source) {
    final file = File('${environment.rootDirectory.path}/$path');
    if (file.existsSync() && argResults?['force'] != true) {
      environment.out.writeln(
        '  $path already exists — edit it, or pass --force to replace it',
      );
      return 1;
    }
    environment.writeFile(path, source);
    environment.out
      ..writeln()
      ..writeln('  run `beak prepare` to wire it up');
    return 0;
  }

  /// The starter override for the resource of [table].
  static String resourceSource(String table) =>
      '''
import 'package:beak/panel.dart';

/// Adjusts the generated resource for the `$table` table.
///
/// [generated] is what Beak derived from the model and `beak.yaml`. Return it
/// unchanged to change nothing, or `copyWith` the parts you want different —
/// filters, actions, view modes, the detail layout. Every other resource in
/// the panel stays generated.
BeakResource beakResource(BeakResource generated) => generated;
''';

  /// Un-ignores the generated entrypoints so the project commits them.
  int _ejectEntrypoints() {
    final gitignore = File('${environment.rootDirectory.path}/.gitignore');
    if (!gitignore.existsSync()) {
      environment.out.writeln(
        '  no .gitignore — the entrypoints are already committed',
      );
      return 0;
    }
    final String source = gitignore.readAsStringSync();
    final String rewritten = withoutEntrypointRules(source);
    if (rewritten == source) {
      environment.out.writeln('  the entrypoints are already committed');
      return 0;
    }
    gitignore.writeAsStringSync(rewritten);
    environment.out
      ..writeln('  updated .gitignore')
      ..writeln()
      ..writeln(
        '  lib/main.dart, bin/serve.dart and bin/migrate.dart are yours now. '
        '`beak prepare` still rewrites them, so edit them only if you mean to '
        'stop running it.',
      );
    return 0;
  }

  /// [source] with the generated-entrypoint block removed.
  ///
  /// Removes the paths and the comment that explains them, since the comment
  /// tells the reader to run this very command.
  static String withoutEntrypointRules(String source) {
    const ignored = {'/lib/main.dart', '/bin/serve.dart', '/bin/migrate.dart'};
    final kept = <String>[];
    var inBeakComment = false;
    for (final line in source.split('\n')) {
      final String trimmed = line.trim();
      if (ignored.contains(trimmed)) {
        inBeakComment = false;
        continue;
      }
      if (trimmed.startsWith('# Beak generates these')) {
        inBeakComment = true;
        continue;
      }
      if (inBeakComment && trimmed.startsWith('#')) {
        continue;
      }
      inBeakComment = false;
      // Removing a block leaves the blank lines that framed it; collapsing
      // them keeps the file looking hand-written, which it now is.
      if (trimmed.isEmpty && kept.isNotEmpty && kept.last.trim().isEmpty) {
        continue;
      }
      kept.add(line);
    }
    return kept.join('\n');
  }

  /// The starter file [kind] ejects to.
  ///
  /// Each one receives Beak's defaults and returns them unchanged, so it
  /// compiles and changes nothing until the first edit. That is the point:
  /// an override is a diff against a working default, never a blank file.
  static String ejectedSource(BeakOverrideKind kind) => switch (kind) {
    BeakOverrideKind.panel => _panel,
    BeakOverrideKind.theme => _theme,
    BeakOverrideKind.auth => _auth,
    BeakOverrideKind.dashboard => _dashboard,
    BeakOverrideKind.server => _server,
  };

  static const String _panel = '''
import 'package:beak/panel.dart';

/// The last word on this panel's configuration.
///
/// [defaults] is everything `beak.yaml`, `lib/models/` and `lib/screens/`
/// produced. Return it to change nothing, or `copyWith` the parts you want
/// different — the resources list, the dashboard, the notification source.
BeakPanelConfig beakPanel(BeakPanelConfig defaults) => defaults;
''';

  static const String _theme = '''
import 'package:beak/ui.dart';

/// The theme the panel uses in light mode.
OiThemeData beakLightTheme() => OiThemeData.light();

/// The theme the panel uses in dark mode.
OiThemeData beakDarkTheme() => OiThemeData.dark();
''';

  static const String _auth = '''
import 'package:beak/panel.dart';

/// Which auth routes the panel mounts, and what they call.
///
/// With no `onLogin`, the panel signs in against the generated
/// `/api/auth/login` and remembers the session, so a project whose
/// `lib/server.dart` configures auth needs nothing here. Supply one to
/// authenticate somewhere else.
BeakAuthConfig beakAuth() => const BeakAuthConfig();
''';

  static const String _dashboard = '''
import 'package:beak/panel.dart';
import 'package:beak/ui.dart';

/// The screen mounted at `/`, replacing the generated dashboard.
///
/// The body is a [BeakBlock] tree, not widgets: blocks compose the same way
/// the generated pages do, so a stat row or a chart drops straight in.
BeakScreen beakDashboard() => const BeakScreen(
  path: '/',
  title: 'Dashboard',
  icon: BeakIconToken(OiIcons.layoutDashboard),
  body: BeakCardBlock(child: BeakTextBlock('Your dashboard')),
);
''';

  static const String _server = '''
import 'package:beak/server.dart';

/// Builds the server from everything `BeakServeHost` resolved.
///
/// [defaults] carries the data source, the registry and the storage. Call
/// `build` for the standard server, passing a [BeakPolicy], extra middleware
/// or additional routes.
BeakServer beakServer(BeakServerDefaults defaults) => defaults.build();
''';
}
