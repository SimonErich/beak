import 'dart:io';

import 'package:args/command_runner.dart';

import '../cli_runner.dart';
import '../project/beak_discovery.dart';
import '../project/beak_emitters.dart';
import '../project/beak_project_config.dart';

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
}

/// Diagnoses a Beak project.
///
/// The previous `doctor` checked this repository's own layout — a vendored
/// `packages/worm`, a sibling `obers_ui`, and the demo stack's ports — so in a
/// user's generated project it printed four failures and exited 1, always.
/// This one checks the project it is actually run in.
final class DoctorCommand extends Command<int> {
  /// Creates the command bound to [environment].
  DoctorCommand(this.environment);

  /// The seams this command runs against.
  final BeakCliEnvironment environment;

  @override
  String get name => 'doctor';

  @override
  String get description => 'Diagnose this Beak project.';

  @override
  Future<int> run() async {
    final checks = await diagnose(environment);
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
    final bool healthy = checks.every(
      (check) => check.status != BeakCheckStatus.fail,
    );
    environment.out.writeln(
      healthy ? 'All checks passed.' : 'Some checks failed.',
    );
    return healthy ? 0 : 1;
  }
}

/// Runs every diagnostic against [environment], in report order.
///
/// Exposed separately from the command so the checks can be asserted on
/// directly, and so other commands can reuse them.
Future<List<BeakCheck>> diagnose(BeakCliEnvironment environment) async {
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
  final bool dependsOnBeak = pubspecSource.contains('beak_core');
  checks.add(
    BeakCheck(
      status: dependsOnBeak ? BeakCheckStatus.ok : BeakCheckStatus.fail,
      label: dependsOnBeak
          ? 'project depends on Beak'
          : 'project does not depend on beak_core',
      remedy: dependsOnBeak ? null : 'add beak_core to pubspec.yaml',
    ),
  );

  // beak.yaml is optional, but a malformed one stops generation dead.
  final String packageName = _packageNameOf(pubspecSource);
  try {
    BeakProjectConfig.load(root, packageName: packageName);
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
      config: BeakProjectConfig.load(root, packageName: packageName),
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

  checks.add(await _databaseCheck(environment, root));
  return checks;
}

/// Whether the configured database is reachable.
///
/// A warning rather than a failure: the panel and the generator work fine
/// without a database, and plenty of `doctor` runs happen before one exists.
Future<BeakCheck> _databaseCheck(
  BeakCliEnvironment environment,
  Directory root,
) async {
  final Uri? url = _databaseUrlOf(root);
  if (url == null) {
    return const BeakCheck(
      status: BeakCheckStatus.warn,
      label: 'no DATABASE_URL in .env',
      remedy: 'add DATABASE_URL to .env before running `beak migrate`',
    );
  }
  final bool reachable = await environment.probe(
    url.host,
    url.hasPort ? url.port : 5432,
  );
  return BeakCheck(
    status: reachable ? BeakCheckStatus.ok : BeakCheckStatus.warn,
    label: reachable
        ? 'database reachable at ${url.host}:${url.port}'
        : 'database unreachable at ${url.host}:${url.port}',
    remedy: reachable ? null : 'start it, or correct DATABASE_URL in .env',
  );
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

/// The `name:` declared in [pubspecSource].
String _packageNameOf(String pubspecSource) {
  for (final line in pubspecSource.split('\n')) {
    final match = RegExp(r'^name:\s*(\S+)\s*$').firstMatch(line);
    if (match != null) {
      return match.group(1)!;
    }
  }
  return 'beak_app';
}
