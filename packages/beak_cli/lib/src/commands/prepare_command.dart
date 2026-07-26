import 'dart:io';

import 'package:args/command_runner.dart';

import '../cli_runner.dart';
import '../project/beak_discovery.dart';
import '../project/beak_emitters.dart';
import '../project/beak_project_config.dart';

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
  final String packageName = _packageNameOf(root);
  final BeakProjectConfig config = BeakProjectConfig.load(
    root,
    packageName: packageName,
  );
  final BeakDiscovery discovery = BeakProjectScanner(root).scan();

  if (discovery.issues.isNotEmpty) {
    environment.out.writeln('Cannot generate — fix these first:');
    for (final issue in discovery.issues) {
      environment.out.writeln('  ${issue.path}: ${issue.message}');
    }
    return BeakPrepareResult(
      discovery: discovery,
      written: const [],
      unchanged: const [],
    );
  }

  final written = <String>[];
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

/// The `name:` from the project's pubspec, or a fallback.
///
/// Read with a line scan rather than a YAML parse: the pubspec may not be
/// valid YAML mid-edit, and a missing name should not stop generation.
String _packageNameOf(Directory root) {
  final file = File('${root.path}/pubspec.yaml');
  if (!file.existsSync()) {
    return 'beak_app';
  }
  for (final line in file.readAsLinesSync()) {
    final match = RegExp(r'^name:\s*(\S+)\s*$').firstMatch(line);
    if (match != null) {
      return match.group(1)!;
    }
  }
  return 'beak_app';
}
