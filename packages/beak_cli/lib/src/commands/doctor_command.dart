import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import '../agents/beak_agent_files.dart';
import '../agents/beak_claude_md.dart';
import '../agents/beak_docs_bundle.dart';
import '../agents/beak_package_config.dart';
import '../agents/beak_project_kind.dart';
import '../agents/beak_skill_installer.dart';
import '../agents/beak_workspace.dart';
import '../cli_runner.dart';
import '../introspect/beak_live_schema.dart';
import '../introspect/beak_schema_introspection.dart';
import '../project/beak_authored_main.dart';
import '../project/beak_discovery.dart';
import '../project/beak_emitters.dart';
import '../project/beak_project_config.dart';
import '../schema/beak_migration_emitter.dart';
import '../schema/beak_migration_order.dart';
import '../schema/beak_schema_drift.dart';
import '../schema/beak_schema_emitter.dart';
import '../schema/beak_schema_ir.dart';
import '../schema/beak_schema_reader.dart';
import '../version.dart';
import 'prepare_command.dart';

/// How a single check came out.
enum BeakCheckStatus {
  /// Everything is as it should be.
  ok,

  /// Worth knowing, but not blocking.
  warn,

  /// Broken; the project will not work until it is fixed.
  fail,
}

/// One diagnostic, with the fix when there is one.
final class BeakCheck {
  /// Creates a check result.
  const BeakCheck({
    required this.status,
    required this.label,
    this.remedy,
    this.group,
  });

  /// Whether it passed.
  final BeakCheckStatus status;

  /// What was checked, and what was found.
  final String label;

  /// The command or edit that fixes it, when a fix exists.
  final String? remedy;

  /// The family of checks this belongs to, such as `agents`, or `null` for
  /// the project checks.
  final String? group;

  /// This check as JSON, for `beak doctor --json`.
  Map<String, Object?> toJson() => {
    'status': status.name,
    'label': label,
    if (remedy case final String remedy) 'remedy': remedy,
    if (group case final String group) 'group': group,
  };
}

/// Diagnoses a Beak project.
///
/// The previous `doctor` checked this repository's own layout — a vendored
/// `packages/worm`, a sibling `obers_ui`, and the demo stack's ports — so in a
/// user's generated project it printed four failures and exited 1, always.
/// This one checks the project it is actually run in.
final class DoctorCommand extends Command<int> {
  /// Creates the command bound to [environment].
  ///
  /// [readSchema] is the seam the drift check reads the live schema through;
  /// tests pass their own so the check runs without a database.
  DoctorCommand(this.environment, {BeakLiveSchemaReader? readSchema})
    : _readSchema = readSchema ?? beakReadLiveSchema {
    argParser.addFlag(
      'json',
      help: 'Report as JSON, for CI.',
      negatable: false,
    );
  }

  /// The seams this command runs against.
  final BeakCliEnvironment environment;

  /// How the drift check reads the live schema.
  final BeakLiveSchemaReader _readSchema;

  @override
  String get name => 'doctor';

  @override
  String get description => 'Diagnose this Beak project.';

  @override
  Future<int> run() async {
    final checks = await diagnose(environment, readSchema: _readSchema);
    final bool healthy = checks.every(
      (check) => check.status != BeakCheckStatus.fail,
    );
    if (argResults?['json'] == true) {
      environment.out.writeln(
        const JsonEncoder.withIndent('  ').convert({
          'healthy': healthy,
          'checks': [for (final check in checks) check.toJson()],
        }),
      );
      return healthy ? 0 : 1;
    }
    for (final check in checks) {
      final String badge = switch (check.status) {
        BeakCheckStatus.ok => 'OK  ',
        BeakCheckStatus.warn => 'WARN',
        BeakCheckStatus.fail => 'FAIL',
      };
      environment.out.writeln('  $badge ${check.label}');
      if (check.remedy case final String remedy) {
        environment.out.writeln('       → $remedy');
      }
    }
    environment.out.writeln(
      healthy ? 'All checks passed.' : 'Some checks failed.',
    );
    return healthy ? 0 : 1;
  }
}

