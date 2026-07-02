/// `worm make:factory` command.
library;

import '../cli_naming.dart';
import '../templates.dart';
import '../worm_command_runner.dart';

/// Generate a factory file under `lib/factories/`.
final class MakeFactoryCommand extends WormCommand {
  /// Creates a [MakeFactoryCommand].
  MakeFactoryCommand(super.context) {
    argParser.addOption(
      'model',
      abbr: 'm',
      help:
          'Model class the factory builds. '
          'Defaults to the class name with the "Factory" suffix '
          'stripped, mirroring make:observer.',
    );
  }

  @override
  String get name => 'make:factory';

  @override
  String get description => 'Generate a Factory subclass skeleton.';

  @override
  String get invocation =>
      'worm make:factory <ClassName> [--model <ModelClass>]';

  @override
  Future<int> run() async {
    final results = argResults;
    if (results == null || results.rest.isEmpty) {
      context.err.writeln('error: factory class name is required');
      return 64;
    }
    final className = results.rest.first;
    final modelClass = results.option('model') ?? _deriveModel(className);
    final path =
        '${context.factoriesDir.path}/${pascalToSnake(className)}.dart';
    return writeFile(
      path,
      factoryTemplate(className: className, modelClass: modelClass),
    );
  }

  /// Strips a trailing `Factory` suffix from [className] to derive a
  /// best-effort model class name. `UserFactory` → `User`. Falls
  /// back to [className] when no suffix is present so the template
  /// still compiles (Factory needs a type argument). Mirrors the
  /// `make:observer` behaviour.
  String _deriveModel(String className) {
    const suffix = 'Factory';
    if (className.length > suffix.length && className.endsWith(suffix)) {
      return className.substring(0, className.length - suffix.length);
    }
    return className;
  }
}
