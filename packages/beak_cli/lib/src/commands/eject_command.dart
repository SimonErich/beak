import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../cli_runner.dart';
import '../field_spec.dart';
import '../project/beak_discovery.dart';
import '../project/beak_emitters.dart';
import '../project/beak_project_config.dart';
import '../schema/beak_schema_reader.dart';
import '../templates.dart';
import 'prepare_command.dart';

/// Something a project can take ownership of.
///
/// Everything Beak generates has a default that stays invisible until it is
/// in the way. Ejecting writes the default out as a file the project owns, so
/// the first edit is a diff rather than a rewrite from the documentation.
enum BeakEjectTarget {
  /// `lib/main.dart` — an authored `BeakPanel(resources: [...])` in place of
  /// the generated entrypoint.
  main('main', 'lib/main.dart, composed by you instead of generated'),

  /// `lib/panel.dart` — the last word on the whole panel config.
  panel('panel', 'lib/panel.dart'),

  /// A `BeakResource` class for one model, without taking the whole panel.
  resource(
    'resource',
    'lib/resources/<table>/<name>_resource.dart (takes a table name)',
  ),

  /// `lib/theme.dart` — the light and dark themes.
  theme('theme', 'lib/theme.dart'),

  /// `lib/auth.dart` — which auth routes exist and what they call.
  auth('auth', 'lib/auth.dart'),

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
///
/// `beak eject resource <table>` writes a `BeakResource` class for one model,
/// which the generated panel then uses in place of that model's default.
/// `beak eject main` switches the project from the generated entrypoint to
/// an authored `BeakPanel(resources: [...])`.
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
      return _ejectResource(rest.last);
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
      return _ejectMain();
    }

    final BeakOverrideKind kind = target.override!;
    return _write('lib/${kind.path}', ejectedSource(kind));
  }

  /// Writes [source] to [path] unless it exists, and says what to do next.
  int _write(String path, String source) {
    if (_refusesToReplace(path)) {
      return 1;
    }
    environment.writeFile(path, source);
    environment.out
      ..writeln()
      ..writeln('  run `beak prepare` to wire it up');
    return 0;
  }

  /// Whether [path] exists and `--force` did not say to replace it, having
  /// said so.
  bool _refusesToReplace(String path) {
    final file = File('${environment.rootDirectory.path}/$path');
    if (file.existsSync() && argResults?['force'] != true) {
      environment.out.writeln(
        '  $path already exists — edit it, or pass --force to replace it',
      );
      return true;
    }
    return false;
  }

  /// Writes a `BeakResource` class for the model backing [table].
  ///
  /// The models come from the schema classes as well as from the scan, so a
  /// schema whose part file `beak prepare` has not written yet still counts.
  /// Nothing else about the project has to be healthy: this is the command
  /// the upgrade message for a removed `lib/resources/<table>.dart` override
  /// points at, and that override stops `beak prepare`.
  int _ejectResource(String table) {
    final Directory root = environment.rootDirectory;
    final (schemas, _) = BeakSchemaReader(root).read();
    final BeakDiscovery discovery = BeakProjectScanner(root).scan(
      tablesByModelClass: {
        for (final schema in schemas) schema.modelClass: schema.table,
      },
    );
    final models = <String, (String, String)>{
      for (final model in discovery.models)
        if (model.table case final String modelTable)
          modelTable: (model.name, model.importPath),
      for (final schema in schemas)
        schema.table: (schema.modelClass, schema.libraryPath),
    };
    final (String, String)? model = models[table];
    if (model == null) {
      environment.out.writeln(
        '  No model declares the table "$table"'
        '${beakDidYouMean(table, models.keys.toSet())}.',
      );
      return 1;
    }
    final (String modelClass, String modelPath) = model;
    for (final resource in discovery.resources) {
      if (resource.configures(modelClass)) {
        environment.out.writeln(
          '  $modelClass already has a resource class: '
          '${resource.className} in lib/${resource.importPath}. Edit that one.',
        );
        return 1;
      }
    }

    final BeakProjectConfig config = BeakProjectConfig.load(
      root,
      packageName: BeakProjectConfig.packageNameOf(root),
    );
    final BeakResourceOverride? presentation = config.resources[table];
    // The generated panel shows every resource class it finds, so taking
    // over a hidden one would put it in the sidebar, which is not the
    // no-visible-change this command promises.
    if (presentation?.hidden ?? false) {
      environment.out.writeln(
        '  "$table" has `hidden: true` under resources.$table in beak.yaml, '
        'so the panel does not show it, and a resource class is always '
        'shown. Remove `hidden: true` first to present it.',
      );
      return 1;
    }

    final String className = BeakDiscoveredResource.conventionalNameFor(
      modelClass,
    );
    final String stem = className.substring(
      0,
      className.length - 'Resource'.length,
    );
    final String folder = '${BeakProjectScanner.resourcesDir}/$table';
    final String path = 'lib/$folder/${snakeCaseOf(stem)}_resource.dart';
    if (_refusesToReplace(path)) {
      return 1;
    }
    final bool authored = isAuthoredEntrypoint(root);
    environment.writeFile(
      path,
      generateResourceClass(
        className: className,
        modelClass: modelClass,
        modelImport: p.posix.relative(modelPath, from: folder),
        table: table,
        icon: presentation?.icon,
        title: presentation?.label,
        navigationGroup: presentation?.section,
        authored: authored,
      ),
    );
    environment.out
      ..writeln()
      ..writeln('  run `beak prepare` to wire it up');
    if (authored) {
      environment.out.writeln(
        '  lib/main.dart is yours, so add $className() to its '
        '`resources: [...]`',
      );
    }
    return 0;
  }

  /// Switches the project to an authored `lib/main.dart`.
  ///
  /// Regenerates first, so the entrypoint lists what discovery sees now,
  /// then writes the `BeakPanel` the generated panel amounts to (see
  /// [BeakEmitters.authoredMain]) and un-ignores the file. An entrypoint the
  /// project already owns is never rewritten.
  int _ejectMain() {
    final Directory root = environment.rootDirectory;
    if (isAuthoredEntrypoint(root)) {
      environment.out.writeln('  lib/main.dart is already yours');
      _unignoreMain();
      return 0;
    }
    final BeakPrepareResult prepared = runPrepare(environment);
    if (!prepared.isSuccess) {
      environment.out.writeln('  lib/main.dart was left as it was');
      return prepared.exitCode;
    }
    final BeakDiscovery discovery = prepared.discovery;
    environment.writeFile(
      'lib/main.dart',
      BeakEmitters.authoredMain(
        config: BeakProjectConfig.load(
          root,
          packageName: BeakProjectConfig.packageNameOf(root),
        ),
        discovery: discovery,
      ),
    );
    _unignoreMain();
    environment.out
      ..writeln()
      ..writeln('  lib/main.dart is yours now: `beak prepare` leaves it alone.')
      ..writeln('  It lists every resource the generated panel showed, with')
      ..writeln('  the beak.yaml presentation written in. Add each resource')
      ..writeln('  class you write to its `resources: [...]`.');
    _warnUnmatched(discovery);
    return 0;
  }

  /// Names each resource class whose model neither its source nor its name
  /// reveals.
  ///
  /// The generated panel matches a class to a model by the table it reports
  /// at runtime. The authored entrypoint is written once, from the source,
  /// so such a class is listed beside every default, and if it presents one
  /// of those models the panel would show that model twice.
  void _warnUnmatched(BeakDiscovery discovery) {
    for (final resource in discovery.resources) {
      if (resource.modelClass != null ||
          discovery.models.any((model) => resource.configures(model.name))) {
        continue;
      }
      environment.out
        ..writeln()
        ..writeln(
          '  Could not tell which model ${resource.className} '
          '(lib/${resource.importPath}) presents. If lib/main.dart also',
        )
        ..writeln(
          '  lists a default BeakResource for that model, delete the '
          'default, or the panel shows the model twice.',
        );
    }
  }

  /// Stops `.gitignore` ignoring `lib/main.dart`, saying so when it did.
  void _unignoreMain() {
    final gitignore = File('${environment.rootDirectory.path}/.gitignore');
    if (!gitignore.existsSync()) {
      return;
    }
    final String source = gitignore.readAsStringSync();
    final String rewritten = withoutMainIgnore(source);
    if (rewritten != source) {
      gitignore.writeAsStringSync(rewritten);
      environment.out.writeln('  updated .gitignore');
    }
  }

  /// Whether [root] has a `lib/main.dart` that Beak did not generate.
  ///
  /// The same test `beak prepare` makes before rewriting an entrypoint: the
  /// generated one starts with the generated-by header.
  static bool isAuthoredEntrypoint(Directory root) {
    final main = File('${root.path}/lib/main.dart');
    return main.existsSync() &&
        !main.readAsStringSync().startsWith('// GENERATED BY');
  }

  /// [source] without the rule ignoring `lib/main.dart`.
  ///
  /// Drops the comment line pointing at `beak eject main` too, since it tells
  /// the reader to run this very command. The generated `bin/` entrypoints
  /// stay ignored: `beak prepare` still writes them.
  static String withoutMainIgnore(String source) {
    final kept = <String>[];
    for (final line in source.split('\n')) {
      final String trimmed = line.trim();
      if (trimmed == '/lib/main.dart' ||
          (trimmed.startsWith('#') && trimmed.contains('beak eject main'))) {
        continue;
      }
      // Removing a line can leave the blank lines around it adjacent;
      // collapsing them keeps the file looking hand-written.
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
    BeakOverrideKind.server => _server,
  };

  static const String _panel = '''
import 'package:beak/panel.dart';

/// The last word on this panel's configuration.
///
/// [defaults] is everything `beak.yaml`, the models, the resource classes and
/// `lib/screens/` produced. Return it to change nothing, or `copyWith` the
/// parts you want different: the resources list, the notification source.
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
/// The default adapter uses the server's generated `/api/auth/login`.
/// Supply a BeakAuthAdapter for another backend. Registration and password
/// recovery stay disabled unless both configured and supported by the adapter.
BeakAuthConfig beakAuth() => const BeakAuthConfig();
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