/// Runs every diagnostic against [environment], in report order.
///
/// Exposed separately from the command so the checks can be asserted on
/// directly, and so other commands can reuse them. [readSchema] reads the
/// live schema for the drift check, and defaults to a real connection.
Future<List<BeakCheck>> diagnose(
  BeakCliEnvironment environment, {
  BeakLiveSchemaReader readSchema = beakReadLiveSchema,
}) async {
  final checks = <BeakCheck>[];
  final Directory root = environment.rootDirectory;
  final pubspec = File('${root.path}/pubspec.yaml');

  if (!pubspec.existsSync()) {
    return [
      const BeakCheck(
        status: BeakCheckStatus.fail,
        label: 'no pubspec.yaml: this is not a Dart project',
        remedy: 'run `beak create <name>` to scaffold one',
      ),
    ];
  }

  if (BeakProjectKind.isModelsOnly(root)) {
    return _diagnoseModelsOnly(root);
  }

  final String pubspecSource = pubspec.readAsStringSync();
  // The umbrella is the supported dependency, but a project that predates it
  // — or that deliberately depends on the parts — is not broken, so accept
  // either rather than telling a working project it is wrong.
  final bool dependsOnBeak = RegExp(
    r'^\s{2}beak(_core|_frontend|_backend)?\s*:',
    multiLine: true,
  ).hasMatch(pubspecSource);
  checks.add(
    BeakCheck(
      status: dependsOnBeak ? BeakCheckStatus.ok : BeakCheckStatus.fail,
      label: dependsOnBeak
          ? 'project depends on Beak'
          : 'project does not depend on beak',
      remedy: dependsOnBeak ? null : 'add beak to pubspec.yaml',
    ),
  );

  // beak.yaml is optional, but a malformed one stops generation dead.
  final String packageName = BeakProjectConfig.packageNameIn(pubspecSource);
  final BeakProjectConfig config;
  try {
    config = BeakProjectConfig.load(root, packageName: packageName);
    checks.add(
      const BeakCheck(status: BeakCheckStatus.ok, label: 'beak.yaml parses'),
    );
  } on BeakProjectConfigException catch (exception) {
    checks.add(
      BeakCheck(
        status: BeakCheckStatus.fail,
        label: 'beak.yaml: ${exception.message}',
        remedy: 'fix the key, or delete beak.yaml to use defaults',
      ),
    );
    return checks;
  }

  final BeakDiscovery discovery = BeakProjectScanner(root).scan();
  // Discovery's own issues, plus the ones only `beak.yaml` and discovery
  // together can see: a `resources:` key naming no table. `prepare` refuses
  // to generate on those, so a doctor that stayed quiet about them reported
  // a healthy project that could not be generated.
  for (final issue in [
    ...discovery.issues,
    ...beakConfigIssues(config, discovery),
  ]) {
    checks.add(
      BeakCheck(
        status: BeakCheckStatus.fail,
        label: '${issue.path}: ${issue.message}',
      ),
    );
  }
  checks.add(
    BeakCheck(
      status: discovery.models.isEmpty
          ? BeakCheckStatus.warn
          : BeakCheckStatus.ok,
      label: discovery.models.isEmpty
          ? 'no models found under lib/'
          : 'discovered ${beakDiscoverySummary(discovery, root, config)}',
      remedy: discovery.models.isEmpty
          ? 'run `beak make:resource <Name>`, which writes a schema class '
                'under lib/resources/<plural>/models/'
          : null,
    ),
  );

  checks.addAll(_authoredResourceChecks(root, discovery, config));

  // Read once: the staleness check, the migration check and the drift check
  // all ask the same question of the same files, and parsing them three
  // times is parsing them three times.
  final (schemas, schemaIssues) = BeakSchemaReader(root).readChecked();
  // `prepare` refuses to generate on these, so a project that has one is not
  // healthy, and a doctor that stayed quiet about it said "All checks passed"
  // to a project that could not be generated.
  final reported = {for (final check in checks) check.label};
  for (final issue in schemaIssues) {
    final String label = '${issue.path}: ${issue.message}';
    if (reported.add(label)) {
      checks.add(BeakCheck(status: BeakCheckStatus.fail, label: label));
    }
  }
  checks.addAll(_migrationImportChecks(root, packageName));

  // Stale generated files are the one failure mode the hidden-entrypoint
  // design introduces, so name it explicitly rather than letting it surface
  // as a confusing compile error.
  final expected = <String, String>{};
  if (discovery.issues.isEmpty) {
    // The host registers migrations in the order `prepare` gave them, which
    // is not always the order of their names.
    final BeakDiscovery ordered = schemaIssues.isEmpty
        ? BeakMigrationOrder.orderedIn(
            discovery,
            tablesReferencedBy: BeakSchemaEmitter.foreignKeyTargets(schemas),
          )
        : discovery;
    for (final generated in beakGeneratedFiles(
      root: root,
      packageName: packageName,
      config: config,
      discovery: ordered,
    )) {
      final file = File('${root.path}/${generated.path}');
      if (!generated.isCommitted &&
          file.existsSync() &&
          !file.readAsStringSync().startsWith('// GENERATED BY')) {
        continue;
      }
      expected[generated.path] = generated.contents;
    }
    // The part files too. They are not in `BeakEmitters.all` — the schema
    // emitter writes them a step earlier, before discovery can see the
    // models they declare — and leaving them out gave `doctor` a blind spot
    // wide enough for `examples/quickstart` to sit 18 lines behind the
    // emitter while reporting "generated files up to date".
    if (schemaIssues.isEmpty) {
      for (final schema in schemas) {
        expected[BeakSchemaEmitter.partPathOf(schema)] = BeakSchemaEmitter.emit(
          schema,
          schemas,
        );
      }
    }
  }
  checks.add(_generatedFilesCheck(root, expected));
  checks.addAll(_leftoverWiringChecks(root, config));

  checks.add(_migrationCoverageCheck(discovery, schemas, schemaIssues));
  checks.add(_webScaffoldCheck(root));
  checks.addAll(
    serverImportChecks(
      root,
      packageName: packageName,
      entrypoint: config.panel.entrypoint,
    ),
  );
  checks.addAll(
    await _databaseChecks(
      environment,
      root,
      readSchema,
      schemas,
      schemaIssues,
      createdTables: discovery.migratedTables,
    ),
  );
  checks.addAll(agentChecks(root, config: config));
  return checks;
}

