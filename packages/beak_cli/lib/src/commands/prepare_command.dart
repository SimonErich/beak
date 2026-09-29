import 'dart:io';

import 'package:args/command_runner.dart';

import '../agents/beak_project_kind.dart';
import '../cli_runner.dart';
import '../project/beak_discovery.dart';
import '../project/beak_emitters.dart';
import '../project/beak_project_config.dart';
import '../schema/beak_migration_emitter.dart';
import '../schema/beak_schema_emitter.dart';
import '../schema/beak_schema_ir.dart';
import '../schema/beak_schema_reader.dart';
import 'agents_command.dart';

/// Regenerates the wiring a Beak project needs, from what it declares.
///
/// This is the command that makes entrypoints disappear. It reads every
/// schema class under `lib/` and writes its `.beak.dart` part, finds the
/// models and `BeakResource` classes anywhere under `lib/`, the screens under
/// `lib/screens/`, the migrations and seeders, reads `beak.yaml`, and writes
/// the registry, the panel config, the app widget, the server host, and the
/// three entrypoints, so a project contains only the declarations that are
/// actually its own. An entrypoint without the generated header belongs to
/// the project and is left alone: that is how an authored `lib/main.dart`,
/// the one `beak eject main` writes, stays authored.
///
/// Idempotent: a file whose contents are unchanged is not rewritten, which is
/// what keeps `beak dev` from thrashing Flutter's file watcher.
///
/// When generation succeeds it also brings the files a coding agent reads up
/// to date (the docs of the resolved Beak version and the managed block in
/// `AGENTS.md`), as `beak.yaml`'s `agents:` section allows, and says so in
/// one line.
///
/// A package that depends on `beak_core` alone only holds schema classes, for
/// a server and an admin that live elsewhere. There `prepare` writes the
/// `*.beak.dart` parts and `lib/beak/registry.g.dart` and nothing else: no
/// app, panel or server wiring, no entrypoint, no migration, and no
/// `beak.yaml` to read.
final class PrepareCommand extends Command<int> {
  /// Creates the command against [environment].
  PrepareCommand(this.environment);

  /// The injected seams (output sink, project directory).
  final BeakCliEnvironment environment;

  @override
  String get name => 'prepare';

  @override
  String get description =>
      'Regenerate the Beak wiring from the schema classes, resource classes, '
      'screens and beak.yaml.';

  @override
  Future<int> run() async {
    final BeakPrepareResult result = runPrepare(environment);
    if (result.isSuccess) {
      // The agent files describe what was just generated, so they follow it.
      // A problem there is a line of output, never a failed prepare.
      refreshAgentFiles(environment);
    }
    return result.exitCode;
  }
}

/// What a `prepare` run did.
final class BeakPrepareResult {
  /// Creates a result.
  const BeakPrepareResult({
    required this.config,
    required this.discovery,
    required this.written,
    required this.unchanged,
  });

  /// The `beak.yaml` the run generated from.
  final BeakProjectConfig config;

  /// What the scan found, including any issues.
  final BeakDiscovery discovery;

  /// Paths whose contents changed and were rewritten.
  final List<String> written;

  /// Paths already up to date.
  final List<String> unchanged;

  /// Whether generation succeeded.
  bool get isSuccess => discovery.issues.isEmpty;

  /// The process exit code: 0 when generation succeeded, 1 otherwise.
  int get exitCode => isSuccess ? 0 : 1;
}

/// The files `beak prepare` owns for a project configured as [config].
///
/// [BeakEmitters.all], minus `lib/main.dart` when `beak.yaml` names a
/// `panel.entrypoint`: an app that embeds the panel keeps its own
/// `lib/main.dart`, so Beak neither writes it nor compares it. `beak doctor`
/// asks the same question of the same list, so the two cannot disagree about
/// which files should exist.
List<BeakGeneratedFile> beakGeneratedFiles({
  required String packageName,
  required BeakProjectConfig config,
  required BeakDiscovery discovery,
}) => [
  for (final file in BeakEmitters.all(
    packageName: packageName,
    config: config,
    discovery: discovery,
  ))
    if (config.panel.entrypoint == null || file.path != 'lib/main.dart') file,
];

