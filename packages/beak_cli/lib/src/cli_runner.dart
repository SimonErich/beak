import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'commands/create_command.dart';
import 'commands/dev_command.dart';
import 'commands/eject_command.dart';
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
/// await createBeakRunner(env).run(['make:resource', 'Product']);
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

/// Builds the `beak` [CommandRunner] with every command registered against
/// [environment]: `create`, `prepare`, `dev`, `introspect`, `eject`,
/// `migrate`, `seed`, `make:resource`, `make:migration` and `doctor`.
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
      ..addCommand(EjectCommand(environment))
      ..addCommand(MigrateCommand(environment))
      ..addCommand(SeedCommand(environment))
      ..addCommand(MakeResourceCommand(environment))
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
}

/// The `beak make:resource Name --fields ...` command.
///
/// Writes one file under [BeakCliEnvironment.rootDirectory] — the annotated
/// schema class at `lib/models/<snake>.dart` — and then runs `beak prepare`,
/// which derives the columns, the model, both sides of every relationship,
/// the panel wiring and the create-table migration from it. `--fields` is
/// written once, so there is no second place for the field list to drift out
/// of step. Registered on the runner by [createBeakRunner]; run it rather
/// than constructing it directly.
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
  String get description => 'Scaffold a resource: one annotated schema class.';

  @override
  Future<int> run() async {
    final String resource = resourceName();
    // One file, and `--fields` written once. `prepare` derives the columns,
    // the model, both sides of every relationship and the migration from it —
    // so there is no second place for the field list to drift out of step.
    environment.writeFile(
      'lib/models/${snakeCaseOf(resource)}.dart',
      generateSchemaClass(resource, fields()),
    );
    return runPrepare(environment).exitCode;
  }
}

/// The `beak make:migration Name` command — an empty, correctly-named
/// migration for a change `beak prepare` cannot derive.
///
/// `prepare` writes the create-table migration for any model whose table
/// nothing creates, so this is for everything else: adding a column to a
/// shipped table, backfilling data, dropping something. The scaffold gives
/// the timestamped name — worm runs migrations in that order — and leaves
/// the body to you.
///
/// ```console
/// $ beak make:migration AddStatusToProducts
///   created lib/migrations/add_status_to_products.dart
/// ```
final class MakeMigrationCommand extends Command<int> {
  /// Creates the command bound to [environment].
  MakeMigrationCommand(this.environment);

  /// The seams this command runs against.
  final BeakCliEnvironment environment;

  @override
  String get name => 'make:migration';

  @override
  String get description => 'Scaffold an empty, correctly-named migration.';

  @override
  String get invocation => 'beak make:migration <Name>';

  @override
  Future<int> run() async {
    final List<String> rest = argResults?.rest ?? const [];
    if (rest.length != 1 ||
        !RegExp(r'^[A-Z][A-Za-z0-9]*$').hasMatch(rest.single)) {
      throw UsageException(
        'Expected exactly one UpperCamelCase migration name.',
        invocation,
      );
    }
    final String className = rest.single;
    final String snake = snakeCaseOf(className);
    final String stamp = _timestampOf(environment.now());
    environment.writeFile('lib/migrations/$snake.dart', '''
import 'package:beak/migrations.dart';

/// ${_sentenceOf(snake)}.
final class $className extends Migration {
  /// Creates the migration.
  const $className();

  @override
  String get name => '${stamp}_$snake';

  @override
  Future<void> upSchema(Schema schema) async {
    // e.g. await schema.alter('products', (table) {
    //   table.string('status', length: 20).makeNullable();
    // });
  }

  @override
  Future<void> downSchema(Schema schema) async {
    // The inverse of upSchema, so a rollback is not a restore from backup.
  }
}
''');
    return 0;
  }

  /// `20260727_143012`, sortable and readable.
  static String _timestampOf(DateTime at) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${at.year}${two(at.month)}${two(at.day)}_'
        '${two(at.hour)}${two(at.minute)}${two(at.second)}';
  }

  /// `add_status_to_products` -> `Add status to products`.
  static String _sentenceOf(String snake) {
    final String spaced = snake.replaceAll('_', ' ');
    return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }
}
