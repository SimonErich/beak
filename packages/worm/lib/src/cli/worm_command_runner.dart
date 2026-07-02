/// Top-level CLI command runner for the worm tool, plus the shared
/// [WormCommand] base class and [HelpFormatter] extension point.
library;

import 'dart:io';

import 'package:args/command_runner.dart';

import 'cli_context.dart';
import 'commands/db_seed_command.dart';
import 'commands/gen_command.dart';
import 'commands/init_command.dart';
import 'commands/make_factory_command.dart';
import 'commands/make_migration_command.dart';
import 'commands/make_model_command.dart';
import 'commands/make_observer_command.dart';
import 'commands/make_seeder_command.dart';
import 'commands/migrate_command.dart';
import 'commands/migrate_fresh_command.dart';
import 'commands/migrate_refresh_command.dart';
import 'commands/migrate_rollback_command.dart';
import 'commands/migrate_status_command.dart';
import 'commands/model_show_command.dart';
import 'commands/schema_dump_command.dart';

/// Shared base class for every worm CLI command.
///
/// Carries the [CliContext] DI handle and centralises cross-cutting
/// concerns (e.g. the `--force` flag used by destructive commands).
/// Concrete commands override `name`, `description`, and `run()`.
abstract class WormCommand extends Command<int> {
  /// Creates a [WormCommand] bound to [context].
  WormCommand(this.context);

  /// Shared CLI execution context (sinks, project root, env, factories).
  final CliContext context;

  /// Registers the standard `--force` flag used to bypass production
  /// safeguards. Destructive commands (`migrate:fresh`,
  /// `migrate:refresh`, …) call this from their constructor.
  void enableForceFlag() {
    argParser.addFlag(
      'force',
      help: 'Required when WORM_ENV=production.',
      negatable: false,
    );
  }

  /// Whether the user passed `--force`. Returns `false` when the flag
  /// has not been registered or has not been parsed yet.
  bool get force => argResults?.flag('force') ?? false;

  @override
  void printUsage() => context.out.writeln(usage);

  /// Writes [content] to [absolutePath] unless the file already
  /// exists. On conflict, writes a "refusing to overwrite"
  /// diagnostic to [CliContext.err] and returns `65`. On success,
  /// creates parent directories, writes the file, logs a
  /// `created  <relative>` line to [CliContext.out], and returns
  /// `0`. Used by every `make:*` command — see also
  /// [reportIfExists] and [writeFileUnchecked] for callers that
  /// must pre-check multiple paths before any write.
  Future<int> writeFile(String absolutePath, String content) async {
    if (reportIfExists(absolutePath)) return 65;
    await writeFileUnchecked(absolutePath, content);
    return 0;
  }

  /// Returns `true` and writes a diagnostic to [CliContext.err] when
  /// the file at [absolutePath] already exists; otherwise returns
  /// `false` without emitting anything.
  bool reportIfExists(String absolutePath) {
    if (!File(absolutePath).existsSync()) return false;
    context.err.writeln(
      'error: ${relativeToRoot(absolutePath)} already exists; '
      'refusing to overwrite',
    );
    return true;
  }

  /// Unconditionally writes [content] to [absolutePath]. Callers are
  /// responsible for ensuring the file does not already exist —
  /// typically via [reportIfExists]. Creates parent directories
  /// recursively and logs a `created  <relative>` line.
  Future<void> writeFileUnchecked(String absolutePath, String content) async {
    final file = File(absolutePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    context.out.writeln('created  ${relativeToRoot(absolutePath)}');
  }

  /// Returns [absolutePath] relative to [CliContext.projectRoot],
  /// or the original path when it does not sit inside the project
  /// root. Drops a leading separator so output reads as
  /// `lib/models/user.dart` rather than `/lib/models/user.dart`.
  String relativeToRoot(String absolutePath) {
    final root = context.projectRoot.path;
    if (!absolutePath.startsWith(root)) return absolutePath;
    final tail = absolutePath.substring(root.length);
    return tail.startsWith('/') ? tail.substring(1) : tail;
  }
}

/// Customisable formatter for global CLI help output.
///
/// Default ([standard]) delegates to [CommandRunner.usage]. Override
/// to add ANSI colour, group commands by namespace, or change the
/// column layout.
abstract class HelpFormatter {
  /// Const constructor for subclasses.
  const HelpFormatter();

  /// Stateless default formatter — returns [CommandRunner.usage] as-is.
  static const HelpFormatter standard = _StandardHelpFormatter();

  /// Renders the global help text for [runner].
  String formatGlobalHelp(CommandRunner<int> runner);
}

final class _StandardHelpFormatter extends HelpFormatter {
  const _StandardHelpFormatter();

  @override
  String formatGlobalHelp(CommandRunner<int> runner) => runner.usage;
}

/// CommandRunner wired with every worm CLI command.
///
/// Exit-code contract (matches the standard CLI conventions used by
/// `git`, `cargo`, etc.):
///
/// * `[]` (no args) and `['--help']` → exit `0`, usage printed to
///   [CliContext.out].
/// * Unknown command → exit `2`, error printed to [CliContext.err].
/// * Any other command's own return value, or `0` when a command
///   returns `null`.
final class WormCommandRunner extends CommandRunner<int> {
  /// Creates a [WormCommandRunner] bound to [context].
  ///
  /// [helpFormatter] customises the global help text — defaults to
  /// [HelpFormatter.standard].
  WormCommandRunner(
    this.context, {
    HelpFormatter helpFormatter = HelpFormatter.standard,
  }) : _helpFormatter = helpFormatter,
       super('worm', 'Type-safe, descriptor-first ORM for server-side Dart.') {
    addCommand(InitCommand(context));
    addCommand(MakeModelCommand(context));
    addCommand(MakeMigrationCommand(context));
    addCommand(MakeSeederCommand(context));
    addCommand(MakeFactoryCommand(context));
    addCommand(MakeObserverCommand(context));
    addCommand(MigrateCommand(context));
    addCommand(MigrateRollbackCommand(context));
    addCommand(MigrateStatusCommand(context));
    addCommand(MigrateFreshCommand(context));
    addCommand(MigrateRefreshCommand(context));
    addCommand(DbSeedCommand(context));
    addCommand(SchemaDumpCommand(context));
    addCommand(ModelShowCommand(context));
    addCommand(GenCommand(context));
  }

  /// Shared CLI execution context.
  final CliContext context;

  final HelpFormatter _helpFormatter;

  /// Active help formatter (default: [HelpFormatter.standard]).
  HelpFormatter get helpFormatter => _helpFormatter;

  @override
  Future<int?> run(Iterable<String> args) async {
    try {
      final result = await super.run(args);
      return result ?? 0;
    } on UsageException catch (e) {
      context.err.writeln(e);
      return 2;
    }
  }

  @override
  void printUsage() =>
      context.out.writeln(_helpFormatter.formatGlobalHelp(this));
}
