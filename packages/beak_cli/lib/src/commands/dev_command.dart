import 'dart:async';

import 'package:args/command_runner.dart';

import '../cli_runner.dart';
import '../project/beak_dotenv.dart';
import '../project/beak_project_config.dart';
import 'prepare_command.dart';

/// Runs a Beak project's backend, after regenerating its wiring.
///
/// The panel is deliberately *not* spawned here. Proxying `flutter run`'s
/// interactive console — raw-mode stdin, interleaved ANSI, correct teardown on
/// Ctrl-C — is the fiddliest part of a dev server and the least testable, and
/// getting it subtly wrong costs more than it saves. `beak dev` regenerates,
/// serves the API, and prints the exact `flutter run` line to paste in a second
/// terminal, which is the part that actually needs automating.
///
/// In an app that embeds the panel, `beak.yaml`'s `panel.entrypoint` names
/// the file that boots it, and the printed line targets that file with `-t`.
///
/// ```console
/// $ beak dev
///   1 model · 0 resource classes · 0 screens · 0 overrides
///   generated  up to date (7 files)
///   panel      run this in another terminal:
///                flutter run -d chrome
///   api        starting…
/// ```
final class DevCommand extends Command<int> {
  /// Creates the command against [environment].
  ///
  /// [startupNoteDelay] is how long the server may take to listen before
  /// `beak dev` says that a first start compiles native code.
  DevCommand(
    this.environment, {
    this.startupNoteDelay = const Duration(seconds: 3),
  }) {
    argParser
      ..addOption(
        'device',
        abbr: 'd',
        help: 'Device the printed `flutter run` line targets.',
        defaultsTo: 'chrome',
      )
      ..addFlag(
        'serve',
        help: 'Start the API. Pass --no-serve to only regenerate.',
        defaultsTo: true,
      );
  }

  /// The injected seams (output sink, project directory, process runner).
  final BeakCliEnvironment environment;

  /// How long to wait for the server to listen before printing the note about
  /// the first start.
  final Duration startupNoteDelay;

  /// The port the server binds when nothing sets one.
  static const int _defaultPort = 8080;

  @override
  String get name => 'dev';

  @override
  String get description =>
      'Regenerate the wiring and serve the API for development.';

  @override
  Future<int> run() async {
    final BeakPrepareResult prepared = runPrepare(environment);
    if (!prepared.isSuccess) {
      return prepared.exitCode;
    }

    final String device = switch (argResults?['device']) {
      final String value => value,
      _ => 'chrome',
    };
    // An app that embeds the panel boots it from a file of its own, and
    // `flutter run` starts `lib/main.dart` unless told otherwise.
    final String? entrypoint = prepared.config.panel.entrypoint;
    environment.out
      ..writeln('  panel      run this in another terminal:')
      ..writeln(
        '               flutter run -d $device'
        '${entrypoint == null ? '' : ' -t $entrypoint'}',
      );

    if (argResults?['serve'] == false) {
      return 0;
    }

    environment.out.writeln('  api        starting…');
    var ended = false;
    final Timer note = Timer(startupNoteDelay, () async {
      final bool listening = await environment.probe(
        'localhost',
        _portOf(prepared.config),
      );
      if (!listening && !ended) {
        environment.out.writeln(
          '  api        still starting (the first run compiles native code, '
          '~30 s)',
        );
      }
    });
    final int exitCode = await environment.runInteractive('dart', const [
      'run',
      'bin/serve.dart',
    ], workingDirectory: environment.rootDirectory.path);
    ended = true;
    note.cancel();
    return exitCode;
  }

  /// The port the server will bind: `PORT` from the environment or `.env`,
  /// then `beak.yaml`, then Beak's default.
  int _portOf(BeakProjectConfig config) =>
      int.tryParse(
        BeakDotenv.resolve(
              environment.rootDirectory,
              processEnvironment: environment.processEnvironment,
            )['PORT'] ??
            '',
      ) ??
      config.server.port ??
      _defaultPort;
}

/// What `beak migrate` can be asked to do, named the way a person says it.
///
/// Each maps to the subcommand of worm's CLI that does it, because
/// `bin/migrate.dart` is that CLI and knows nothing of these words.
enum BeakMigrateVerb {
  // --8<-- [start:BeakMigrateVerb]
  /// Apply the pending migrations.
  up('migrate'),

  /// List which migrations are applied and which are pending.
  status('migrate:status'),

