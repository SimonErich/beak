/// `worm migrate:fresh` command.
library;

import '../../migration/migration_runner.dart';
import '../force_gate.dart';
import '../worm_command_runner.dart';

/// Drop the tracking table and re-apply every migration.
///
/// With `--seed`, also runs every registered seeder once the
/// migrations have re-applied — delegated to
/// [MigrationRunner.fresh] via its `seed:` parameter, which returns
/// the list of seeders that actually ran so the CLI can echo each
/// one. Refuses to proceed in production without `--force`
/// (delegated to [ensureForceForProduction]).
final class MigrateFreshCommand extends WormCommand {
  /// Creates a [MigrateFreshCommand].
  MigrateFreshCommand(super.context) {
    enableForceFlag();
    argParser.addFlag(
      'seed',
      help: 'Run all registered seeders after migrations re-apply.',
      negatable: false,
    );
  }

  @override
  String get name => 'migrate:fresh';

  @override
  String get description =>
      'Drop the migration log and re-apply every migration. '
      'Use --seed to also run seeders. Requires --force in production.';

  @override
  Future<int> run() async {
    if (!ensureForceForProduction(context: context, force: force)) {
      return 1;
    }
    final seed = argResults?.flag('seed') ?? false;
    final adapter = await context.adapterFactory();
    final runner = MigrationRunner(
      adapter: adapter,
      migrations: context.migrations,
      seeders: context.seeders,
      environment: context.environment,
    );
    final seeded = await runner.fresh(seed: seed);
    context.out.writeln(
      'migrate:fresh complete '
      '(${context.migrations.length} migration(s) applied).',
    );
    for (final name in seeded) {
      context.out.writeln('seeded  $name');
    }
    return 0;
  }
}
