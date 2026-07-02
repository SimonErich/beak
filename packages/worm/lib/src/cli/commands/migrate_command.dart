/// `worm migrate` command (with `--pretend` and `--step`).
library;

import '../../migration/migration_runner.dart';
import '../worm_command_runner.dart';

/// Apply pending migrations or preview them via `--pretend`.
final class MigrateCommand extends WormCommand {
  /// Creates a [MigrateCommand].
  MigrateCommand(super.context) {
    argParser
      ..addFlag(
        'pretend',
        help: 'Print compiled SQL without executing.',
        negatable: false,
      )
      ..addOption(
        'step',
        help: 'Apply at most this many pending migrations.',
        valueHelp: 'N',
      );
  }

  @override
  String get name => 'migrate';

  @override
  String get description =>
      'Apply pending migrations. Use --pretend to dry-run, '
      '--step=N to apply only the first N pending migrations.';

  @override
  Future<int> run() async {
    final adapter = await context.adapterFactory();
    final runner = MigrationRunner(
      adapter: adapter,
      migrations: context.migrations,
    );
    if (argResults?.flag('pretend') ?? false) {
      return _pretend(runner);
    }
    return _apply(runner);
  }

  Future<int> _pretend(MigrationRunner runner) async {
    final captured = await runner.pretend();
    if (captured.isEmpty) {
      context.out.writeln('Nothing to migrate.');
      context.out.writeln('Dry run complete — no changes made.');
      return 0;
    }
    for (final entry in captured.entries) {
      context.out.writeln('-- ${entry.key}');
      for (final statement in entry.value) {
        context.out.writeln(statement);
      }
    }
    context.out.writeln('Dry run complete — no changes made.');
    return 0;
  }

  Future<int> _apply(MigrationRunner runner) async {
    final step = _parseStep();
    final applied = await runner.run(step: step);
    if (applied.isEmpty) {
      context.out.writeln('Nothing to migrate.');
      return 0;
    }
    for (final name in applied) {
      context.out.writeln('migrated  $name');
    }
    return 0;
  }

  int? _parseStep() {
    final raw = argResults?.option('step');
    if (raw == null) return null;
    return int.parse(raw);
  }
}
