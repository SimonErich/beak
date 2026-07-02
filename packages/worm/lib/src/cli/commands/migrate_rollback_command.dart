/// `worm migrate:rollback` command.
library;

import '../../migration/migration_runner.dart';
import '../worm_command_runner.dart';

/// Roll back the most recently applied migration batch — or the
/// last N batches when `--steps=N` is supplied.
final class MigrateRollbackCommand extends WormCommand {
  /// Creates a [MigrateRollbackCommand].
  MigrateRollbackCommand(super.context) {
    argParser.addOption(
      'steps',
      help: 'Number of batches to roll back. Defaults to 1.',
      defaultsTo: '1',
      valueHelp: 'N',
    );
  }

  @override
  String get name => 'migrate:rollback';

  @override
  String get description =>
      'Roll back the most recent migration batch. Use --steps=N to '
      'roll back the last N batches.';

  @override
  Future<int> run() async {
    final steps = int.parse(argResults?.option('steps') ?? '1');
    final adapter = await context.adapterFactory();
    final runner = MigrationRunner(
      adapter: adapter,
      migrations: context.migrations,
    );
    final reverted = await runner.rollback(steps: steps);
    if (reverted.isEmpty) {
      context.out.writeln('Nothing to roll back.');
      return 0;
    }
    for (final name in reverted) {
      context.out.writeln('reverted  $name');
    }
    return 0;
  }
}
