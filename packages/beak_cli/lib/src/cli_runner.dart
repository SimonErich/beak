import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'commands/agents_command.dart';
import 'commands/create_command.dart';
import 'commands/dev_command.dart';
import 'commands/docs_command.dart';
import 'commands/doctor_command.dart';
import 'commands/eject_command.dart';
import 'commands/init_command.dart';
import 'commands/introspect_command.dart';
import 'commands/prepare_command.dart';
import 'field_spec.dart';
import 'introspect/beak_live_schema.dart';
import 'introspect/beak_schema_introspection.dart';
import 'project/beak_authored_main.dart';
import 'project/beak_emitters.dart';
import 'project/beak_project_config.dart';
import 'schema/beak_drift_migration_emitter.dart';
import 'schema/beak_schema_drift.dart';
import 'schema/beak_schema_reader.dart';
import 'templates.dart';
import 'version.dart';

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
    BeakProcessRunner? runInteractive,
    this.processEnvironment = const {},
  }) : runProcess = runProcess ?? _neverRunsProcesses,
       runInteractive = runInteractive ?? runProcess ?? _neverRunsProcesses;

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

  /// Spawns an external command that talks to the person at the terminal.
  ///
  /// Its output goes straight to the terminal, as does its input, so the
  /// migrations report what they applied, the dev server logs its requests and
  /// `flutter pub get` shows its progress. [runProcess] is for commands whose
  /// output is noise. Falls back to [runProcess] when not given, so a test
  /// that records one runner sees every command.
  final BeakProcessRunner runInteractive;

  /// The variables the process was started with.
  ///
  /// Empty unless given, so a test never reads the machine's own environment;
  /// [BeakCliEnvironment.production] passes the real one. Settings are read
  /// through `BeakDotenv`, the way the server reads them: the project's `.env`
  /// under these, which win.
  final Map<String, String> processEnvironment;

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
    processEnvironment: Platform.environment,
    runProcess: (executable, arguments, {workingDirectory}) async {
      final result = await Process.run(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        runInShell: true,
      );
      return result.exitCode;
    },
    runInteractive: (executable, arguments, {workingDirectory}) async {
      final process = await Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        runInShell: true,
        mode: ProcessStartMode.inheritStdio,
      );
      return process.exitCode;
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
/// [environment]: `create`, `init`, `prepare`, `dev`, `introspect`, `eject`,
/// `docs`, `agents`, `migrate`, `seed`, `make:resource`, `make:migration`
/// and `doctor`.
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
    _BeakCommandRunner(environment)
      ..addCommand(CreateCommand(environment))
      ..addCommand(PrepareCommand(environment))
      ..addCommand(DevCommand(environment))
      ..addCommand(IntrospectCommand(environment))
      ..addCommand(
        InitCommand(
          environment,
          refreshAgentFiles: (env) async =>
              refreshAgentFiles(env, installSkills: true),
        ),
      )
      ..addCommand(DocsCommand(environment))
      ..addCommand(AgentsCommand(environment))
      ..addCommand(EjectCommand(environment))
      ..addCommand(MigrateCommand(environment))
      ..addCommand(SeedCommand(environment))
      ..addCommand(MakeResourceCommand(environment))
      ..addCommand(MakeMigrationCommand(environment))
      ..addCommand(DoctorCommand(environment));

/// The `beak` runner: the commands, plus the top-level `--version` flag.
final class _BeakCommandRunner extends CommandRunner<int> {
  _BeakCommandRunner(this.environment)
    : super('beak', 'Beak: scaffold, generate, and diagnose admin panels.') {
    argParser.addFlag(
      'version',
      help: 'Print the beak version and exit.',
      negatable: false,
    );
  }

  /// Where `--version` prints.
  final BeakCliEnvironment environment;

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults.flag('version')) {
      environment.out.writeln('beak $beakCliVersion');
      return 0;
    }
    try {
      return await super.runCommand(topLevelResults);
    } on BeakProjectConfigException catch (exception) {
      // A `beak.yaml` the commands cannot read is the project's mistake, not
      // the tool's: say which key or line, rather than a stack trace.
      environment.out.writeln(exception);
      return 1;
    }
  }
}

