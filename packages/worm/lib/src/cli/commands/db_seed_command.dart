/// `worm db:seed` command.
library;

import '../../seeder/environment.dart';
import '../../seeder/seeder_runner.dart';
import '../worm_command_runner.dart';

/// Run database seeders.
///
/// Surface flags:
///
/// * `--class <Name>` — run a single named seeder, ignoring the
///   environment filter. Literal AC contract:
///   `SeederRunner.run(seederClass: <Name>)`.
/// * `--force` — ignore the environment filter for every seeder.
/// * `--env <name>` — override the environment used for filtering
///   (falls back to `CliContext.environment`, which itself sources
///   `WORM_ENV` upstream).
final class DbSeedCommand extends WormCommand {
  /// Creates a [DbSeedCommand].
  DbSeedCommand(super.context) {
    argParser
      ..addOption(
        'class',
        help: 'Run only the seeder whose name matches.',
        valueHelp: 'SeederName',
      )
      ..addFlag(
        'force',
        help: 'Skip the environment filter and run every seeder.',
        negatable: false,
      )
      ..addOption(
        'env',
        help:
            'Override the environment used for filtering. '
            'Falls back to WORM_ENV / context.environment.',
        valueHelp: 'name',
      )
      ..addOption(
        'only',
        help: 'Deprecated alias for --class.',
        valueHelp: 'SeederName',
      );
  }

  @override
  String get name => 'db:seed';

  @override
  String get description =>
      'Run database seeders. Use --class to target one, --force to '
      'ignore environment filtering, --env to override the active '
      'environment.';

  @override
  Future<int> run() async {
    final results = argResults;
    final seederClass = results?.option('class') ?? results?.option('only');
    final forceFlag = results?.flag('force') ?? false;
    final environment = _resolveEnvironment(results?.option('env'));
    final adapter = await context.adapterFactory();
    final runner = SeederRunner(
      adapter: adapter,
      seeders: context.seeders,
      environment: environment,
    );
    final ran = await runner.run(seederClass: seederClass, force: forceFlag);
    if (ran.isEmpty) {
      context.out.writeln(
        'No seeders applicable to ${environment.name} environment.',
      );
      return 0;
    }
    for (final name in ran) {
      context.out.writeln('seeded  $name');
    }
    return 0;
  }

  /// Resolves the seeding environment. Honours an explicit
  /// `--env <name>` first, then falls back to
  /// `context.environment`. Parsing is case-insensitive.
  Environment _resolveEnvironment(String? raw) {
    if (raw == null) return context.environment;
    final lower = raw.trim().toLowerCase();
    for (final env in Environment.values) {
      if (env.name == lower) return env;
    }
    return context.environment;
  }
}