/// Runs generation against [environment] and reports what happened.
///
/// Exposed separately from [PrepareCommand] so other commands can prepare
/// before doing their own work without going through the runner. A package of
/// schema classes only (see [BeakProjectKind.isModelsOnly]) gets the parts and
/// the registry and nothing else.
BeakPrepareResult runPrepare(BeakCliEnvironment environment) {
  final Directory root = environment.rootDirectory;
  final String packageName = BeakProjectConfig.packageNameOf(root);
  if (BeakProjectKind.isModelsOnly(root)) {
    return _prepareModelsOnly(environment, packageName);
  }
  final BeakProjectConfig config = BeakProjectConfig.load(
    root,
    packageName: packageName,
  );
  // Schema classes generate their own part files first, so the models they
  // declare exist before discovery goes looking for them.
  final (schemas, schemaIssues) = BeakSchemaReader(root).read();
  final List<String> schemaFiles = _writeSchemaParts(
    root,
    schemas,
    schemaIssues,
  ).written;

  final BeakDiscovery discovery = BeakProjectScanner(
    root,
  ).scan(tablesByModelClass: _tablesByModelClass(schemas));
  final allIssues = <BeakDiscoveryIssue>[
    ...schemaIssues,
    ...discovery.issues,
    ...beakConfigIssues(config, discovery),
  ];

  if (allIssues.isNotEmpty) {
    return _refused(environment, config, allIssues);
  }

  // Migrations before the wiring: a migration Beak writes must be visible to
  // the scan that lists them on the generated host. They are written once and
  // never rewritten, so they deliberately sit outside BeakEmitters.all, whose
  // every entry `beak doctor` byte-compares and would call stale.
  final migrationFiles = <String>[];
  for (final migration in BeakMigrationEmitter.missing(
    models: discovery.models,
    schemas: schemas,
    coveredTables: discovery.migratedTables,
    now: environment.now(),
  )) {
    final file = File('${root.path}/${migration.path}');
    if (file.existsSync()) {
      continue;
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(migration.contents);
    migrationFiles.add(migration.path);
  }
  final BeakDiscovery withMigrations = migrationFiles.isEmpty
      ? discovery
      : BeakProjectScanner(
          root,
        ).scan(tablesByModelClass: _tablesByModelClass(schemas));

  final written = <String>[...schemaFiles, ...migrationFiles];
  final unchanged = <String>[];
  for (final generated in beakGeneratedFiles(
    packageName: packageName,
    config: config,
    discovery: withMigrations,
  )) {
    final file = File('${root.path}/${generated.path}');
    // Entrypoints are scaffold defaults. Once an application owns one, model
    // generation must not replace its direct BeakPanel resource configuration.
    if (!generated.isCommitted &&
        file.existsSync() &&
        !file.readAsStringSync().startsWith('// GENERATED BY')) {
      unchanged.add(generated.path);
      continue;
    }
    if (_writeIfChanged(file, generated.contents)) {
      written.add(generated.path);
    } else {
      unchanged.add(generated.path);
    }
  }

  environment.out.writeln('  ${withMigrations.summary}');
  _reportFiles(environment, written: written, unchanged: unchanged);
  return BeakPrepareResult(
    config: config,
    discovery: withMigrations,
    written: written,
    unchanged: unchanged,
  );
}

/// The generation of a package that only holds schema classes.
///
/// Reads no `beak.yaml`: nothing in it applies where there is no panel, no
/// server and no entrypoint to configure. Scans for the models alone, so a
/// stray `lib/screens/` or `lib/migrations/` cannot block it either.
BeakPrepareResult _prepareModelsOnly(
  BeakCliEnvironment environment,
  String packageName,
) {
  final Directory root = environment.rootDirectory;
  final config = BeakProjectConfig.defaults(packageName: packageName);
  final (schemas, schemaIssues) = BeakSchemaReader(root).read();
  final parts = _writeSchemaParts(root, schemas, schemaIssues);
  final BeakDiscovery discovery = BeakProjectScanner(
    root,
  ).scanModels(tablesByModelClass: _tablesByModelClass(schemas));
  final allIssues = <BeakDiscoveryIssue>[...schemaIssues, ...discovery.issues];
  if (allIssues.isNotEmpty) {
    return _refused(environment, config, allIssues);
  }

  final written = <String>[...parts.written];
  final unchanged = <String>[...parts.unchanged];
  for (final generated in BeakEmitters.modelsOnly(discovery)) {
    if (_writeIfChanged(
      File('${root.path}/${generated.path}'),
      generated.contents,
    )) {
      written.add(generated.path);
    } else {
      unchanged.add(generated.path);
    }
  }

  final int count = discovery.models.length;
  environment.out.writeln(
    '  $count ${count == 1 ? 'model' : 'models'} · models-only package',
  );
  _reportFiles(environment, written: written, unchanged: unchanged);
  return BeakPrepareResult(
    config: config,
    discovery: discovery,
    written: written,
    unchanged: unchanged,
  );
}

/// Writes the `.beak.dart` part of each schema class whose text changed.
///
/// Nothing is written while [schemaIssues] is non-empty: a schema that does
/// not read has no part to generate. The two lists are project-relative
/// paths.
({List<String> written, List<String> unchanged}) _writeSchemaParts(
  Directory root,
  List<BeakSchemaIr> schemas,
  List<BeakDiscoveryIssue> schemaIssues,
) {
  final written = <String>[];
  final unchanged = <String>[];
  if (schemaIssues.isNotEmpty) {
    return (written: written, unchanged: unchanged);
  }
  for (final schema in schemas) {
    final String path = BeakSchemaEmitter.partPathOf(schema);
    final bool changed = _writeIfChanged(
      File('${root.path}/$path'),
      BeakSchemaEmitter.emit(schema, schemas),
    );
    (changed ? written : unchanged).add(path);
  }
  return (written: written, unchanged: unchanged);
}

/// The physical table of each schema class's model, by model class name.
Map<String, String> _tablesByModelClass(List<BeakSchemaIr> schemas) => {
  for (final schema in schemas) schema.modelClass: schema.table,
};

/// Writes [contents] to [file] unless it already holds exactly that, and says
/// whether it wrote.
///
/// Not touching a current file is what keeps `beak dev` from thrashing
/// Flutter's file watcher.
bool _writeIfChanged(File file, String contents) {
  if (file.existsSync() && file.readAsStringSync() == contents) {
    return false;
  }
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
  return true;
}

/// Lists [issues] and returns the result of a run that generated nothing.
BeakPrepareResult _refused(
  BeakCliEnvironment environment,
  BeakProjectConfig config,
  List<BeakDiscoveryIssue> issues,
) {
  environment.out.writeln('Cannot generate — fix these first:');
  for (final issue in issues) {
    environment.out.writeln('  ${issue.path}: ${issue.message}');
  }
  return BeakPrepareResult(
    config: config,
    discovery: BeakDiscovery(issues: issues),
    written: const [],
    unchanged: const [],
  );
}

/// The line that says how many files were written.
void _reportFiles(
  BeakCliEnvironment environment, {
  required List<String> written,
  required List<String> unchanged,
}) {
  environment.out.writeln(
    written.isEmpty
        ? '  generated  up to date (${unchanged.length} files)'
        : '  generated  ${written.length} of '
              '${written.length + unchanged.length} files',
  );
}
