import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../cli_runner.dart';
import '../introspect/beak_live_schema.dart';
import '../introspect/beak_schema_introspection.dart';
import '../project/beak_discovery.dart';
import '../project/beak_emitters.dart';
import '../project/beak_project_config.dart';
import '../schema/beak_migration_emitter.dart';
import '../schema/beak_schema_drift.dart';
import '../schema/beak_schema_emitter.dart';
import '../schema/beak_schema_ir.dart';
import '../schema/beak_schema_reader.dart';

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
  const BeakCheck({required this.status, required this.label, this.remedy});

  /// Whether it passed.
  final BeakCheckStatus status;

  /// What was checked, and what was found.
  final String label;

  /// The command or edit that fixes it, when a fix exists.
  final String? remedy;

  /// This check as JSON, for `beak doctor --json`.
  Map<String, Object?> toJson() => {
    'status': status.name,
    'label': label,
    if (remedy case final String remedy) 'remedy': remedy,
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
        label: 'no pubspec.yaml — this is not a Dart project',
        remedy: 'run `beak create <name>` to scaffold one',
      ),
    ];
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
          ? 'no models found under lib/models/'
          : 'discovered ${discovery.summary}',
      remedy: discovery.models.isEmpty
          ? 'add a BeakModel subclass under lib/models/'
          : null,
    ),
  );

  // Read once: the staleness check, the migration check and the drift check
  // all ask the same question of the same files, and parsing them three
  // times is parsing them three times.
  final (schemas, schemaIssues) = BeakSchemaReader(root).read();

  // Stale generated files are the one failure mode the hidden-entrypoint
  // design introduces, so name it explicitly rather than letting it surface
  // as a confusing compile error.
  final stale = <String>[];
  final missing = <String>[];
  void compare(String path, String expected) {
    final file = File('${root.path}/$path');
    if (!file.existsSync()) {
      missing.add(path);
    } else if (file.readAsStringSync() != expected) {
      stale.add(path);
    }
  }

  if (discovery.issues.isEmpty) {
    for (final generated in BeakEmitters.all(
      packageName: packageName,
      config: config,
      discovery: discovery,
    )) {
      compare(generated.path, generated.contents);
    }
    // The part files too. They are not in `BeakEmitters.all` — the schema
    // emitter writes them a step earlier, before discovery can see the
    // models they declare — and leaving them out gave `doctor` a blind spot
    // wide enough for `examples/quickstart` to sit 18 lines behind the
    // emitter while reporting "generated files up to date".
    if (schemaIssues.isEmpty) {
      for (final schema in schemas) {
        compare(
          BeakSchemaEmitter.partPathOf(schema),
          BeakSchemaEmitter.emit(schema, schemas),
        );
      }
    }
  }
  if (missing.isNotEmpty || stale.isNotEmpty) {
    checks.add(
      BeakCheck(
        status: BeakCheckStatus.fail,
        label:
            'generated files out of date '
            '(${missing.length} missing, ${stale.length} stale)',
        remedy: 'beak prepare',
      ),
    );
  } else {
    checks.add(
      const BeakCheck(
        status: BeakCheckStatus.ok,
        label: 'generated files up to date',
      ),
    );
  }

  checks.add(_migrationCoverageCheck(discovery, schemas, schemaIssues));
  checks.add(_webScaffoldCheck(root));
  checks.addAll(serverImportChecks(root, packageName: packageName));
  checks.addAll(
    await _databaseChecks(environment, root, readSchema, schemas, schemaIssues),
  );
  return checks;
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
      label: 'migration coverage not checked — fix the schema issues first',
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
/// under `lib/` — `examples/embedded` has a `lib/legacy_system.dart` that
/// migrates the host system's own table and is imported by `bin/host.dart`
/// alone — and a path allowlist called that a failure while missing the real
/// one, a server import in a file the panel does import.
List<BeakCheck> serverImportChecks(
  Directory root, {
  required String packageName,
}) {
  final Set<String>? reachable = _panelGraphOf(root, packageName);
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
Set<String>? _panelGraphOf(Directory root, String packageName) {
  // `lib/main.dart` is generated and often git-ignored, so fall back to the
  // root widget it is one line of.
  const roots = ['lib/main.dart', 'lib/beak/app.g.dart'];
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
  List<BeakDiscoveryIssue> schemaIssues,
) async {
  // No DATABASE_URL is the supported zero-setup default rather than a
  // misconfiguration, so it resolves to the same file the server would use
  // and is checked like any other database. Telling someone their working
  // project is wrong trains them to ignore this output.
  final Uri url = beakDatabaseUrlOf(root) ?? Uri.parse(defaultSqliteUrl);
  final bool isDefault = beakDatabaseUrlOf(root) == null;
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
              ? 'no DATABASE_URL — the default SQLite file is not created yet'
              : 'database is SQLite ($file), not created yet',
          remedy: 'beak migrate',
        ),
      ];
    }
    return [
      BeakCheck(
        status: BeakCheckStatus.ok,
        label: isDefault
            ? 'no DATABASE_URL — using the default SQLite file ($file)'
            : 'database is SQLite ($file)',
      ),
      if (canDrift) ...await _driftChecks(url, readSchema, schemas, root),
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
      ...await _driftChecks(url, readSchema, schemas, root),
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
        remedy: 'write a migration with `beak make:migration`, then `migrate`',
      ),
  ];
}
