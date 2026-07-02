/// `worm migrate:status` command.
library;

import '../../migration/migration_runner.dart';
import '../../migration/migration_status.dart';
import '../worm_command_runner.dart';

/// Show pending vs. applied state for every registered migration as
/// a column-aligned `Migration | Batch | Status` table.
final class MigrateStatusCommand extends WormCommand {
  /// Creates a [MigrateStatusCommand].
  MigrateStatusCommand(super.context);

  @override
  String get name => 'migrate:status';

  @override
  String get description => 'List pending and applied migrations.';

  @override
  Future<int> run() async {
    final adapter = await context.adapterFactory();
    final runner = MigrationRunner(
      adapter: adapter,
      migrations: context.migrations,
    );
    final report = await runner.status();
    if (report.isEmpty) {
      context.out.writeln('No migrations registered.');
      return 0;
    }
    _printTable(report);
    return 0;
  }

  void _printTable(List<MigrationStatus> report) {
    final nameWidth = _widestName(report);
    final header = _row('Migration', 'Batch', 'Status', nameWidth);
    context.out
      ..writeln(header)
      ..writeln('-' * header.length);
    for (final entry in report) {
      context.out.writeln(_formatRow(entry, nameWidth));
    }
  }

  int _widestName(List<MigrationStatus> report) {
    var widest = 'Migration'.length;
    for (final entry in report) {
      if (entry.name.length > widest) widest = entry.name.length;
    }
    return widest;
  }

  String _formatRow(MigrationStatus entry, int nameWidth) {
    final batch = entry.batch?.toString() ?? '-';
    final marker = entry.state == MigrationState.applied ? '[x]' : '[ ]';
    return '$marker ${_row(entry.name, batch, entry.state.name, nameWidth)}';
  }

  String _row(String name, String batch, String status, int nameWidth) =>
      '${name.padRight(nameWidth)} | ${batch.padRight(5)} | $status';
}