/// Whether every file in [expected], project-relative path to text, exists
/// under [root] with exactly that text.
BeakCheck _generatedFilesCheck(Directory root, Map<String, String> expected) {
  var missing = 0;
  var stale = 0;
  for (final MapEntry(key: path, value: contents) in expected.entries) {
    final file = File('${root.path}/$path');
    if (!file.existsSync()) {
      missing++;
    } else if (file.readAsStringSync() != contents) {
      stale++;
    }
  }
  if (missing == 0 && stale == 0) {
    return const BeakCheck(
      status: BeakCheckStatus.ok,
      label: 'generated files up to date',
    );
  }
  return BeakCheck(
    status: BeakCheckStatus.fail,
    label: 'generated files out of date ($missing missing, $stale stale)',
    remedy: 'beak prepare',
  );
}

/// A warning for panel wiring that an earlier generated entrypoint left behind.
///
/// Once the entrypoint is the project's own, `beak prepare` stops writing the
/// panel config and the app widget, and would delete the ones on disk. Until
/// it runs they are files nobody imports that still have to compile.
List<BeakCheck> _leftoverWiringChecks(
  Directory root,
  BeakProjectConfig config,
) {
  if (beakPanelWiringIsUsed(root, config)) {
    return const [];
  }
  final List<String> leftover = beakLeftoverPanelWiring(root);
  if (leftover.isEmpty) {
    return const [];
  }
  return [
    BeakCheck(
      status: BeakCheckStatus.warn,
      label:
          '${leftover.join(', ')} ${leftover.length == 1 ? 'is' : 'are'} '
          'left over from a generated entrypoint, and nothing imports '
          '${leftover.length == 1 ? 'it' : 'them'}',
      remedy: 'beak prepare',
    ),
  ];
}

/// The diagnosis of a package that only holds schema classes.
///
/// It asks what applies there and nothing else: the schema classes read
/// cleanly, the generated parts and registry are current, and no file reaches
/// the server, the panel or Flutter, because the package is shared by a
/// server and an admin. There is no panel, entrypoint, `beak.yaml`, migration,
/// database or agent file to be missing.
List<BeakCheck> _diagnoseModelsOnly(Directory root) {
  final (schemas, schemaIssues) = BeakSchemaReader(root).readChecked();
  final BeakDiscovery discovery = BeakProjectScanner(root).scanModels(
    tablesByModelClass: {
      for (final schema in schemas) schema.modelClass: schema.table,
    },
  );
  final issues = <BeakDiscoveryIssue>[...schemaIssues, ...discovery.issues];
  final checks = <BeakCheck>[
    const BeakCheck(
      status: BeakCheckStatus.ok,
      label: 'models-only package: depends on beak_core, no app',
    ),
    BeakCheck(
      status: discovery.models.isEmpty
          ? BeakCheckStatus.warn
          : BeakCheckStatus.ok,
      label: discovery.models.isEmpty
          ? 'no models found under lib/'
          : 'discovered ${discovery.models.length} '
                '${discovery.models.length == 1 ? 'model' : 'models'}',
      remedy: discovery.models.isEmpty
          ? 'write a schema class annotated with @Resource under lib/'
          : null,
    ),
    for (final issue in issues)
      BeakCheck(
        status: BeakCheckStatus.fail,
        label: '${issue.path}: ${issue.message}',
      ),
  ];
  if (issues.isEmpty) {
    checks
      ..add(
        const BeakCheck(
          status: BeakCheckStatus.ok,
          label: 'schema classes read cleanly',
        ),
      )
      ..add(
        _generatedFilesCheck(root, {
          for (final generated in BeakEmitters.modelsOnly(discovery))
            generated.path: generated.contents,
          for (final schema in schemas)
            BeakSchemaEmitter.partPathOf(schema): BeakSchemaEmitter.emit(
              schema,
              schemas,
            ),
        }),
      );
  } else {
    checks.add(
      const BeakCheck(
        status: BeakCheckStatus.ok,
        label: 'generated files not checked: fix the schema issues first',
      ),
    );
  }
  checks.addAll(_modelsOnlyImportChecks(root));
  return checks;
}

/// Prefixes of the libraries a package of schema classes must not import: the
/// app, the server, the panel and Flutter, none of which its consumers all
/// share.
const List<String> _appLibraryPrefixes = [
  'package:beak/',
  'package:beak_frontend/',
  'package:beak_backend/',
  'package:flutter/',
];

