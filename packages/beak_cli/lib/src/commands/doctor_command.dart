import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../cli_runner.dart';
import '../introspect/beak_schema_introspection.dart';
import '../introspect/postgres_introspector.dart';
import '../project/beak_discovery.dart';
import '../project/beak_emitters.dart';
import '../project/beak_project_config.dart';
import '../schema/beak_migration_emitter.dart';
import '../schema/beak_schema_drift.dart';
import '../schema/beak_schema_ir.dart';
import '../schema/beak_schema_reader.dart';
import 'introspect_command.dart';

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
  /// [open] is the seam the drift check reads the live schema through; tests
  /// pass their own so the check runs against canned rows.
  DoctorCommand(this.environment, {BeakDatabaseOpener? open})
    : _open = open ?? openPostgresConnection {
    argParser.addFlag(
      'json',
      help: 'Report as JSON, for CI.',
      negatable: false,
    );
  }

  /// The seams this command runs against.
  final BeakCliEnvironment environment;

  /// How the drift check connects to the database.
  final BeakDatabaseOpener _open;

  @override
  String get name => 'doctor';

  @override
  String get description => 'Diagnose this Beak project.';

  @override
  Future<int> run() async {
    final checks = await diagnose(environment, open: _open);
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
/// directly, and so other commands can reuse them. [open] connects to the
/// database for the drift check, and defaults to a real connection.
Future<List<BeakCheck>> diagnose(
  BeakCliEnvironment environment, {
  BeakDatabaseOpener open = openPostgresConnection,
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
  for (final issue in discovery.issues) {
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

  // Stale generated files are the one failure mode the hidden-entrypoint
  // design introduces, so name it explicitly rather than letting it surface
  // as a confusing compile error.
  final stale = <String>[];
  final missing = <String>[];
  if (discovery.issues.isEmpty) {
    for (final generated in BeakEmitters.all(
      packageName: packageName,
      config: config,
      discovery: discovery,
    )) {
      final file = File('${root.path}/${generated.path}');
      if (!file.existsSync()) {
        missing.add(generated.path);
      } else if (file.readAsStringSync() != generated.contents) {
        stale.add(generated.path);
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

  // Read once: the migration check and the drift check ask the same
  // question of the same files, and parsing them twice is parsing them
  // twice.
  final (schemas, schemaIssues) = BeakSchemaReader(root).read();
  checks.add(_migrationCoverageCheck(discovery, schemas, schemaIssues));
  checks.add(_webScaffoldCheck(root));
  checks.addAll(serverImportChecks(root));
  checks.addAll(
    await _databaseChecks(environment, root, open, schemas, schemaIssues),
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

/// Panel files that reach the server, one check each.
///
/// This is the failure the library split exists to prevent: the panel runs in
/// a browser and the server half imports `dart:io` and a database driver, so
/// one such import compiles fine and then fails at runtime — or takes the
/// server's ahead-of-time build down with it when the file is also reachable
/// from `bin/serve.dart`.
List<BeakCheck> serverImportChecks(Directory root) {
  const serverLibraries = {
    'package:beak/server.dart',
    'package:beak/migrations.dart',
  };
  // Where server-side code legitimately lives.
  const allowed = {
    'lib/server.dart',
    'lib/beak/server.g.dart',
    'lib/${BeakProjectScanner.migrationsDir}/',
    'lib/${BeakProjectScanner.seedersDir}/',
  };

  final lib = Directory('${root.path}/lib');
  if (!lib.existsSync()) {
    return const [];
  }
  final offenders = <String, String>{};
  for (final entity in lib.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    final String relative = entity.path
        .substring(root.path.length + 1)
        .replaceAll(r'\', '/');
    if (allowed.any(
      (path) =>
          path.endsWith('/') ? relative.startsWith(path) : relative == path,
    )) {
      continue;
    }
    final String source = entity.readAsStringSync();
    for (final library in serverLibraries) {
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

/// Whether the configured database is reachable, and whether it still
/// matches the schema classes.
///
/// Reachability is a warning rather than a failure: the panel and the
/// generator work fine without a database, and plenty of `doctor` runs happen
/// before one exists.
Future<List<BeakCheck>> _databaseChecks(
  BeakCliEnvironment environment,
  Directory root,
  BeakDatabaseOpener open,
  List<BeakSchemaIr> schemas,
  List<BeakDiscoveryIssue> schemaIssues,
) async {
  final Uri? url = _databaseUrlOf(root);
  if (url == null) {
    // Not a warning: no DATABASE_URL is the supported zero-setup default, and
    // telling someone their working project is misconfigured trains them to
    // ignore this output.
    return const [
      BeakCheck(
        status: BeakCheckStatus.ok,
        label: 'no DATABASE_URL — using the default SQLite file',
      ),
    ];
  }
  if (url.scheme == 'sqlite' || url.scheme == 'file') {
    return [
      BeakCheck(
        status: BeakCheckStatus.ok,
        label:
            'database is SQLite '
            '(${url.path.isEmpty ? url.toString() : url.path})',
      ),
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
    if (isIntrospectableUrl(url) && schemaIssues.isEmpty && schemas.isNotEmpty)
      ...await _driftChecks(url, open, schemas),
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
  BeakDatabaseOpener open,
  List<BeakSchemaIr> schemas,
) async {
  final List<IntrospectedTable> tables;
  try {
    final (BeakSqlReader query, Future<void> Function() close) = await open(
      url,
    );
    try {
      tables = await PostgresIntrospector(query).read();
    } finally {
      await close();
    }
  } catch (error) {
    // The port answered but the connection did not, which is a credentials
    // or permissions problem rather than drift. Say which.
    return [
      BeakCheck(
        status: BeakCheckStatus.warn,
        label: 'could not read the database schema: $error',
        remedy: 'check the credentials in DATABASE_URL',
      ),
    ];
  }

  final List<String> drift = beakSchemaDrift(schemas: schemas, tables: tables);
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
        label: problem,
        remedy: 'write a migration with `beak make:migration`, then `migrate`',
      ),
  ];
}

/// The `DATABASE_URL` from the project's `.env`, when it declares one.
Uri? _databaseUrlOf(Directory root) {
  final env = File('${root.path}/.env');
  if (!env.existsSync()) {
    return null;
  }
  for (final line in env.readAsLinesSync()) {
    final match = RegExp(r'^\s*DATABASE_URL\s*=\s*(\S+)\s*$').firstMatch(line);
    if (match != null) {
      return Uri.tryParse(match.group(1)!);
    }
  }
  return null;
}
