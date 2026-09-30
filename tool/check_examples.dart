/// Example-health guard (`melos run check-examples`).
///
/// The examples are the only place the whole generator is exercised
/// end to end, and they are what a reader copies. Nothing else in the gate
/// notices when one drifts: `analyze` and `test` both run against whatever
/// generated code is checked in, so a change to an emitter leaves the
/// examples stale and every gate green.
///
/// So: run the real `beak doctor` — the binary, through its `--json`
/// contract, in each example — and fail on any FAIL it reports. That covers
/// stale or missing generated files, a model with no migration, a panel file
/// reaching the server, and a malformed `beak.yaml`, without this tool
/// knowing what any of those are.
///
/// Warnings are printed and do not fail: "no `web/` scaffold" and "database
/// unreachable" are true of a checkout without Flutter's web scaffold or a
/// running Postgres, and neither is a defect in the example.
///
/// Sibling of `tool/check_no_material.dart` and `tool/check_web_safe.dart`,
/// wired into `melos run analyze` next to them.
library;

import 'dart:convert';
import 'dart:io';

/// Where the examples live, relative to the repository root.
const String examplesDir = 'examples';

/// The CLI entrypoint, relative to the repository root.
const String beakCli = 'packages/beak_cli/bin/beak.dart';

/// One example's verdict.
final class ExampleHealth {
  /// Creates a verdict for [name].
  const ExampleHealth({
    required this.name,
    required this.failures,
    required this.warnings,
  });

  /// The example's directory name.
  final String name;

  /// Labels of the checks that failed.
  final List<String> failures;

  /// Labels of the checks that warned.
  final List<String> warnings;

  /// Whether nothing failed.
  bool get isHealthy => failures.isEmpty;
}

Future<void> main(List<String> arguments) async {
  final Directory root = Directory.current;
  final List<Directory> examples = examplesIn(root);
  if (examples.isEmpty) {
    stderr.writeln('No examples found under $examplesDir/.');
    exit(1);
  }

  final results = <ExampleHealth>[];
  for (final example in examples) {
    results.add(await healthOf(example, repositoryRoot: root));
  }

  for (final result in results) {
    final String badge = result.isHealthy ? 'OK  ' : 'FAIL';
    stdout.writeln('  $badge ${result.name}');
    for (final failure in result.failures) {
      stdout.writeln('       ✗ $failure');
    }
    for (final warning in result.warnings) {
      stdout.writeln('       ! $warning');
    }
  }

  final unhealthy = results.where((result) => !result.isHealthy).toList();
  if (unhealthy.isEmpty) {
    stdout.writeln('All ${results.length} examples are healthy.');
    return;
  }
  stderr
    ..writeln()
    ..writeln(
      '${unhealthy.length} example(s) failed `beak doctor`. Run '
      '`beak prepare` in each, and commit what it writes.',
    );
  exit(1);
}

/// Every directory under `examples/` that is a Beak project.
///
/// A pub workspace root (a `workspace:` list, e.g. `examples/serverpod`) is
/// skipped: it is a Serverpod project with its own CI job, and `beak doctor`
/// does not run at a workspace root.
List<Directory> examplesIn(Directory root) {
  final directory = Directory('${root.path}/$examplesDir');
  if (!directory.existsSync()) {
    return const [];
  }
  final found = <Directory>[
    for (final entity in directory.listSync())
      if (entity is Directory &&
          File('${entity.path}/pubspec.yaml').existsSync() &&
          !isWorkspaceRoot(
            File('${entity.path}/pubspec.yaml').readAsStringSync(),
          ))
        entity,
  ];
  found.sort((a, b) => a.path.compareTo(b.path));
  return found;
}

/// Whether [pubspecSource] is a pub workspace root.
bool isWorkspaceRoot(String pubspecSource) =>
    RegExp(r'^workspace:', multiLine: true).hasMatch(pubspecSource);

/// Runs `beak doctor --json` in [example] and reads its verdict.
Future<ExampleHealth> healthOf(
  Directory example, {
  required Directory repositoryRoot,
}) async {
  final String name = example.path.split(Platform.pathSeparator).last;
  final ProcessResult result = await Process.run('dart', [
    'run',
    '${repositoryRoot.path}/$beakCli',
    'doctor',
    '--json',
  ], workingDirectory: example.path);

  final Object? report = _decode(result.stdout);
  if (report is! Map<String, Object?>) {
    return ExampleHealth(
      name: name,
      failures: [
        'beak doctor produced no JSON (exit ${result.exitCode}): '
            '${_firstLine(result.stderr)}',
      ],
      warnings: const [],
    );
  }

  final failures = <String>[];
  final warnings = <String>[];
  final Object? checks = report['checks'];
  for (final check in checks is List<Object?> ? checks : const <Object?>[]) {
    if (check case {
      'status': final String status,
      'label': final String label,
    }) {
      if (status == 'fail') {
        failures.add(label);
      } else if (status == 'warn') {
        warnings.add(label);
      }
    }
  }
  return ExampleHealth(name: name, failures: failures, warnings: warnings);
}

/// [output] as JSON, or `null` when it is not.
Object? _decode(Object? output) {
  if (output is! String || output.trim().isEmpty) {
    return null;
  }
  try {
    return jsonDecode(output);
  } on FormatException {
    return null;
  }
}

/// The first non-empty line of [text], for a one-line error.
String _firstLine(Object? text) {
  if (text is! String) {
    return '';
  }
  for (final line in text.split('\n')) {
    if (line.trim().isNotEmpty) {
      return line.trim();
    }
  }
  return '';
}