/// A check for each import in a models-only package that reaches the app.
///
/// The package is pure Dart, shared by a server and a web admin, so an import
/// of the panel, the server, Flutter or `dart:io` breaks one of them:
/// `dart:io` compiles on the web and only fails when it runs.
List<BeakCheck> _modelsOnlyImportChecks(Directory root) {
  final lib = Directory('${root.path}/lib');
  final offenders = <(String, String)>[];
  if (lib.existsSync()) {
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final String relative = p.posix.joinAll(
        p.split(p.relative(entity.path, from: root.path)),
      );
      for (final uri in _referencedUrisIn(entity.readAsStringSync())) {
        if (uri == 'dart:io' ||
            _appLibraryPrefixes.any((prefix) => uri.startsWith(prefix))) {
          offenders.add((relative, uri));
        }
      }
    }
  }
  if (offenders.isEmpty) {
    return const [
      BeakCheck(
        status: BeakCheckStatus.ok,
        label: 'no file imports the server, the panel or Flutter',
      ),
    ];
  }
  offenders.sort(
    (a, b) => a.$1 == b.$1 ? a.$2.compareTo(b.$2) : a.$1.compareTo(b.$1),
  );
  return [
    for (final (path, uri) in offenders)
      BeakCheck(
        status: BeakCheckStatus.fail,
        label:
            '$path imports $uri, which a models-only package shared by a '
            'server and an admin must not reach',
        remedy: 'move that code to the app that uses these models',
      ),
  ];
}

/// A warning for each resource class the authored entrypoint does not list.
///
/// The entrypoint is `lib/main.dart`, or the file `panel.entrypoint` names in
/// an app that embeds the panel. `beak prepare` never rewrites an entrypoint
/// the project owns, so a new `BeakResource` subclass reaches the panel only
/// once someone adds it to the `resources: [...]` list there, and forgetting
/// is silent: the class compiles, the resource simply never appears. A
/// generated entrypoint is wired by `beak prepare`, and one whose list cannot
/// be read statically (a variable, a spread of one) is not second-guessed.
List<BeakCheck> _authoredResourceChecks(
  Directory root,
  BeakDiscovery discovery,
  BeakProjectConfig config,
) {
  final String entrypoint = config.panel.entrypointPath;
  final file = File('${root.path}/$entrypoint');
  final String? source = file.existsSync() ? file.readAsStringSync() : null;
  final Set<String>? listed =
      source == null || source.startsWith(BeakAuthoredMain.generatedMarker)
      ? null
      : BeakAuthoredMain.parse(source).listedResources;
  if (listed == null || discovery.resources.isEmpty) {
    return const [];
  }
  final unlisted = [
    for (final resource in discovery.resources)
      if (!listed.contains(resource.className)) resource,
  ];
  if (unlisted.isEmpty) {
    return [
      BeakCheck(
        status: BeakCheckStatus.ok,
        label: '$entrypoint lists every resource class',
      ),
    ];
  }
  return [
    for (final resource in unlisted)
      BeakCheck(
        status: BeakCheckStatus.warn,
        label:
            '${resource.className} (lib/${resource.importPath}) is not listed '
            "in $entrypoint's resources: [...], so the panel never shows it",
        remedy:
            'add ${resource.className}() to the resources list in '
            '$entrypoint; `beak prepare` never rewrites an authored '
            'entrypoint',
      ),
  ];
}

/// Whether every model Beak owns has a migration that creates its table.
///
/// A model with no table is a resource whose every endpoint fails, and the
/// failure surfaces as a database error at request time rather than as
/// anything a project could act on. Computed from the same emitter
/// `beak prepare` writes with, so the check and the generator cannot report
/// different things.
BeakCheck _migrationCoverageCheck(
  BeakDiscovery discovery,
  List<BeakSchemaIr> schemas,
  List<BeakDiscoveryIssue> schemaIssues,
) {
  if (schemaIssues.isNotEmpty) {
    // A schema that does not parse is already a failure of its own.
    return const BeakCheck(
      status: BeakCheckStatus.ok,
      label: 'migration coverage not checked: fix the schema issues first',
    );
  }
  final missing = BeakMigrationEmitter.missing(
    models: discovery.models,
    schemas: schemas,
    coveredTables: discovery.migratedTables,
    now: DateTime.utc(2026),
  );
  if (missing.isEmpty) {
    return const BeakCheck(
      status: BeakCheckStatus.ok,
      label: 'every model has a migration',
    );
  }
  return BeakCheck(
    status: BeakCheckStatus.fail,
    label:
        'no migration creates '
        '${missing.map((file) => file.table).join(', ')}',
    remedy: 'beak prepare',
  );
}

/// Whether Flutter's `web/` scaffold exists.
///
/// `beak create` delegates it to `flutter create`, which can fail — offline,
/// or behind a proxy — leaving a project that runs everywhere but the web.
BeakCheck _webScaffoldCheck(Directory root) {
  final bool present = File('${root.path}/web/index.html').existsSync();
  return BeakCheck(
    status: present ? BeakCheckStatus.ok : BeakCheckStatus.warn,
    label: present ? 'web/ scaffold present' : 'no web/ scaffold',
    remedy: present ? null : 'flutter create --platforms=web .',
  );
}

/// Libraries that cannot run in a browser, because they reach `dart:io` and a
/// database driver.
const Set<String> _serverLibraries = {
  'package:beak/server.dart',
  'package:beak/migrations.dart',
};