  /// Roll back the latest batch, or `--steps` of them.
  down('migrate:rollback'),

  /// Drop the tables and apply every migration again.
  fresh('migrate:fresh'),

  /// Roll every migration back, then apply them again.
  refresh('migrate:refresh');

  // --8<-- [end:BeakMigrateVerb]

  const BeakMigrateVerb(this.wormCommand);

  /// The worm subcommand this runs.
  final String wormCommand;

  /// Whether this verb drops or rewrites tables, and so needs `--force` in
  /// production.
  bool get isDestructive => this == fresh || this == refresh;

  /// The flags and options this verb takes, by name.
  ///
  /// Worm refuses a flag its subcommand does not know, with its own usage and
  /// exit `2`, so Beak refuses it first, as the usage error it is.
  Set<String> get flags => switch (this) {
    up => const {'pretend', 'step'},
    status => const {},
    down => const {'steps'},
    fresh => const {'seed', 'force'},
    refresh => const {'force'},
  };

  /// Every verb, spelled as typed and separated by [separator].
  static String spellings(String separator) =>
      values.map((verb) => verb.name).join(separator);

  /// The verb spelled [word], or `null` when there is none.
  static BeakMigrateVerb? parse(String word) {
    for (final verb in values) {
      if (verb.name == word) {
        return verb;
      }
    }
    return null;
  }
}

/// A command that hands the rest of its arguments to the project's worm CLI.
///
/// The flags it declares are forwarded by name, and everything after a `--`
/// goes through untouched, so a flag worm has and Beak has not heard of is
/// one `--` away rather than out of reach.
abstract base class _WormPassThroughCommand extends Command<int> {
  _WormPassThroughCommand(this.environment);

  /// The injected seams.
  final BeakCliEnvironment environment;

  /// The names of the options forwarded as `--name=value`, when given.
  List<String> get forwardedOptions;

  /// The names of the flags forwarded as `--name`, when set.
  List<String> get forwardedFlags;

  /// The positional words, before any `--`.
  List<String> get words {
    final List<String> rest = argResults?.rest ?? const [];
    return rest.sublist(0, rest.length - passedThrough.length);
  }

  /// The arguments after `--`, which are not Beak's to interpret.
  List<String> get passedThrough {
    final List<String> arguments = argResults?.arguments ?? const [];
    final int separator = arguments.indexOf('--');
    return separator < 0 ? const [] : arguments.sublist(separator + 1);
  }

  /// Runs worm's [subcommand] with the declared flags and the pass-through.
  Future<int> runWorm(String subcommand) => runProjectCli(environment, [
    subcommand,
    for (final option in forwardedOptions)
      if (argResults?[option] case final String value) '--$option=$value',
    for (final flag in forwardedFlags)
      if (argResults?[flag] == true) '--$flag',
    ...passedThrough,
  ]);
}

/// Runs the project's migrations, after regenerating the wiring.
///
/// A thin pass-through to the project's generated `bin/migrate.dart`, which
/// runs the worm CLI over the same host the server uses, so the schema and the
/// API can never come from different registries. Its output is the terminal's
/// and its exit code is this command's.
///
/// ```console
/// $ beak migrate status
/// $ beak migrate down --steps 2
/// $ beak migrate fresh --seed
/// $ beak migrate --pretend
/// ```
final class MigrateCommand extends _WormPassThroughCommand {
  /// Creates the command against [environment].
  MigrateCommand(super.environment) {
    argParser
      ..addFlag(
        'pretend',
        help: 'Print the SQL without running it (up).',
        negatable: false,
      )
      ..addFlag(
        'seed',
        help: 'Run the seeders afterwards (fresh).',
        negatable: false,
      )
      ..addFlag(
        'force',
        help: 'Allow it when WORM_ENV=production (fresh, refresh).',
        negatable: false,
      )
      ..addOption(
        'step',
        help: 'Apply at most this many migrations (up).',
        valueHelp: 'N',
      )
      ..addOption(
        'steps',
        help: 'Roll back this many batches (down).',
        valueHelp: 'N',
      );
  }

  @override
  String get name => 'migrate';

  @override
  String get description => 'Apply, inspect or roll back migrations.';

  @override
  String get invocation =>
      'beak migrate [${BeakMigrateVerb.spellings('|')}] [--pretend] '
      '[--step N] [--steps N] [--seed] [--force] [-- <worm args>]';

