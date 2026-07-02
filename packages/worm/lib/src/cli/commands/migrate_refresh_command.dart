/// `worm migrate:refresh` command.
library;

import '../../migration/migration_runner.dart';
import '../force_gate.dart';
import '../worm_command_runner.dart';

/// Roll back every migration, then re-apply.
final class MigrateRefreshCommand extends WormCommand {
  /// Creates a [MigrateRefreshCommand].
  MigrateRefreshCommand(super.context) {
    enableForceFlag();
  }

  @override
  String get name => 'migrate:refresh';

  @override
  String get description =>
      'Roll back every migration, then re-apply. Requires --force in '
      'production.';

  @override
  Future<int> run() async {
    if (!ensureForceForProduction(context: context, force: force)) {
      return 1;
    }
    final adapter = await context.adapterFactory();
    final runner = MigrationRunner(
      adapter: adapter,
      migrations: context.migrations,
    );
    await runner.refresh();
    context.out.writeln('migrate:refresh complete.');
    return 0;
  }
}