/// Panel files that reach the server, one check each.
///
/// This is the failure the library split exists to prevent: the panel runs in
/// a browser and the server half imports `dart:io` and a database driver, so
/// one such import compiles fine and then fails at runtime — or takes the
/// server's ahead-of-time build down with it when the file is also reachable
/// from `bin/serve.dart`.
///
/// Only files the panel actually reaches are checked. Membership is the
/// import graph, not the path: a project may keep server-side code anywhere
/// under `lib/` — an authored `lib/database_setup.dart` may
/// migrate the host system's own table and is imported by `bin/host.dart`
/// alone — and a path allowlist called that a failure while missing the real
/// one, a server import in a file the panel does import.
List<BeakCheck> serverImportChecks(
  Directory root, {
  required String packageName,
  String? entrypoint,
}) {
  final Set<String>? reachable = _panelGraphOf(root, packageName, entrypoint);
  if (reachable == null) {
    // No panel entrypoint to protect. `beak prepare` writes one; until then
    // there is nothing to say.
    return const [];
  }

  final offenders = <String, String>{};
  for (final relative in reachable) {
    final file = File('${root.path}/$relative');
    if (!file.existsSync()) {
      continue;
    }
    final String source = file.readAsStringSync();
    for (final library in _serverLibraries) {
      if (source.contains("import '$library'")) {
        offenders[relative] = library;
        break;
      }
    }
  }
  if (offenders.isEmpty) {
    return const [
      BeakCheck(
        status: BeakCheckStatus.ok,
        label: 'no panel file imports the server',
      ),
    ];
  }
  return [
    for (final entry
        in offenders.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
      BeakCheck(
        status: BeakCheckStatus.fail,
        label:
            '${entry.key} imports ${entry.value}, which cannot run on the '
            'web',
        remedy:
            'move the server-side part to lib/server.dart, or import '
            'package:beak/beak.dart instead',
      ),
  ];
}

/// Every project file the panel reaches, as `lib/`-rooted relative paths.
///
/// `null` when the project has no panel entrypoint at all. Walks this
/// package's own sources only: what `package:beak` does internally is the
/// framework's problem, and `melos run guard-web` covers it there.
///
/// The roots are the [entrypoint] `beak.yaml` names, or `lib/main.dart`, and
/// the generated app widget. In an app that embeds the panel `lib/main.dart`
/// is the app's own and is not part of the panel, so it is not a root.
Set<String>? _panelGraphOf(
  Directory root,
  String packageName,
  String? entrypoint,
) {
  // `lib/main.dart` is generated and often git-ignored, so fall back to the
  // root widget it is one line of.
  final roots = [
    entrypoint ?? BeakPanelSettings.defaultEntrypoint,
    'lib/beak/app.g.dart',
  ];
  final queue = <String>[
    for (final path in roots)
      if (File('${root.path}/$path').existsSync()) path,
  ];
  if (queue.isEmpty) {
    return null;
  }

  final seen = <String>{...queue};
  while (queue.isNotEmpty) {
    final String current = queue.removeLast();
    final file = File('${root.path}/$current');
    if (!file.existsSync()) {
      continue;
    }
    for (final uri in _referencedUrisIn(file.readAsStringSync())) {
      final String? next = _resolveWithinProject(
        uri,
        from: current,
        packageName: packageName,
      );
      if (next != null && seen.add(next)) {
        queue.add(next);
      }
    }
  }
  return seen;
}

/// Every URI [source] pulls in via `import`, `export` or `part`.
///
/// Line-based and directive-anchored, matching `tool/check_web_safe.dart`: a
/// URI inside a doc comment or a string constant is not an import.
List<String> _referencedUrisIn(String source) {
  final uris = <String>[];
  for (final line in source.split('\n')) {
    final String trimmed = line.trim();
    final bool isDirective =
        trimmed.startsWith('import ') ||
        trimmed.startsWith('export ') ||
        trimmed.startsWith('part ');
    if (!isDirective || trimmed.startsWith('part of ')) {
      continue;
    }
    if (RegExp("""['"]([^'"]+)['"]""").firstMatch(trimmed) case final match?) {
      uris.add(match.group(1)!);
    }
  }
  return uris;
}

/// [uri] as a project-relative path, or `null` when it leaves the project.
///
/// A `package:` URI naming this project resolves back into `lib/`; a URI
/// naming anything else is a dependency, and stops the walk — what
/// `package:beak` does internally is the framework's problem, checked there
/// by `melos run guard-web`.
String? _resolveWithinProject(
  String uri, {
  required String from,
  required String packageName,
}) {
  if (uri.startsWith('dart:')) {
    return null;
  }
  if (uri.startsWith('package:')) {
    final String withoutScheme = uri.substring('package:'.length);
    final int slash = withoutScheme.indexOf('/');
    if (slash < 0 || withoutScheme.substring(0, slash) != packageName) {
      return null;
    }
    return 'lib/${withoutScheme.substring(slash + 1)}';
  }
  // Relative, so resolve against the importing file's directory.
  final List<String> segments = from.split('/')..removeLast();
  for (final part in uri.split('/')) {
    if (part == '.') {
      continue;
    }
    if (part == '..') {
      if (segments.isEmpty) {
        return null;
      }
      segments.removeLast();
    } else {
      segments.add(part);
    }
  }
  return segments.join('/');
}

/// Whether the configured database is reachable, and whether it still
/// matches the schema classes.
///
/// Reachability is a warning rather than a failure: the panel and the
/// generator work fine without a database, and plenty of `doctor` runs happen
/// before one exists.
Future<List<BeakCheck>> _databaseChecks(
  BeakCliEnvironment environment,
  Directory root,
  BeakLiveSchemaReader readSchema,
  List<BeakSchemaIr> schemas,
  List<BeakDiscoveryIssue> schemaIssues, {
  required Set<String> createdTables,
}) async {
  // No DATABASE_URL is the supported zero-setup default rather than a
  // misconfiguration, so it resolves to the same file the server would use
  // and is checked like any other database. Telling someone their working
  // project is wrong trains them to ignore this output.
  final Uri? configuredUrl = beakDatabaseUrlOf(
    root,
    processEnvironment: environment.processEnvironment,
  );
  final Uri url = configuredUrl ?? Uri.parse(defaultSqliteUrl);
  final bool isDefault = configuredUrl == null;
  final bool canDrift = schemaIssues.isEmpty && schemas.isNotEmpty;

  if (beakIsSqliteUrl(url)) {
    final String? file = beakSqliteFileOf(url);
    if (file == null) {
      // In-memory: it belongs to the process that opened it, so there is
      // nothing here to be out of step with, and nothing to probe.
      return const [
        BeakCheck(
          status: BeakCheckStatus.ok,
          label: 'database is in-memory SQLite, so nothing persists',
        ),
      ];
    }
    if (!beakSqliteFileExists(url, root)) {
      // Before the first migrate there is no file, and no schema that could
      // be out of step with the models.
      return [
        BeakCheck(
          status: BeakCheckStatus.ok,
          label: isDefault
              ? 'no DATABASE_URL: the default SQLite file is not created yet'
              : 'database is SQLite ($file), not created yet',
          remedy: 'beak migrate',
        ),
      ];
    }
    return [
      BeakCheck(
        status: BeakCheckStatus.ok,
        label: isDefault
            ? 'no DATABASE_URL: using the default SQLite file ($file)'
            : 'database is SQLite ($file)',
      ),
      if (canDrift)
        ...await _driftChecks(url, readSchema, schemas, root, createdTables),
    ];
  }

  final bool reachable = await environment.probe(
    url.host,
    url.hasPort ? url.port : 5432,
  );
  if (!reachable) {
    return [
      BeakCheck(
        status: BeakCheckStatus.warn,
        label: 'database unreachable at ${url.host}:${url.port}',
        remedy: 'start it, or correct DATABASE_URL in .env',
      ),
    ];
  }
  return [
    BeakCheck(
      status: BeakCheckStatus.ok,
      label: 'database reachable at ${url.host}:${url.port}',
    ),
    if (canDrift && beakCanReadSchema(url))
      ...await _driftChecks(url, readSchema, schemas, root, createdTables),
  ];
}

/// How the live schema differs from the schema classes, one check per
/// difference.
///
/// Warnings, never failures. Drift is a fact about a database rather than
/// about the project, and the fix is a migration someone has to write and
/// review — so `beak doctor` in CI should name it, not block on it.
Future<List<BeakCheck>> _driftChecks(
  Uri url,
  BeakLiveSchemaReader readSchema,
  List<BeakSchemaIr> schemas,
  Directory root,
  Set<String> createdTables,
) async {
  final List<IntrospectedTable> tables;
  try {
    tables = await readSchema(beakResolvedDatabaseUrl(url, root));
  } catch (error) {
    // The database answered the probe but not the query, which is a
    // credentials or permissions problem rather than drift. Say which.
    return [
      BeakCheck(
        status: BeakCheckStatus.warn,
        label: 'could not read the database schema: $error',
        remedy: 'check the credentials in DATABASE_URL',
      ),
    ];
  }

  final List<BeakDrift> drift = beakSchemaDrift(
    schemas: schemas,
    tables: tables,
  );
  if (drift.isEmpty) {
    return const [
      BeakCheck(
        status: BeakCheckStatus.ok,
        label: 'the database matches the schema classes',
      ),
    ];
  }
  return [
    for (final problem in drift)
      BeakCheck(
        status: BeakCheckStatus.warn,
        label: problem.message,
        remedy: _remedyFor(problem, createdTables),
      ),
  ];
}

/// What to do about [problem], which depends on why the database differs.
///
/// A table that is missing while a migration creates it is a migration that
/// has not run yet, and `beak migrate` is the fix. A column missing from a
/// table that exists is drift: the create migration already ran without it,
/// and `--from-drift` writes the `alter`. Everything else is a decision no
/// command can make.
String _remedyFor(BeakDrift problem, Set<String> createdTables) =>
    switch (problem) {
      BeakMissingTable(:final table) =>
        createdTables.contains(table)
            ? 'beak migrate'
            : 'beak prepare, which writes the migration, then beak migrate',
      BeakMissingPivot(:final table, :final schema, :final relation) =>
        createdTables.contains(table) ||
                createdTables.contains(
                  '${schema.relationsClass}.${relation.fieldName}',
                )
            ? 'beak migrate'
            : 'beak prepare, which writes the migration, then beak migrate',
      BeakMissingColumn(
        cause: BeakMissingColumnCause.declared ||
            BeakMissingColumnCause.foreignKey,
        :final columnKey,
        :final table,
      ) =>
        'beak make:migration Add${_pascalOf(columnKey)}To${_pascalOf(table)} '
            '--from-drift, then beak migrate',
      BeakMissingColumn() =>
        'write a migration with `beak make:migration <Name>` (a flag that '
            'changes more than a column is not something --from-drift adds), '
            'then beak migrate',
      BeakUndeclaredColumn(:final schema) =>
        'declare the field on ${schema.className}, or drop the column in a '
            'migration written with `beak make:migration <Name>`',
    };

/// `stock_level` -> `StockLevel`.
String _pascalOf(String snake) => snake
    .split('_')
    .where((word) => word.isNotEmpty)
    .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
    .join();

/// A failure for each import of a migration that names a file which is gone.
///
/// A create-table migration imports the schema file its model lives in, by a
/// relative path, so moving that file breaks the migration and with it the
/// whole project. The analyzer says so too, but doctor is the command that
/// answers "is this project all right", and a project that does not compile
/// is not.
List<BeakCheck> _migrationImportChecks(Directory root, String packageName) {
  final directory = Directory(p.join(root.path, 'lib', 'migrations'));
  if (!directory.existsSync()) {
    return const [];
  }
  final broken = <BeakCheck>[];
  final files =
      directory
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final String from = p.posix.joinAll(
      p.split(p.relative(file.path, from: root.path)),
    );
    for (final uri in _referencedUrisIn(file.readAsStringSync())) {
      final String? target = _resolveWithinProject(
        uri,
        from: from,
        packageName: packageName,
      );
      if (target != null && !File(p.join(root.path, target)).existsSync()) {
        broken.add(
          BeakCheck(
            status: BeakCheckStatus.fail,
            label: '$from imports $uri, which does not exist',
            remedy:
                'point the import at the file, which may have moved; the '
                'migration does not compile until it does',
          ),
        );
      }
    }
  }
  return broken.isEmpty
      ? const [
          BeakCheck(
            status: BeakCheckStatus.ok,
            label: 'migrations import files that exist',
          ),
        ]
      : broken;
}