  @override
  List<String> get forwardedOptions => const ['step', 'steps'];

  @override
  List<String> get forwardedFlags => const ['pretend', 'seed', 'force'];

  /// The verbs a flag or option belongs to, for the message that says so.
  static String _homesOf(String name) => BeakMigrateVerb.values
      .where((verb) => verb.flags.contains(name))
      .map((verb) => '`beak migrate ${verb.name}`')
      .join(' or ');

  /// Throws when a flag was passed that [verb] does not take.
  void _requireFlagsOf(BeakMigrateVerb verb) {
    for (final name in ['pretend', 'step', 'steps', 'seed', 'force']) {
      if (!(argResults?.wasParsed(name) ?? false) ||
          verb.flags.contains(name)) {
        continue;
      }
      final String takes = verb.flags.isEmpty
          ? 'takes no flags'
          : 'takes ${(verb.flags.toList()..sort()).map((flag) => '--$flag').join(', ')}';
      throw UsageException(
        '--$name applies to ${_homesOf(name)}, not `beak migrate '
        '${verb.name}`, which $takes.',
        usage,
      );
    }
  }

  @override
  Future<int> run() {
    final List<String> spoken = words;
    if (spoken.length > 1) {
      throw UsageException(
        'Expected at most one of ${BeakMigrateVerb.spellings(', ')}.',
        usage,
      );
    }
    final BeakMigrateVerb? verb = spoken.isEmpty
        ? BeakMigrateVerb.up
        : BeakMigrateVerb.parse(spoken.single);
    if (verb == null) {
      throw UsageException(
        '"${spoken.single}" is not a migrate action; use one of '
        '${BeakMigrateVerb.spellings(', ')}.',
        usage,
      );
    }
    _requireFlagsOf(verb);
    if (verb.isDestructive && argResults?['force'] != true && _isProduction()) {
      environment.out.writeln(
        'error: refusing to run destructive command in production '
        'without --force',
      );
      return Future.value(1);
    }
    return runWorm(verb.wormCommand);
  }

  /// Whether `WORM_ENV` names production, as the server would resolve it.
  ///
  /// Worm's own gate reads the process environment alone, so a `.env` that
  /// says `WORM_ENV=production` armed nothing. The same message and exit code,
  /// decided here from the environment the server resolves.
  bool _isProduction() =>
      BeakDotenv.resolve(
        environment.rootDirectory,
        processEnvironment: environment.processEnvironment,
      )['WORM_ENV']?.trim().toLowerCase() ==
      'production';
}

/// Runs the project's seeders, after regenerating the wiring.
///
/// ```console
/// $ beak seed
/// $ beak seed --class UserSeeder
/// ```
final class SeedCommand extends _WormPassThroughCommand {
  /// Creates the command against [environment].
  SeedCommand(super.environment) {
    argParser
      ..addOption(
        'class',
        help: 'Run only the seeder with this name.',
        valueHelp: 'SeederName',
      )
      ..addOption(
        'env',
        help:
            'Filter the seeders by this environment instead of the active one.',
        valueHelp: 'name',
      )
      ..addFlag(
        'force',
        help: 'Ignore the environment filter and run every seeder.',
        negatable: false,
      );
  }

  @override
  String get name => 'seed';

  @override
  String get description => 'Run the project seeders.';

  @override
  String get invocation =>
      'beak seed [--class <SeederName>] [--env <name>] [--force] '
      '[-- <worm args>]';

  @override
  List<String> get forwardedOptions => const ['class', 'env'];

  @override
  List<String> get forwardedFlags => const ['force'];

  @override
  Future<int> run() {
    if (words.isNotEmpty) {
      throw UsageException(
        'beak seed takes no arguments; use --class to run one seeder.',
        usage,
      );
    }
    return runWorm('db:seed');
  }
}

/// Regenerates, then runs the project's `bin/migrate.dart` with [args] in the
/// terminal, returning its exit code.
///
/// Preparing first is what makes a newly added migration or seeder take effect
/// without a separate command — the generated host lists them.
Future<int> runProjectCli(
  BeakCliEnvironment environment,
  List<String> args,
) async {
  final BeakPrepareResult prepared = runPrepare(environment);
  if (!prepared.isSuccess) {
    return prepared.exitCode;
  }
  return environment.runInteractive('dart', [
    'run',
    'bin/migrate.dart',
    ...args,
  ], workingDirectory: environment.rootDirectory.path);
}
