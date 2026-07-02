/// `worm make:migration` command.
library;

import '../../migration/migration_auto_generator.dart';
import '../cli_naming.dart';
import '../templates.dart';
import '../worm_command_runner.dart';

/// Generate a migration file under `migrations/`.
///
/// With `--auto`, the command introspects the live database
/// schema, diffs it against `schema/schema.json`, and writes a
/// migration whose `upSchema(Schema)` body brings the database
/// in line with the target.
final class MakeMigrationCommand extends WormCommand {
  /// Creates a [MakeMigrationCommand].
  MakeMigrationCommand(super.context) {
    argParser
      ..addOption(
        'table',
        abbr: 't',
        help: 'Name of the table the migration targets.',
      )
      ..addFlag(
        'auto',
        help:
            'Generate the body by diffing schema/schema.json against '
            'the live database schema.',
        negatable: false,
      );
  }

  @override
  String get name => 'make:migration';

  @override
  String get description => 'Generate a migration class skeleton.';

  @override
  String get invocation =>
      'worm make:migration <snake_case_name> '
      '[--table <table>] [--auto]';

  @override
  Future<int> run() async {
    final results = argResults;
    if (results == null || results.rest.isEmpty) {
      context.err.writeln('error: migration name is required');
      return 64;
    }
    final baseName = results.rest.first;
    final timestamp = migrationTimestamp(context.now());
    final fileBase = '${timestamp}_$baseName';
    final className = snakeToPascal(baseName);
    final path = '${context.migrationsDir.path}/$fileBase.dart';
    if (results.flag('auto')) {
      return _runAuto(path: path, className: className, fileName: fileBase);
    }
    final tableArg = results.option('table') ?? baseName;
    return writeFile(
      path,
      migrationTemplate(
        className: className,
        table: tableArg,
        fileName: fileBase,
      ),
    );
  }

  Future<int> _runAuto({
    required String path,
    required String className,
    required String fileName,
  }) async {
    if (reportIfExists(path)) return 65;
    final adapter = await context.adapterFactory();
    final generator = MigrationAutoGenerator(
      adapter: adapter,
      projectRoot: context.projectRoot,
    );
    final source = await generator.generate(
      className: className,
      fileName: fileName,
    );
    await writeFileUnchecked(path, source);
    return 0;
  }
}
