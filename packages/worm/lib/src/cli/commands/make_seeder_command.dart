/// `worm make:seeder` command.
library;

import '../cli_naming.dart';
import '../templates.dart';
import '../worm_command_runner.dart';

/// Generate a seeder file under `seeds/`.
final class MakeSeederCommand extends WormCommand {
  /// Creates a [MakeSeederCommand].
  MakeSeederCommand(super.context) {
    argParser.addOption(
      'table',
      abbr: 't',
      help: 'Table the seeder writes into (informational).',
    );
  }

  @override
  String get name => 'make:seeder';

  @override
  String get description => 'Generate a Seeder subclass skeleton.';

  @override
  String get invocation => 'worm make:seeder <ClassName> [--table <table>]';

  @override
  Future<int> run() async {
    final results = argResults;
    if (results == null || results.rest.isEmpty) {
      context.err.writeln('error: seeder class name is required');
      return 64;
    }
    final className = results.rest.first;
    final table = results.option('table') ?? pascalToSnake(className);
    final path = '${context.seedsDir.path}/${pascalToSnake(className)}.dart';
    return writeFile(path, seederTemplate(className: className, table: table));
  }
}
