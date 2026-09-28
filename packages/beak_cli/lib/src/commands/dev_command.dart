import 'package:args/command_runner.dart';

import '../cli_runner.dart';
import 'prepare_command.dart';

/// Runs a Beak project's backend, after regenerating its wiring.
///
/// The panel is deliberately *not* spawned here. Proxying `flutter run`'s
/// interactive console — raw-mode stdin, interleaved ANSI, correct teardown on
/// Ctrl-C — is the fiddliest part of a dev server and the least testable, and
/// getting it subtly wrong costs more than it saves. `beak dev` regenerates,
/// serves the API, and prints the exact `flutter run` line to paste in a second
/// terminal, which is the part that actually needs automating.
///
/// ```console
/// $ beak dev
///   1 model · 0 resource classes · 0 screens · 0 overrides
///   generated  up to date (7 files)
///   panel      run this in another terminal:
///                flutter run -d chrome
///   api        starting…
/// ```
final class DevCommand extends Command<int> {
  /// Creates the command against [environment].
  DevCommand(this.environment) {
    argParser
      ..addOption(
        'device',
        abbr: 'd',
        help: 'Device the printed `flutter run` line targets.',
        defaultsTo: 'chrome',
      )
      ..addFlag(
        'serve',
        help: 'Start the API. Pass --no-serve to only regenerate.',
        defaultsTo: true,
      );
  }

  /// The injected seams (output sink, project directory, process runner).
  final BeakCliEnvironment environment;

  @override
  String get name => 'dev';

  @override
  String get description =>
      'Regenerate the wiring and serve the API for development.';

  @override
  Future<int> run() async {
    final BeakPrepareResult prepared = runPrepare(environment);
    if (!prepared.isSuccess) {
      return prepared.exitCode;
    }

    final String device = switch (argResults?['device']) {
      final String value => value,
      _ => 'chrome',
    };
    environment.out
      ..writeln('  panel      run this in another terminal:')
      ..writeln('               flutter run -d $device');

    if (argResults?['serve'] == false) {
      return 0;
    }

    environment.out.writeln('  api        starting…');
    return environment.runProcess('dart', const [
      'run',
      'bin/serve.dart',
    ], workingDirectory: environment.rootDirectory.path);
  }
}

/// Applies pending migrations, after regenerating the wiring.
///
/// A thin pass-through to the project's generated `bin/migrate.dart`, which
/// runs the worm CLI over the same host the server uses — so the schema and
/// the API can never come from different registries.
final class MigrateCommand extends Command<int> {
  /// Creates the command against [environment].
  MigrateCommand(this.environment);

  /// The injected seams.
  final BeakCliEnvironment environment;

  @override
  String get name => 'migrate';

  @override
  String get description => 'Apply pending migrations.';

  @override
  String get invocation => 'beak migrate [status|up|down|fresh|refresh]';

  @override
  Future<int> run() =>
      runProjectCli(environment, argResults?.rest ?? const ['migrate']);
}

/// Runs the project's seeders.
final class SeedCommand extends Command<int> {
  /// Creates the command against [environment].
  SeedCommand(this.environment);

  /// The injected seams.
  final BeakCliEnvironment environment;

  @override
  String get name => 'seed';

  @override
  String get description => 'Run the project seeders.';

  @override
  Future<int> run() => runProjectCli(environment, const ['db:seed']);
}

/// Regenerates, then runs the project's `bin/migrate.dart` with [args].
///
/// Preparing first is what makes a newly added migration or seeder take effect
/// without a separate command — the generated host lists them.
Future<int> runProjectCli(
  BeakCliEnvironment environment,
  List<String> args,
) async {
  final BeakPrepareResult prepared = runPrepare(environment);
  if (!prepared.isSuccess) {
    return prepared.exitCode;
  }
  return environment.runProcess('dart', [
    'run',
    'bin/migrate.dart',
    ...args.isEmpty ? const ['migrate'] : args,
  ], workingDirectory: environment.rootDirectory.path);
}