/// What a coding agent needs in the project, one check each.
///
/// The `agents` group: the managed block in `AGENTS.md` (present, current,
/// not damaged), the `CLAUDE.md` that makes Claude Code read it, the size
/// Codex will read of it, the docs bundle copied for the resolved Beak, the
/// skills installed, and whether this CLI is the one the project's Beak was
/// released with. All warnings: none of it stops the project from building.
/// Empty for a project that does not depend on Beak.
List<BeakCheck> agentChecks(
  Directory root, {
  required BeakProjectConfig config,
}) {
  final BeakProjectKind? kind = BeakProjectKind.detect(root, config: config);
  if (kind == null) {
    return const [];
  }
  final BeakAgentReport? report = syncAgentFiles(
    root,
    options: const BeakAgentOptions(check: true, installSkills: false),
  );
  if (report == null) {
    return const [];
  }
  final workspace = BeakWorkspace.locate(root);
  final BeakPackageConfig? packages = BeakPackageConfig.read(
    workspace.packageConfigFile,
  );
  BeakCheck check(BeakCheckStatus status, String label, {String? remedy}) =>
      BeakCheck(status: status, label: label, remedy: remedy, group: 'agents');
  final checks = <BeakCheck>[];

  if (config.agents.instructions == BeakAgentInstructions.none) {
    checks.add(
      check(BeakCheckStatus.ok, 'agent instructions are disabled in beak.yaml'),
    );
  } else {
    for (final change in report.files.where((change) => !change.isClaude)) {
      checks.add(switch (change.action) {
        BeakFileAction.unchanged => check(
          BeakCheckStatus.ok,
          '${change.label} has the Beak ${report.version} block',
        ),
        BeakFileAction.updated => check(
          BeakCheckStatus.warn,
          '${change.label} has an out-of-date Beak block',
          remedy: 'beak prepare',
        ),
        _ => check(
          BeakCheckStatus.warn,
          '${change.label} has no Beak block',
          remedy: 'beak agents',
        ),
      });
    }
    for (final problem in report.problems) {
      checks.add(
        check(
          BeakCheckStatus.warn,
          problem,
          remedy: 'fix or delete the markers, then run `beak agents`',
        ),
      );
    }
  }

  final agentsMd = File(p.join(root.path, 'AGENTS.md'));
  if (agentsMd.existsSync()) {
    if (config.agents.instructions != BeakAgentInstructions.none) {
      checks.add(switch (BeakClaudeMd.pairing(root)) {
        BeakClaudePairing.paired => check(
          BeakCheckStatus.ok,
          'CLAUDE.md reads AGENTS.md',
        ),
        BeakClaudePairing.unread => check(
          BeakCheckStatus.warn,
          'AGENTS.md exists but no CLAUDE.md reads it, and Claude Code reads '
          'CLAUDE.md, not AGENTS.md',
          remedy: 'beak agents',
        ),
        BeakClaudePairing.brokenDotClaudeImport => check(
          BeakCheckStatus.warn,
          '.claude/CLAUDE.md imports `@AGENTS.md`, which resolves next to '
          'that file',
          remedy: 'use `@../AGENTS.md`',
        ),
      });
    }
    final int kib = (agentsMd.lengthSync() / 1024).ceil();
    checks.add(
      kib <= 32
          ? check(BeakCheckStatus.ok, 'AGENTS.md is $kib KiB')
          : check(
              BeakCheckStatus.warn,
              'AGENTS.md is $kib KiB, and Codex reads only the first 32 KiB',
              remedy: 'move the detail into files AGENTS.md points to',
            ),
    );
  }

  checks.add(_docsCheck(config, report, workspace, check));

  final List<BeakInstalledSkill> skills = installedSkills(workspace, packages);
  final outdated = <String>{
    for (final skill in skills)
      if (skill.status == BeakInstalledSkillStatus.outdated ||
          skill.status == BeakInstalledSkillStatus.orphaned)
        skill.name,
  };
  final edited = <String>{
    for (final skill in skills)
      if (skill.status == BeakInstalledSkillStatus.modified) skill.name,
  };
  if (outdated.isNotEmpty) {
    checks.add(
      check(
        BeakCheckStatus.warn,
        'Beak skills out of date: ${(outdated.toList()..sort()).join(', ')}',
        remedy: 'beak agents',
      ),
    );
  } else if (skills.isEmpty) {
    checks.add(
      check(
        BeakCheckStatus.ok,
        'no Beak skills installed',
        remedy: 'optional: `beak agents` installs them',
      ),
    );
  } else {
    final int count = {for (final skill in skills) skill.name}.length;
    checks.add(
      check(
        BeakCheckStatus.ok,
        '$count Beak skill${count == 1 ? '' : 's'} installed, all current',
      ),
    );
  }
  if (edited.isNotEmpty) {
    checks.add(
      check(
        BeakCheckStatus.ok,
        'Beak skills edited locally, kept as they are: '
        '${(edited.toList()..sort()).join(', ')}',
      ),
    );
  }

  final String? projectVersion =
      packages?.umbrella?.version ?? packages?.core?.version;
  if (projectVersion != null) {
    checks.add(_skewCheck(projectVersion, check));
  }
  return checks;
}