/// Shared argument handling of the `make:*` commands.
abstract base class _MakeCommand extends Command<int> {
  _MakeCommand(this.environment) {
    argParser.addOption(
      'fields',
      help:
          'Comma-separated name:kind pairs '
          '(string|text|int|decimal|double|bool|datetime).',
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
/// Writes two files under [BeakCliEnvironment.rootDirectory], in the feature
/// folder of the resource's table: the annotated schema class at
/// `lib/resources/<plural>/models/<snake>.dart`, and the `BeakResource` class
/// presenting it at `lib/resources/<plural>/<snake>_resource.dart`. Then it
/// runs `beak prepare`, which derives the columns, the model, both sides of
/// every relationship, the panel wiring and the create-table migration from
/// the schema. `--fields` is written once, so there is no second place for
/// the field list to drift out of step. In a project whose `lib/main.dart`
/// is authored, it prints the line that registers the new class there.
/// Registered on the runner by [createBeakRunner]; run it rather than
/// constructing it directly.
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
      'Scaffold a resource: its schema class and its resource class.';

  @override
  Future<int> run() async {
    final String resource = resourceName();
    final String snake = snakeCaseOf(resource);
    final String table = tableNameOf(resource);
    final String folder = 'lib/resources/$table';
    final String schemaPath = '$folder/models/$snake.dart';
    final String resourcePath = '$folder/${snake}_resource.dart';
    final BeakProjectConfig config = BeakProjectConfig.load(
      environment.rootDirectory,
      packageName: BeakProjectConfig.packageNameOf(environment.rootDirectory),
    );
    // Before anything is written: a resource scaffolded into a directory that
    // is not a Beak project has nothing to generate it and nowhere to run.
    if (beakNotAProject(environment.rootDirectory, config)
        case final String reason) {
      environment.out.writeln('  $reason');
      return 1;
    }
    final String entrypoint = config.panel.entrypointPath;
    final File entrypointFile = File(
      p.join(environment.rootDirectory.path, entrypoint),
    );
    // The panel's entrypoint is `lib/main.dart`, or the file `beak.yaml` names
    // in an app that embeds the panel; either is the project's own once Beak
    // did not write it.
    final String? entrypointSource = entrypointFile.existsSync()
        ? entrypointFile.readAsStringSync()
        : null;
    final bool authored =
        entrypointSource != null &&
        !entrypointSource.startsWith(BeakAuthoredMain.generatedMarker);
    for (final path in [schemaPath, resourcePath]) {
      if (File(p.join(environment.rootDirectory.path, path)).existsSync()) {
        environment.out.writeln(
          '  $path already exists: pick another name, or edit it',
        );
        return 1;
      }
    }
    environment
      ..writeFile(schemaPath, generateSchemaClass(resource, fields()))
      ..writeFile(
        resourcePath,
        generateResourceClass(
          className: '${resource}Resource',
          modelClass: '${resource}Model',
          modelImport: 'models/$snake.dart',
          table: table,
          authored: authored,
        ),
      );
    final int exitCode = runPrepare(environment).exitCode;
    if (authored) {
      // `prepare` never touches an authored entrypoint, so the class is not
      // in the panel until someone adds it. Inside a `const` list a second
      // `const` is a lint, so the line matches where it will be pasted.
      final bool isConstantList = BeakAuthoredMain.parse(
        entrypointSource,
      ).resourcesAreConstant;
      final String importPath = p.posix.relative(
        resourcePath,
        from: p.posix.dirname(entrypoint),
      );
      environment.out
        ..writeln()
        ..writeln('  $entrypoint is yours; register the resource there:')
        ..writeln("    import '$importPath';")
        ..writeln(
          '    ${isConstantList ? '' : 'const '}${resource}Resource(),'
          '  // in resources: [...]',
        );
    }
    return exitCode;
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
  ///
  /// [readSchema] is how `--from-drift` reads the live schema; tests pass
  /// their own so the command runs without a database.
  MakeMigrationCommand(this.environment, {BeakLiveSchemaReader? readSchema})
    : _readSchema = readSchema ?? beakReadLiveSchema {
    argParser
      ..addFlag(
        'from-drift',
        help:
            'Fill the migration in from the difference between the schema '
            'classes and the database.',
        negatable: false,
      )
      ..addFlag(
        'force',
        help: 'Replace the file if a migration of this name already exists.',
        negatable: false,
      );
  }

  /// The seams this command runs against.
  final BeakCliEnvironment environment;

  /// How `--from-drift` reads the live schema.
  final BeakLiveSchemaReader _readSchema;

  @override
  String get name => 'make:migration';

  @override
  String get description => 'Scaffold an empty, correctly-named migration.';

  @override
  String get invocation =>
      'beak make:migration <Name> [--from-drift] [--force]';

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
    if (_refusesToReplace('lib/migrations/$snake.dart')) {
      return 1;
    }
    if (argResults?['from-drift'] == true) {
      return _writeFromDrift(className: className, snake: snake, stamp: stamp);
    }
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

  /// Whether [path] holds a migration already and `--force` did not say to
  /// replace it, having said so.
  ///
  /// A migration is the project's the moment it is written, and often edited
  /// before it has run; scaffolding over it once more would lose that work.
  bool _refusesToReplace(String path) {
    final file = File(p.join(environment.rootDirectory.path, path));
    if (file.existsSync() && argResults?['force'] != true) {
      environment.out.writeln(
        '  $path already exists: pick another name, or pass --force to '
        'replace it',
      );
      return true;
    }
    return false;
  }

  /// Writes the migration the live database needs to match the models.
  ///
  /// The columns come from drift rather than from reading the migrations,
  /// because a Beak migration derives its columns from the model at runtime
  /// and never names them. Only a column a field declares is written: the
  /// rest of what drift reports needs a decision, not a column.
  Future<int> _writeFromDrift({
    required String className,
    required String snake,
    required String stamp,
  }) async {
    final Directory root = environment.rootDirectory;
    final (schemas, schemaIssues) = BeakSchemaReader(root).read();
    if (schemaIssues.isNotEmpty) {
      environment.out.writeln('Cannot read the schema classes:');
      for (final issue in schemaIssues) {
        environment.out.writeln('  ${issue.path}: ${issue.message}');
      }
      return 1;
    }

    final Uri url =
        beakDatabaseUrlOf(
          root,
          processEnvironment: environment.processEnvironment,
        ) ??
        Uri.parse(defaultSqliteUrl);
    if (!beakCanReadSchema(url)) {
      // Without this, `sqlite::memory:` fell through to the Postgres reader
      // and surfaced as a socket error on port 0.
      environment.out.writeln(
        beakIsSqliteUrl(url)
            ? 'The database is in-memory SQLite, which belongs to the process '
                  'that opened it; there is no schema on disk to compare '
                  'against.'
            : 'Beak can read Postgres and SQLite schemas; "${url.scheme}" is '
                  'not supported yet.',
      );
      return 1;
    }
    if (beakSqliteFileOf(url) != null && !beakSqliteFileExists(url, root)) {
      // Opening a SQLite file creates it, so looking would leave an empty
      // database behind and then report that it lacks nothing.
      environment.out.writeln(
        'There is no database yet, so there is nothing to compare the schema '
        'classes against.',
      );
      environment.out.writeln('  run `beak migrate` first');
      return 1;
    }
    final List<IntrospectedTable> tables;
    try {
      tables = await _readSchema(beakResolvedDatabaseUrl(url, root));
    } catch (error) {
      environment.out.writeln('Could not read the database schema: $error');
      return 1;
    }

    final List<BeakDrift> drift = beakSchemaDrift(
      schemas: schemas,
      tables: tables,
    );
    final String? contents = BeakDriftMigrationEmitter.emit(
      className: className,
      timestamp: stamp,
      description: _sentenceOf(snake),
      drift: drift,
    );
    // Report what cannot be written before deciding there is nothing to do:
    // "no drift" and "drift no migration can express" are different answers,
    // and conflating them tells someone their schema is applied when it is
    // not.
    final refusals = BeakDriftMigrationEmitter.unaddable(drift);
    for (final MapEntry(key: problem, value: why) in refusals.entries) {
      environment.out.writeln(
        '  ! ${problem.table}.${problem.columnKey}: $why',
      );
    }
    if (contents == null) {
      environment.out.writeln(
        refusals.isEmpty
            ? '  nothing to add: the database already has every column the '
                  'schema classes declare'
            : '  nothing written: every missing column needs a decision '
                  'first',
      );
      return refusals.isEmpty ? 0 : 1;
    }
    environment.writeFile('lib/migrations/$snake.dart', contents);
    environment.out.writeln('  run `beak migrate` to apply it');
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
