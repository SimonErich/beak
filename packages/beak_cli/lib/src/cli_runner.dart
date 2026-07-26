import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'commands/create_command.dart';
import 'commands/dev_command.dart';
import 'commands/doctor_command.dart';
import 'commands/introspect_command.dart';
import 'commands/prepare_command.dart';
import 'field_spec.dart';
import 'project/beak_emitters.dart';
import 'templates.dart';

/// A TCP reachability probe over a host and port.
///
/// Returns `true` when a connection to `host:port` succeeds within the
/// probe's timeout. Injected into [BeakCliEnvironment] so `beak doctor` can
/// be tested without touching the network — production uses
/// [BeakCliEnvironment.production], which probes with a real socket.
typedef BeakPortProbe = Future<bool> Function(String host, int port);

/// Runs an external command, returning its exit code.
///
/// Injected so commands that shell out — `beak create` calling
/// `flutter create` for the web scaffold, `beak dev` starting the server —
/// stay unit-testable without spawning real processes.
typedef BeakProcessRunner =
    Future<int> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

/// The injectable seams every command runs against — the output sink, the
/// target directory, the clock behind migration timestamps, and the network
/// probe behind `beak doctor`.
///
/// Injecting these keeps commands deterministic and side-effect-free under
/// test; production wiring lives in [BeakCliEnvironment.production].
///
/// ```dart
/// final env = BeakCliEnvironment(
///   out: StringBuffer(),
///   rootDirectory: Directory.systemTemp.createTempSync('beak'),
///   now: () => DateTime.utc(2026, 7, 3, 12),
///   probe: (host, port) async => false,
/// );
/// await createBeakRunner(env).run(['make:model', 'Product']);
/// ```
final class BeakCliEnvironment {
  /// Creates an environment from explicit seams.
  ///
  /// Prefer [BeakCliEnvironment.production] outside tests.
  BeakCliEnvironment({
    required this.out,
    required this.rootDirectory,
    required this.now,
    required this.probe,
    BeakProcessRunner? runProcess,
  }) : runProcess = runProcess ?? _neverRunsProcesses;

  /// The sink command progress and generated-file logs are written to.
  final StringSink out;

  /// The project directory generated files are written under, and the root
  /// `beak doctor` inspects.
  final Directory rootDirectory;

  /// The clock read once per command to build the migration timestamp
  /// prefix, so scaffolded migration names are reproducible under test.
  final DateTime Function() now;

  /// The reachability probe `beak doctor` uses to check Postgres and MinIO.
  final BeakPortProbe probe;

  /// Spawns external commands. Defaults to a runner that refuses to spawn
  /// anything, so a test that does not opt in cannot start a real process by
  /// accident.
  final BeakProcessRunner runProcess;

