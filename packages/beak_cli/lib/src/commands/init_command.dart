import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../cli_runner.dart';
import '../field_spec.dart';
import '../project/beak_authored_main.dart';
import '../project/beak_discovery.dart';
import '../project/beak_emitters.dart';
import '../project/beak_project_config.dart';
import '../templates.dart';
import '../version.dart';
import 'prepare_command.dart';

/// Brings the files a coding agent reads up to date after `beak init`.
///
/// Injected so `beak init` does not know how they are written: the agent
/// files are the concern of their own command, and this is the one place
/// `init` hands over to it.
typedef BeakAgentFilesRefresher =
    Future<void> Function(BeakCliEnvironment environment);

/// Adds Beak's admin panel to an existing Flutter app.
///
/// `beak create` starts a project where Beak owns the entrypoint. An app that
/// exists already cannot give up `lib/main.dart`, so `init` embeds the panel
/// next to it: a `beak` dependency, a `beak.yaml` that records where the
/// panel boots from, an authored entrypoint for it, and a `.gitignore` block
/// for what Beak generates. The app's own files are never rewritten, and the
/// panel starts with `flutter run -t <entrypoint>`.
///
/// Every step is idempotent and comment-preserving, so running it again
/// repairs whatever is missing and writes nothing else. It refuses what it
/// cannot do: a project that is not Flutter, and a Serverpod workspace, whose
/// admin belongs in the workspace.
///
/// ```console
/// $ cd my_app
/// $ beak init
///   updated pubspec.yaml (added the beak dependency)
///   created beak.yaml
///   created lib/admin_main.dart
///   created .gitignore
/// $ beak dev
/// $ flutter run -d chrome -t lib/admin_main.dart
/// ```
final class InitCommand extends Command<int> {
  /// Creates the command against [environment].
  ///
  /// [refreshAgentFiles] runs once at the end, after a successful `prepare`.
  InitCommand(this.environment, {BeakAgentFilesRefresher? refreshAgentFiles})
    : _refreshAgentFiles = refreshAgentFiles {
    argParser
      ..addOption(
        'entrypoint',
        help:
            'The Dart file, directly under lib/, that boots the panel. '
            'Defaults to lib/main.dart when the app has none of its own, '
            'and lib/admin_main.dart otherwise.',
        valueHelp: 'path',
      )
      ..addOption(
        'beak-ref',
        help: 'The git ref of Beak to depend on.',
        valueHelp: 'ref',
        defaultsTo: beakReleaseRef,
      )
      ..addOption(
        'beak-path',
        help:
            'Depend on a local Beak checkout at this path instead of git. '
            'Use it when developing Beak itself.',
        valueHelp: 'dir',
      )
      ..addFlag(
        'example',
        help: 'Also write a first schema class and resource, a Note.',
        negatable: false,
      )
      ..addFlag(
        'pub',
        help: 'Run `flutter pub get` and `beak prepare` afterwards.',
        defaultsTo: true,
      )
      ..addFlag(
        'dry-run',
        help: 'Report what would be written without writing it.',
        negatable: false,
      );
  }

  /// The injected seams.
  final BeakCliEnvironment environment;

  final BeakAgentFilesRefresher? _refreshAgentFiles;

  /// Opens the block of `.gitignore` that Beak owns.
  static const String gitignoreBegin = '# BEGIN beak';

  /// Closes the block of `.gitignore` that Beak owns.
  static const String gitignoreEnd = '# END beak';

  /// The default entrypoint of an app whose `lib/main.dart` is its own.
  static const String adminEntrypoint = 'lib/admin_main.dart';

  /// Where `--example` writes the schema class.
  static const String _noteSchemaPath = 'lib/resources/notes/models/note.dart';

  /// Where `--example` writes the resource class.
  static const String _noteResourcePath =
      'lib/resources/notes/note_resource.dart';

  /// A Dart file directly under `lib/`, the only place the entrypoint that
  /// `init` writes can import the app's files from by a short relative path.
  static final RegExp _entrypointShape = RegExp(r'^lib/[^/]+\.dart$');

  @override
  String get name => 'init';

