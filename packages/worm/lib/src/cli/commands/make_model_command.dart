/// `worm make:model` command.
library;

import '../cli_naming.dart';
import '../templates.dart';
import '../worm_command_runner.dart';

/// Generates a model class, optionally with migration / seeder /
/// factory companions via `--all`.
final class MakeModelCommand extends WormCommand {
  /// Creates a [MakeModelCommand].
  MakeModelCommand(super.context) {
    argParser.addFlag(
      'all',
      abbr: 'a',
      help: 'Also generate a migration, seeder, and factory.',
      negatable: false,
    );
  }

  @override
  String get name => 'make:model';

  @override
  String get description => 'Generate a model class. Use --all for siblings.';

  @override
  String get invocation => 'worm make:model <ClassName> [--all]';

  @override
  Future<int> run() async {
    final results = argResults;
    if (results == null || results.rest.isEmpty) {
      context.err.writeln('error: model class name is required');
      return 64;
    }
    final className = results.rest.first;
    final table = tableNameFor(className);
    final plan = _planPaths(className, table, all: results.flag('all'));
    for (final p in plan) {
      if (reportIfExists(p.path)) return 65;
    }
    for (final p in plan) {
      await writeFileUnchecked(p.path, p.content);
    }
    return 0;
  }

  List<_TargetFile> _planPaths(
    String className,
    String table, {
    required bool all,
  }) {
    final out = <_TargetFile>[
      _TargetFile(
        path: '${context.modelsDir.path}/${pascalToSnake(className)}.dart',
        content: modelTemplate(className: className, table: table),
      ),
    ];
    if (all) {
      out.addAll(_siblingPlan(className, table));
    }
    return out;
  }

  List<_TargetFile> _siblingPlan(String className, String table) {
    final timestamp = migrationTimestamp(context.now());
    final fileBase = '${timestamp}_create_${table}_table';
    return <_TargetFile>[
      _TargetFile(
        path: '${context.migrationsDir.path}/$fileBase.dart',
        content: migrationTemplate(
          className: 'Create${className}sTable',
          table: table,
          fileName: fileBase,
        ),
      ),
      _TargetFile(
        path:
            '${context.seedsDir.path}/${pascalToSnake(className)}_seeder.dart',
        content: seederTemplate(className: '${className}Seeder', table: table),
      ),
      _TargetFile(
        path:
            '${context.factoriesDir.path}/'
            '${pascalToSnake(className)}_factory.dart',
        content: factoryTemplate(
          className: '${className}Factory',
          modelClass: className,
        ),
      ),
    ];
  }
}

class _TargetFile {
  const _TargetFile({required this.path, required this.content});
  final String path;
  final String content;
}