  /// The default runner: reports the command it declined to run.
  static Future<int> _neverRunsProcesses(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async => 127;

  /// Creates the default environment: writes to `stdout`, generates under
  /// the current directory, reads the wall clock, and probes ports with a
  /// real 2-second TCP connect.
  ///
  /// ```dart
  /// final runner = createBeakRunner(BeakCliEnvironment.production());
  /// await runner.run(args);
  /// ```
  factory BeakCliEnvironment.production() => BeakCliEnvironment(
    out: stdout,
    rootDirectory: Directory.current,
    now: DateTime.now,
    runProcess: (executable, arguments, {workingDirectory}) async {
      final result = await Process.run(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        runInShell: true,
      );
      return result.exitCode;
    },
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

  /// Writes [content] to [path], creating any missing parent directories, and
  /// logs a `created` line naming the path to [out]. Overwrites an existing
  /// file at that path.
  ///
  /// A relative [path] resolves under [rootDirectory]; an absolute one is used
  /// as given, so `--out /somewhere/else` means what it says rather than
  /// quietly landing inside the project.
  void writeFile(String path, String content) {
    final file = File(
      p.isAbsolute(path) ? path : p.join(rootDirectory.path, path),
    );
    file.parent.createSync(recursive: true);
    // Dart output goes through the same formatter the emitters use, so
    // `dart format --set-exit-if-changed` on a scaffolded project is a no-op
    // rather than a diff the user did not write.
    file.writeAsStringSync(
      path.endsWith('.dart') ? BeakEmitters.format(content) : content,
    );
    out.writeln('  created $path');
  }
}

/// Builds the `beak` [CommandRunner] with every scaffolding command
/// (`make:resource`, `make:model`, `make:columns`, `make:migration`) and
/// `doctor` registered against [environment].
///
/// The returned runner's `run` completes with the process exit code (or
/// `null` for `--help`); it throws [UsageException] on bad input, which the
/// `bin/beak.dart` entry point catches to exit `64`.
///
/// ```dart
/// final runner = createBeakRunner(BeakCliEnvironment.production());
/// final int code = await runner.run([
///   'make:resource',
///   'Product',
///   '--fields',
///   'name:string,price:decimal',
/// ]) ?? 0;
/// ```
CommandRunner<int> createBeakRunner(BeakCliEnvironment environment) =>
    CommandRunner<int>(
        'beak',
        'Beak — scaffold, generate, and diagnose admin panels.',
      )
      ..addCommand(CreateCommand(environment))
      ..addCommand(PrepareCommand(environment))
      ..addCommand(DevCommand(environment))
      ..addCommand(IntrospectCommand(environment))
      ..addCommand(MigrateCommand(environment))
      ..addCommand(SeedCommand(environment))
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

/// The `beak make:resource Name --fields ...` command — the full scaffold.
///
/// Writes three files under [BeakCliEnvironment.rootDirectory]: the worm
/// model (`lib/models/<snake>.dart`), the Beak columns + model
/// (`lib/models/<snake>_columns.dart`), and the create-table migration
/// (`lib/migrations/create_<table>_table.dart`), then prints the manual
/// registration steps. Registered on the runner by [createBeakRunner]; run
/// it rather than constructing it directly.
///
/// ```console
/// $ beak make:resource Product \
///     --fields name:string,price:decimal,active:bool
/// ```
final class MakeResourceCommand extends _MakeCommand {
  /// Creates the command bound to [environment].
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
      ..writeFile('lib/models/$snake.dart', generateWormModel(resource, specs))
      ..writeFile(
        'lib/models/${snake}_columns.dart',
        generateBeakColumns(resource, specs),
      )
      ..writeFile(
        'lib/migrations/create_${tableNameOf(resource)}_table.dart',
        generateMigration(resource, specs, timestamp: stamp),
      )
      // Nothing to register: `beak prepare` discovers both directories.
      ..out.writeln('Next: run `beak prepare` (or `beak dev`) to wire it up.');
    return 0;
  }
}

/// The `beak make:model Name --fields ...` command — generates only the
/// canonical worm model (`lib/models/<snake>.dart`), leaving columns
/// and migration untouched. The narrow counterpart of
/// [MakeResourceCommand].
final class MakeModelCommand extends _MakeCommand {
  /// Creates the command bound to [environment].
  MakeModelCommand(super.environment);

  @override
  String get name => 'make:model';

  @override
  String get description => 'Scaffold a canonical worm model.';

  @override
  Future<int> run() async {
    final String resource = resourceName();
    environment.writeFile(
      'lib/models/${snakeCaseOf(resource)}.dart',
      generateWormModel(resource, fields()),
    );
    return 0;
  }
}

/// The `beak make:columns Name --fields ...` command — generates only the
/// Beak columns class and `BeakModel`
/// (`lib/models/<snake>_columns.dart`), the define-once definition both
/// the server and the Flutter panel consume. The narrow counterpart of
/// [MakeResourceCommand].
final class MakeColumnsCommand extends _MakeCommand {
  /// Creates the command bound to [environment].
  MakeColumnsCommand(super.environment);

  @override
  String get name => 'make:columns';

  @override
  String get description => 'Scaffold Beak columns and the BeakModel.';

  @override
  Future<int> run() async {
    final String resource = resourceName();
    environment.writeFile(
      'lib/models/${snakeCaseOf(resource)}_columns.dart',
      generateBeakColumns(resource, fields()),
    );
    return 0;
  }
}

/// The `beak make:migration Name --fields ...` command — generates only the
/// create-table worm migration (`lib/migrations/create_<table>_table.dart`),
/// its name prefixed with a timestamp from [BeakCliEnvironment.now]. The
/// narrow counterpart of [MakeResourceCommand]; remember to register the
/// migration in `bin/worm.dart`.
final class MakeMigrationCommand extends _MakeCommand {
  /// Creates the command bound to [environment].
  MakeMigrationCommand(super.environment);

  @override
  String get name => 'make:migration';

  @override
  String get description => 'Scaffold the create-table worm migration.';

  @override
  Future<int> run() async {
    final String resource = resourceName();
    environment.writeFile(
      'lib/migrations/create_${tableNameOf(resource)}_table.dart',
      generateMigration(resource, fields(), timestamp: timestamp()),
    );
    return 0;
  }
}
