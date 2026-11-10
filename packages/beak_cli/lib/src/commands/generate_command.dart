import 'dart:io';

import 'package:args/command_runner.dart';

import '../cli_runner.dart';
import '../serverpod/generate_issue.dart';
import '../serverpod/generator.dart';

/// Generates the schema package from the Serverpod models and the inventory.
///
/// `beak generate --project apps/shop_admin` reads the `serverpod:` and
/// `generate:` sections of that project's `beak.yaml`, the models under the
/// server, the newest migration and every inventory file, and writes one
/// self-contained library per admitted model into the output package. The
/// output package's `lib/` belongs to this command: a changed file is
/// rewritten, a generated file nothing produces any more is deleted, and a
/// file without the generated header stops the run instead of being touched.
///
/// `--check` writes nothing and exits non-zero when the output is stale,
/// missing a file or holds an orphan, which is what CI runs.
final class GenerateCommand extends Command<int> {
  /// Creates the command against [environment].
  GenerateCommand(this.environment) {
    argParser
      ..addOption(
        'project',
        help: 'The panel package whose beak.yaml configures the run.',
        valueHelp: 'path',
      )
      ..addFlag(
        'check',
        help: 'Write nothing; fail when the generated package is stale.',
        negatable: false,
      );
  }

  /// The injected seams.
  final BeakCliEnvironment environment;

  @override
  String get name => 'generate';

  @override
  String get description =>
      'Generate the admin schema package from a Serverpod server and the '
      'reviewed inventory.';

  @override
  String get invocation => 'beak generate [--project <path>] [--check]';

  @override
  Future<int> run() async {
    final args = argResults!;
    try {
      final result = runServerpodGenerate(
        environment,
        project: args['project'] as String?,
        check: args['check'] == true,
      );
      final out = environment.out;
      for (final warning in result.warnings) {
        out.writeln('warning: $warning');
      }
      if (args['check'] == true) {
        if (result.isSuccess) {
          out.writeln('beak generate: generated files are up to date.');
        } else {
          out.writeln('beak generate --check failed:');
          for (final problem in result.problems) {
            out.writeln('  $problem');
          }
        }
      } else {
        out
          ..writeln(
            'beak generate: ${result.written.length} written, '
            '${result.unchanged.length} unchanged.',
          )
          ..writeAll([for (final problem in result.problems) '  $problem\n']);
      }
      return result.exitCode;
    } on BeakGenerateException catch (error) {
      for (final issue in error.issues) {
        environment.out.writeln('beak generate: $issue');
      }
      return 1;
    } on FileSystemException catch (error) {
      environment.out.writeln('beak generate: ${error.message}');
      return 1;
    }
  }
}