  @override
  String get description =>
      'Add the Beak admin panel to an existing Flutter app.';

  @override
  String get invocation =>
      'beak init [--entrypoint <path>] [--beak-ref <ref> | --beak-path <dir>] '
      '[--example] [--[no-]pub] [--dry-run]';

  @override
  Future<int> run() async {
    if ((argResults?.rest ?? const []).isNotEmpty) {
      throw UsageException('beak init takes no arguments.', invocation);
    }
    final String? beakPath = switch (argResults?['beak-path']) {
      final String path => path,
      _ => null,
    };
    // A local checkout replaces the git dependency, so a ref would silently
    // mean nothing.
    if (beakPath != null && (argResults?.wasParsed('beak-ref') ?? false)) {
      throw UsageException(
        '--beak-ref pins the git dependency and --beak-path replaces it; '
        'pass one of them.',
        invocation,
      );
    }
    final String? requestedEntrypoint = switch (argResults?['entrypoint']) {
      final String path => path,
      _ => null,
    };
    if (requestedEntrypoint != null &&
        !_entrypointShape.hasMatch(requestedEntrypoint)) {
      throw UsageException(
        '--entrypoint must be a Dart file directly under lib/, such as '
        '$adminEntrypoint (got "$requestedEntrypoint").',
        invocation,
      );
    }

    final Directory root = environment.rootDirectory;
    final pubspecFile = File(p.join(root.path, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      environment.out.writeln(
        'There is no pubspec.yaml here. Run `beak init` in the root of your '
        'Flutter app.',
      );
      return 1;
    }
    final String pubspecSource = pubspecFile.readAsStringSync();
    final YamlMap? pubspec = _pubspecOf(pubspecSource);
    if (pubspec == null) {
      environment.out.writeln(
        'pubspec.yaml is not a valid pubspec: fix it, then run `beak init` '
        'again.',
      );
      return 1;
    }
    final YamlMap? dependencies = _dependenciesOf(pubspec);
    final Object? flutter = dependencies?['flutter'];
    if (flutter is! Map || flutter['sdk'] != 'flutter') {
      environment.out.writeln(
        'Flutter projects only: this pubspec.yaml has no `flutter: sdk: '
        'flutter` dependency, and `beak init` embeds a Flutter panel.',
      );
      return 1;
    }
    if (_belongsToServerpod(root, pubspec)) {
      environment.out
        ..writeln(
          'This project belongs to a Serverpod workspace. `beak init` does '
          'not embed Beak in it. Two other ways in:',
        )
        ..writeln(
          '  the admin app: add the admin app to your Serverpod workspace '
          '(see the Serverpod section of the docs)',
        )
        ..writeln(
          '  the client bridge: a panel over the endpoints you already have, '
          'wired by hand; see docs/serverpod/bridge/index.md',
        );
      return 1;
    }

    final String packageName = BeakProjectConfig.packageNameIn(pubspecSource);
    // Read before anything is written: a beak.yaml that cannot be understood
    // stops the command with nothing changed.
    final BeakProjectConfig config = BeakProjectConfig.load(
      root,
      packageName: packageName,
    );
    final String? configured = config.panel.entrypoint;
    if (configured != null &&
        requestedEntrypoint != null &&
        configured != requestedEntrypoint) {
      environment.out.writeln(
        'beak.yaml already sets panel.entrypoint to $configured; change it '
        'there rather than passing --entrypoint $requestedEntrypoint.',
      );
      return 1;
    }
    final String entrypoint =
        requestedEntrypoint ?? configured ?? _defaultEntrypoint(root);

    final bool dryRun = argResults?['dry-run'] == true;
    final bool alreadyDependsOnBeak =
        dependencies?.containsKey('beak') ?? false;
    if (alreadyDependsOnBeak) {
      environment.out.writeln(
        '  this project already depends on beak; repairing what is missing',
      );
    } else {
      _addDependency(
        pubspecFile,
        pubspecSource,
        beakPath: beakPath,
        beakRef: switch (argResults?['beak-ref']) {
          final String ref => ref,
          _ => beakReleaseRef,
        },
        dryRun: dryRun,
      );
    }
    _writeBeakYaml(
      packageName: packageName,
      entrypoint: entrypoint,
      config: config,
      dryRun: dryRun,
    );
    final bool example = argResults?['example'] == true;
    _writeEntrypoint(
      entrypoint,
      config: config,
      example: example,
      dryRun: dryRun,
    );
    if (example) {
      _writeExample(dryRun: dryRun);
    }
    _writeGitignore(dryRun: dryRun);
    _recommendStrictAnalysis();

    if (dryRun) {
      return 0;
    }
    if (argResults?['pub'] != true) {
      environment.out
        ..writeln()
        ..writeln('  next: run `flutter pub get`, then `beak prepare`');
      return 0;
    }
    return _finish(entrypoint);
  }

  /// Resolves packages, generates the wiring, and hands over to the agent
  /// files.
  Future<int> _finish(String entrypoint) async {
    final int pubExit = await environment.runInteractive('flutter', const [
      'pub',
      'get',
    ], workingDirectory: environment.rootDirectory.path);
    if (pubExit != 0) {
      environment.out.writeln(
        '  `flutter pub get` failed (exit $pubExit). Fix what it reports, '
        'then run `flutter pub get` and `beak prepare`.',
      );
    }
    final BeakPrepareResult prepared = runPrepare(environment);
    if (pubExit != 0 || !prepared.isSuccess) {
      return 1;
    }
    await _refreshAgentFiles?.call(environment);
    environment.out
      ..writeln()
      ..writeln('  next:')
      ..writeln('    beak make:resource Product --fields name:string!')
      ..writeln('    beak dev')
      ..writeln('    flutter run -d chrome -t $entrypoint');
    return 0;
  }

  /// The entrypoint for an app that names none: `lib/main.dart` while that
  /// file is absent or Beak's own, and a file beside it otherwise.
  static String _defaultEntrypoint(Directory root) {
    final main = File(p.join(root.path, BeakPanelSettings.defaultEntrypoint));
    final bool isFree =
        !main.existsSync() ||
        main.readAsStringSync().startsWith(BeakAuthoredMain.generatedMarker);
    return isFree ? BeakPanelSettings.defaultEntrypoint : adminEntrypoint;
  }

  /// Adds the `beak` dependency to the pubspec, leaving the rest of it as it
  /// was.
  void _addDependency(
    File pubspecFile,
    String source, {
    required String? beakPath,
    required String beakRef,
    required bool dryRun,
  }) {
    if (dryRun) {
      environment.out.writeln(
        '  would add the beak dependency to pubspec.yaml',
      );
      return;
    }
    final editor = YamlEditor(source)
      ..update(
        ['dependencies', 'beak'],
        beakPath != null
            ? {'path': '$beakPath/packages/beak'}
            : {
                'git': {
                  'url': 'https://github.com/SimonErich/beak.git',
                  'ref': beakRef,
                  'path': 'packages/beak',
                },
              },
      );
    pubspecFile.writeAsStringSync(editor.toString());
    environment.out.writeln(
      '  updated pubspec.yaml (added the beak dependency)',
    );
  }

  /// Writes `beak.yaml`, or adds the `panel` key to the one the app has.
  void _writeBeakYaml({
    required String packageName,
    required String entrypoint,
    required BeakProjectConfig config,
    required bool dryRun,
  }) {
    final file = File(p.join(environment.rootDirectory.path, 'beak.yaml'));
    if (!file.existsSync()) {
      _create('beak.yaml', _beakYaml(packageName, entrypoint), dryRun: dryRun);
      return;
    }
    if (config.panel.entrypoint != null) {
      return;
    }
    final String current = file.readAsStringSync();
    _update(
      'beak.yaml',
      loadYaml(current) is YamlMap
          ? (YamlEditor(
              current,
            )..update(['panel'], {'entrypoint': entrypoint})).toString()
          // An empty file, or one that is only comments, has no mapping to
          // edit: the key goes after what is there.
          : '$current${current.isEmpty || current.endsWith('\n') ? '' : '\n'}'
                'panel:\n  entrypoint: $entrypoint\n',
      dryRun: dryRun,
    );
  }

  /// Writes the authored entrypoint, unless the app already has that file.
  void _writeEntrypoint(
    String entrypoint, {
    required BeakProjectConfig config,
    required bool example,
    required bool dryRun,
  }) {
    final file = File(p.join(environment.rootDirectory.path, entrypoint));
    final bool isBeaks =
        file.existsSync() &&
        file.readAsStringSync().startsWith(BeakAuthoredMain.generatedMarker);
    if (file.existsSync() && !isBeaks) {
      environment.out.writeln('  $entrypoint already exists; left as it was');
      return;
    }
    if (!_entrypointShape.hasMatch(entrypoint)) {
      environment.out.writeln(
        '  ! $entrypoint does not exist and is not directly under lib/, so '
        '`beak init` cannot write it; create it yourself',
      );
      return;
    }
    final String source = BeakEmitters.authoredMain(
      config: config,
      discovery: example ? _exampleDiscovery : const BeakDiscovery(),
    );
    if (isBeaks) {
      _update(entrypoint, source, dryRun: dryRun);
    } else {
      _create(entrypoint, source, dryRun: dryRun);
    }
  }

  /// What the panel lists when `--example` wrote a Note.
  static const BeakDiscovery _exampleDiscovery = BeakDiscovery(
    models: [
      BeakDiscoveredSymbol(
        name: 'NoteModel',
        importPath: 'resources/notes/models/note.dart',
        isConstructible: true,
        table: 'notes',
      ),
    ],
    resources: [
      BeakDiscoveredResource(
        className: 'NoteResource',
        importPath: 'resources/notes/note_resource.dart',
        isConst: true,
        modelClass: 'NoteModel',
      ),
    ],
  );

  /// Writes a first schema class and its resource, each unless it is there.
  void _writeExample({required bool dryRun}) {
    final files = {
      _noteSchemaPath: generateSchemaClass(
        'Note',
        BeakFieldSpec.parseList('title:string!,body:text,pinned:bool'),
      ),
      _noteResourcePath: generateResourceClass(
        className: 'NoteResource',
        modelClass: 'NoteModel',
        modelImport: 'models/note.dart',
        table: 'notes',
        icon: 'fileText',
        authored: true,
      ),
    };
    for (final MapEntry(key: path, value: source) in files.entries) {
      if (File(p.join(environment.rootDirectory.path, path)).existsSync()) {
        environment.out.writeln('  $path already exists; left as it was');
      } else {
        _create(path, source, dryRun: dryRun);
      }
    }
  }

  /// Inserts the block of ignores for what Beak generates, once.
  void _writeGitignore({required bool dryRun}) {
    final file = File(p.join(environment.rootDirectory.path, '.gitignore'));
    if (!file.existsSync()) {
      _create('.gitignore', _gitignoreBlock, dryRun: dryRun);
      return;
    }
    final String current = file.readAsStringSync();
    if (current.contains(gitignoreBegin)) {
      return;
    }
    _update(
      '.gitignore',
      '$current${current.isEmpty || current.endsWith('\n') ? '' : '\n'}'
          '${current.isEmpty ? '' : '\n'}$_gitignoreBlock',
      dryRun: dryRun,
    );
  }

  /// Prints the analyzer flags Beak's files are written for, if the app does
  /// not set them.
  ///
  /// `analysis_options.yaml` is the app's; tightening it would change what the
  /// app's own code reports.
  void _recommendStrictAnalysis() {
    final file = File(
      p.join(environment.rootDirectory.path, 'analysis_options.yaml'),
    );
    final String current = file.existsSync() ? file.readAsStringSync() : '';
    const flags = ['strict-casts', 'strict-inference', 'strict-raw-types'];
    if (flags.every(current.contains)) {
      return;
    }
    environment.out
      ..writeln(
        '  analysis_options.yaml is yours, so Beak leaves it alone. Its files '
        'are written for these flags:',
      )
      ..writeln('    analyzer:')
      ..writeln('      language:');
    for (final flag in flags) {
      environment.out.writeln('        $flag: true');
    }
  }

  void _create(String path, String source, {required bool dryRun}) {
    if (dryRun) {
      environment.out.writeln('  would create $path');
    } else {
      environment.writeFile(path, source);
    }
  }

  void _update(String path, String source, {required bool dryRun}) {
    if (dryRun) {
      environment.out.writeln('  would update $path');
      return;
    }
    File(
      p.join(environment.rootDirectory.path, path),
    ).writeAsStringSync(source);
    environment.out.writeln('  updated $path');
  }

  /// The contents of a new `beak.yaml`.
  static String _beakYaml(String packageName, String entrypoint) =>
      '''
# Beak project configuration. Every key is optional: delete this file and
# Beak still boots, titling the panel after the package.
name: ${BeakProjectConfig.titleCase(packageName)}

api:
  # The origin the panel calls. Use `auto` to call the origin the panel was
  # served from, which is what a single-host deployment wants.
  baseUrl: ${BeakApiSettings.defaultBaseUrl}

panel:
  # This app keeps its own lib/main.dart, so `beak prepare` never writes it.
  # The panel boots from this file instead: flutter run -t $entrypoint
  entrypoint: $entrypoint
''';

  static const String _gitignoreBlock =
      '''
$gitignoreBegin
# Written by `beak prepare`, plus the local database, uploads and secrets.
/bin/serve.dart
/bin/migrate.dart
/*.db*
/storage/
.env
$gitignoreEnd
''';

  /// [source] as a pubspec, or `null` when it is not a mapping.
  static YamlMap? _pubspecOf(String source) {
    try {
      return switch (loadYaml(source)) {
        final YamlMap map => map,
        _ => null,
      };
    } on YamlException {
      return null;
    }
  }

  /// The `dependencies` of [pubspec], when it declares a mapping of them.
  static YamlMap? _dependenciesOf(YamlMap pubspec) =>
      switch (pubspec['dependencies']) {
        final YamlMap map => map,
        _ => null,
      };

  /// Whether the project at [root] is part of a Serverpod workspace.
  ///
  /// It is when it depends on Serverpod itself, when a member of its own
  /// `workspace:` does, or when it is a member of a workspace above it that
  /// does. Only pubspecs are read: this decides whether Beak may embed
  /// itself, not how the workspace is laid out.
  static bool _belongsToServerpod(Directory root, YamlMap pubspec) {
    if (_dependsOnServerpod(pubspec) || _membersUseServerpod(root, pubspec)) {
      return true;
    }
    if (pubspec['resolution'] != 'workspace') {
      return false;
    }
    for (
      Directory parent = root.parent;
      parent.path != parent.parent.path;
      parent = parent.parent
    ) {
      final YamlMap? above = _pubspecIn(parent);
      if (above != null && above['workspace'] != null) {
        return _dependsOnServerpod(above) ||
            _membersUseServerpod(parent, above);
      }
    }
    return false;
  }

  /// Whether a member of the workspace [pubspec] declares in [root] depends on
  /// Serverpod. A member that is missing or unreadable is skipped.
  static bool _membersUseServerpod(Directory root, YamlMap pubspec) {
    final Object? members = pubspec['workspace'];
    if (members is! List) {
      return false;
    }
    for (final member in members) {
      final YamlMap? memberPubspec = _pubspecIn(
        Directory(p.join(root.path, '$member')),
      );
      if (memberPubspec != null && _dependsOnServerpod(memberPubspec)) {
        return true;
      }
    }
    return false;
  }

  /// The pubspec in [directory], or `null` when it has none that parses.
  static YamlMap? _pubspecIn(Directory directory) {
    final file = File(p.join(directory.path, 'pubspec.yaml'));
    return file.existsSync() ? _pubspecOf(file.readAsStringSync()) : null;
  }

  /// Whether [pubspec] depends on `serverpod` or one of its packages.
  static bool _dependsOnServerpod(YamlMap pubspec) {
    for (final section in const ['dependencies', 'dev_dependencies']) {
      if (pubspec[section] case final YamlMap packages) {
        if (packages.keys.any(
          (name) => '$name' == 'serverpod' || '$name'.startsWith('serverpod_'),
        )) {
          return true;
        }
      }
    }
    return false;
  }
}
