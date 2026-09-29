import 'package:args/command_runner.dart';

import '../cli_runner.dart';
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
  DevCommand(this.environment) {
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
    return environment.runInteractive('dart', const [
      'run',
      'bin/serve.dart',
    ], workingDirectory: environment.rootDirectory.path);
  }
}

/// What `beak migrate` can be asked to do, named the way a person says it.
///
/// Each maps to the subcommand of worm's CLI that does it, because
/// `bin/migrate.dart` is that CLI and knows nothing of these words.
enum BeakMigrateVerb {
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

  const BeakMigrateVerb(this.wormCommand);

  /// The worm subcommand this runs.
  final String wormCommand;

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
    return runWorm(verb.wormCommand);
  }
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