/// Whether the docs bundle in the workspace is the one the project resolved.
BeakCheck _docsCheck(
  BeakProjectConfig config,
  BeakAgentReport report,
  BeakWorkspace workspace,
  BeakCheck Function(BeakCheckStatus, String, {String? remedy}) check,
) {
  if (!config.agents.docs) {
    return check(BeakCheckStatus.ok, 'docs bundle is disabled in beak.yaml');
  }
  return switch (report.docs) {
    BeakDocsReady(:final status, :final version) => switch (status) {
      BeakDocsStatus.pending => _staleDocs(workspace, version, check),
      _ => check(
        BeakCheckStatus.ok,
        'docs bundle for Beak $version is in ${BeakWorkspace.docsPath}',
      ),
    },
    BeakDocsUnavailable(:final reason) => check(
      BeakCheckStatus.warn,
      'docs bundle unavailable: $reason',
      remedy: 'flutter pub get',
    ),
    null => check(BeakCheckStatus.ok, 'docs bundle not checked'),
  };
}

/// The check for a docs copy that is missing or of another version.
BeakCheck _staleDocs(
  BeakWorkspace workspace,
  String resolvedVersion,
  BeakCheck Function(BeakCheckStatus, String, {String? remedy}) check,
) {
  final manifest = File(p.join(workspace.docsDirectory.path, 'manifest.json'));
  String? copied;
  if (manifest.existsSync()) {
    try {
      if (jsonDecode(manifest.readAsStringSync()) case {
        'beak': final String version,
      }) {
        copied = version;
      }
    } on FormatException {
      copied = null;
    }
  }
  return copied == null
      ? check(
          BeakCheckStatus.warn,
          'docs bundle not materialized in ${BeakWorkspace.docsPath}',
          remedy: 'beak docs',
        )
      : check(
          BeakCheckStatus.warn,
          'docs bundle is Beak $copied but the project resolved Beak '
          '$resolvedVersion',
          remedy: 'beak prepare',
        );
}

/// Whether this CLI shares a minor version with the project's Beak.
BeakCheck _skewCheck(
  String projectVersion,
  BeakCheck Function(BeakCheckStatus, String, {String? remedy}) check,
) {
  final Version? project = _parse(projectVersion);
  final Version? cli = _parse(beakCliVersion);
  if (project == null ||
      cli == null ||
      (project.major == cli.major && project.minor == cli.minor)) {
    return check(
      BeakCheckStatus.ok,
      'CLI $beakCliVersion matches project Beak $projectVersion',
    );
  }
  return check(
    BeakCheckStatus.warn,
    'CLI $beakCliVersion, project Beak $projectVersion',
    remedy:
        'reactivate the CLI with `dart pub global activate --source git '
        'https://github.com/SimonErich/beak.git --git-path packages/beak_cli '
        '--git-ref v$projectVersion`',
  );
}

Version? _parse(String version) {
  try {
    return Version.parse(version);
  } on FormatException {
    return null;
  }
}
