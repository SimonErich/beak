/// `worm make:observer` command.
library;

import '../cli_naming.dart';
import '../templates.dart';
import '../worm_command_runner.dart';

/// Generate an `Observer` subclass under `lib/src/observer/`.
final class MakeObserverCommand extends WormCommand {
  /// Creates a [MakeObserverCommand].
  MakeObserverCommand(super.context) {
    argParser.addOption(
      'model',
      abbr: 'm',
      help:
          'Model class the observer watches. '
          'Defaults to the class name with the "Observer" suffix '
          'stripped, mirroring make:factory.',
    );
  }

  @override
  String get name => 'make:observer';

  @override
  String get description => 'Generate an Observer subclass skeleton.';

  @override
  String get invocation =>
      'worm make:observer <ClassName> [--model <ModelClass>]';

  @override
  Future<int> run() async {
    final results = argResults;
    if (results == null || results.rest.isEmpty) {
      context.err.writeln('error: observer class name is required');
      return 64;
    }
    final className = results.rest.first;
    final modelClass = results.option('model') ?? _deriveModel(className);
    final path =
        '${context.projectRoot.path}/lib/src/observer/'
        '${pascalToSnake(className)}.dart';
    return writeFile(
      path,
      observerTemplate(className: className, modelClass: modelClass),
    );
  }

  /// Strips a trailing `Observer` suffix from [className] to derive a
  /// best-effort model class name. `UserObserver` → `User`. Mirrors
  /// the `make:factory` behaviour.
  String _deriveModel(String className) {
    const suffix = 'Observer';
    if (className.length > suffix.length && className.endsWith(suffix)) {
      return className.substring(0, className.length - suffix.length);
    }
    return className;
  }
}
