import 'dart:io';

import 'package:args/command_runner.dart';

import 'field_spec.dart';
import 'templates.dart';

/// Reachability probe over host/port, injectable for tests.
typedef BeakPortProbe = Future<bool> Function(String host, int port);

/// The seams every command runs against — output sink, target directory,
/// clock, and network probe are all injectable so tests never touch the
/// real world.
final class BeakCliEnvironment {
  /// Creates the environment commands run in.
  BeakCliEnvironment({
    required this.out,
    required this.rootDirectory,
    required this.now,
    required this.probe,
  });

  /// Where command output goes.
  final StringSink out;

  /// The project directory files are generated into.
  final Directory rootDirectory;

  /// The clock behind migration timestamps.
  final DateTime Function() now;

  /// The reachability probe behind `beak doctor`.
  final BeakPortProbe probe;

  /// The default environment: stdout, the current directory, the wall
  /// clock, and real TCP probes.
  factory BeakCliEnvironment.production() => BeakCliEnvironment(
    out: stdout,
    rootDirectory: Directory.current,
    now: DateTime.now,
    probe: (host, port) async {
      try {
        final socket = await Socket.connect(
          host,
          port,
          timeout: const Duration(seconds: 2),
        );
        await socket.close();
        return true;
      } on Object {
        return false;
      }
    },
  );

  /// Writes [content] to [relativePath] under the root, creating parent
  /// directories, and logs the path.
  void writeFile(String relativePath, String content) {
    final file = File('${rootDirectory.path}/$relativePath');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    out.writeln('  created $relativePath');
  }
}

/// The `beak` command runner with every scaffolding command registered.
CommandRunner<int> createBeakRunner(BeakCliEnvironment environment) =>
    CommandRunner<int>(
        'beak',
        'Beak scaffolding — generate models, columns, and migrations.',
      )
      ..addCommand(MakeResourceCommand(environment))
      ..addCommand(MakeModelCommand(environment))
      ..addCommand(MakeColumnsCommand(environment))
      ..addCommand(MakeMigrationCommand(environment))
      ..addCommand(DoctorCommand(environment));

/// Shared argument handling of the `make:*` commands.
abstract base class _MakeCommand extends Command<int> {
  _MakeCommand(this.environment) {
    argParser.addOption(
      'fields',
      help:
          'Comma-separated name:kind pairs '
          '(string|text|int|decimal|bool|datetime).',
      defaultsTo: '',
    );
  }

  /// The seams this command runs against.
  final BeakCliEnvironment environment;

  /// The `UpperCamelCase` resource name argument.
  String resourceName() {
    final List<String> rest = argResults?.rest ?? const [];
    if (rest.length != 1 ||
        !RegExp(r'^[A-Z][A-Za-z0-9]*$').hasMatch(rest.single)) {
      throw UsageException(
        'Expected exactly one UpperCamelCase resource name.',
        usage,
      );
    }
    return rest.single;
  }

  /// The parsed `--fields` specs.
  List<BeakFieldSpec> fields() {
    try {
      return BeakFieldSpec.parseList(switch (argResults?['fields']) {
        final String spec => spec,
        _ => '',
      });
    } on FormatException catch (exception) {
      throw UsageException(exception.message, usage);
    }
  }

  /// The migration timestamp prefix derived from the injected clock.
  String timestamp() {
    final DateTime now = environment.now();
    String two(int part) => part.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}'
        '_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}

/// `beak make:resource Name --fields ...` — the full scaffold: worm model,
/// migration, and the Beak columns + model definition.
final class MakeResourceCommand extends _MakeCommand {
  /// Creates the command.
  MakeResourceCommand(super.environment);

  @override
  String get name => 'make:resource';

  @override
  String get description =>
      'Scaffold a full resource: worm model, migration, Beak columns/model.';

  @override
  Future<int> run() async {
    final String resource = resourceName();
    final List<BeakFieldSpec> specs = fields();
    final String snake = snakeCaseOf(resource);
    final String stamp = timestamp();
    environment
      ..out.writeln('Scaffolding $resource:')
      ..writeFile(
        'lib/src/models/$snake.dart',
        generateWormModel(resource, specs),
      )
      ..writeFile(
        'lib/src/models/${snake}_columns.dart',
        generateBeakColumns(resource, specs),
      )
      ..writeFile(
        'lib/src/migrations/create_${tableNameOf(resource)}_table.dart',
        generateMigration(resource, specs, timestamp: stamp),
      )
      ..out.writeln(
        'Next: register the migration in bin/worm.dart and the model in '
        'your BeakModelRegistry / BeakPanelConfig.',
      );
    return 0;
  }
}

/// `beak make:model Name --fields ...` — the worm model only.
final class MakeModelCommand extends _MakeCommand {
  /// Creates the command.
  MakeModelCommand(super.environment);

  @override
  String get name => 'make:model';

  @override
  String get description => 'Scaffold a canonical worm model.';

  @override
  Future<int> run() async {
    final String resource = resourceName();
    environment.writeFile(
      'lib/src/models/${snakeCaseOf(resource)}.dart',
      generateWormModel(resource, fields()),
    );
    return 0;
  }
}

/// `beak make:columns Name --fields ...` — the Beak columns + model only.
final class MakeColumnsCommand extends _MakeCommand {
  /// Creates the command.
  MakeColumnsCommand(super.environment);

  @override
  String get name => 'make:columns';

  @override
  String get description => 'Scaffold Beak columns and the BeakModel.';

  @override
  Future<int> run() async {
    final String resource = resourceName();
    environment.writeFile(
      'lib/src/models/${snakeCaseOf(resource)}_columns.dart',
      generateBeakColumns(resource, fields()),
    );
    return 0;
  }
}

/// `beak make:migration Name --fields ...` — the worm migration only.
final class MakeMigrationCommand extends _MakeCommand {
  /// Creates the command.
  MakeMigrationCommand(super.environment);

  @override
  String get name => 'make:migration';

  @override
  String get description => 'Scaffold the create-table worm migration.';

  @override
  Future<int> run() async {
    final String resource = resourceName();
    environment.writeFile(
      'lib/src/migrations/create_${tableNameOf(resource)}_table.dart',
      generateMigration(resource, fields(), timestamp: timestamp()),
    );
    return 0;
  }
}

/// `beak doctor` — checks the vendored paths, env file, and Docker
/// services this repo expects.
final class DoctorCommand extends Command<int> {
  /// Creates the command.
  DoctorCommand(this.environment);

  /// The seams this command runs against.
  final BeakCliEnvironment environment;

  @override
  String get name => 'doctor';

  @override
  String get description =>
      'Check worm/obers_ui paths, the env file, and Docker services.';

  @override
  Future<int> run() async {
    var healthy = true;
    void report(String label, bool ok) {
      environment.out.writeln('  ${ok ? 'OK  ' : 'FAIL'} $label');
      healthy = healthy && ok;
    }

    final String root = environment.rootDirectory.path;
    report('worm vendored', Directory('$root/packages/worm').existsSync());
    report(
      'obers_ui reachable',
      Directory('$root/../obers_ui').existsSync() ||
          Directory('$root/packages/obers_ui').existsSync(),
    );
    report(
      '.env present (.env.example to copy)',
      File('$root/.env').existsSync(),
    );
    report('postgres :25432', await environment.probe('localhost', 25432));
    report('minio :29000', await environment.probe('localhost', 29000));
    environment.out.writeln(
      healthy ? 'All checks passed.' : 'Some checks failed.',
    );
    return healthy ? 0 : 1;
  }
}
