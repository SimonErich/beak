import 'dart:io';

import 'package:args/command_runner.dart';

import '../cli_runner.dart';
import '../project/beak_discovery.dart';
import '../project/beak_emitters.dart';
import '../project/beak_project_config.dart';
import '../schema/beak_schema_emitter.dart';
import '../schema/beak_schema_reader.dart';

/// Regenerates the wiring a Beak project needs, from what it declares.
///
/// This is the command that makes entrypoints disappear. It scans
/// `lib/models/`, `lib/screens/`, `lib/migrations/` and `lib/seeders/`, reads
/// `beak.yaml`, and writes the registry, the panel config, the app widget, the
/// server host, and the three entrypoints — so a project contains only the
/// declarations that are actually its own.
///
/// Idempotent: a file whose contents are unchanged is not rewritten, which is
/// what keeps `beak dev` from thrashing Flutter's file watcher.
final class PrepareCommand extends Command<int> {
  /// Creates the command against [environment].
  PrepareCommand(this.environment);

  /// The injected seams (output sink, project directory).
  final BeakCliEnvironment environment;

  @override
  String get name => 'prepare';

  @override
  String get description =>
      'Regenerate the Beak wiring from lib/models, lib/screens and beak.yaml.';

  @override
  Future<int> run() async => runPrepare(environment).exitCode;
}

/// What a `prepare` run did.
final class BeakPrepareResult {
  /// Creates a result.
  const BeakPrepareResult({
    required this.discovery,
    required this.written,
    required this.unchanged,
  });

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

/// Runs generation against [environment] and reports what happened.
///
/// Exposed separately from [PrepareCommand] so other commands can prepare
/// before doing their own work without going through the runner.
BeakPrepareResult runPrepare(BeakCliEnvironment environment) {
  final Directory root = environment.rootDirectory;
  final String packageName = BeakProjectConfig.packageNameOf(root);
  final BeakProjectConfig config = BeakProjectConfig.load(
    root,
    packageName: packageName,
  );
  // Schema classes generate their own part files first, so the models they
  // declare exist before discovery goes looking for them.
  final (schemas, schemaIssues) = BeakSchemaReader(root).read();
  final schemaFiles = <String>[];
  if (schemaIssues.isEmpty) {
    for (final schema in schemas) {
      final String path =
          'lib/${_directoryOf(schema.libraryPath)}'
          '${BeakSchemaEmitter.partFileNameOf(schema.libraryPath)}';
      final String contents = BeakSchemaEmitter.emit(schema, schemas);
      final file = File('${root.path}/$path');
      if (!file.existsSync() || file.readAsStringSync() != contents) {
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(contents);
        schemaFiles.add(path);
      }
    }
  }

  final BeakDiscovery discovery = BeakProjectScanner(root).scan(
    tablesByModelClass: <String, String>{
      for (final schema in schemas) schema.modelClass: schema.table,
    },
  );
  final allIssues = <BeakDiscoveryIssue>[
    ...schemaIssues,
    ...discovery.issues,
    ...beakConfigIssues(config, discovery),
  ];

  if (allIssues.isNotEmpty) {
    environment.out.writeln('Cannot generate — fix these first:');
    for (final issue in allIssues) {
      environment.out.writeln('  ${issue.path}: ${issue.message}');
    }
    return BeakPrepareResult(
      discovery: BeakDiscovery(issues: allIssues),
      written: const [],
      unchanged: const [],
    );
  }

  final written = <String>[...schemaFiles];
  final unchanged = <String>[];
  for (final generated in BeakEmitters.all(
    packageName: packageName,
    config: config,
    discovery: discovery,
  )) {
    final file = File('${root.path}/${generated.path}');
    final bool isCurrent =
        file.existsSync() && file.readAsStringSync() == generated.contents;
    if (isCurrent) {
      unchanged.add(generated.path);
      continue;
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(generated.contents);
    written.add(generated.path);
  }

  environment.out.writeln('  ${discovery.summary}');
  environment.out.writeln(
    written.isEmpty
        ? '  generated  up to date (${unchanged.length} files)'
        : '  generated  ${written.length} of '
              '${written.length + unchanged.length} files',
  );
  return BeakPrepareResult(
    discovery: discovery,
    written: written,
    unchanged: unchanged,
  );
}

/// The directory part of [libraryPath], with a trailing slash.
///
/// A schema's part file sits beside the library that declares it, so the
/// generated path keeps whatever nesting the author chose under `lib/models/`.
String _directoryOf(String libraryPath) {
  final int slash = libraryPath.lastIndexOf('/');
  return slash < 0 ? '' : libraryPath.substring(0, slash + 1);
}
