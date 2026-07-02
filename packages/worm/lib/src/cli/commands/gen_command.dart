/// `worm gen` command.
library;

import '../process_runner.dart';
import '../worm_command_runner.dart';

/// Trigger `build_runner` code generation for `*.worm.dart`
/// companion files.
///
/// Surface flags:
///
/// * default → `dart run build_runner build --delete-conflicting-outputs`
/// * `--watch` → `dart run build_runner watch` with streamed output
/// * `--clean` → `dart run build_runner clean` followed by `build`
/// * `--no-delete-conflicting-outputs` opts out of the flag the
///   default `build` invocation forwards.
///
/// The actual subprocess plumbing is delegated to [ProcessRunner];
/// tests inject a fake so no real process is spawned.
final class GenCommand extends WormCommand {
  /// Creates a [GenCommand].
  ///
  /// [processRunner] defaults to [DefaultProcessRunner]; tests pass
  /// a fake that records arguments and supplies canned exit codes.
  GenCommand(super.context, {ProcessRunner? processRunner})
    : _runner = processRunner ?? const DefaultProcessRunner() {
    argParser
      ..addFlag(
        'watch',
        help: 'Spawn `dart run build_runner watch` with streamed output.',
        negatable: false,
      )
      ..addFlag(
        'clean',
        help: 'Run `build_runner clean` before the build step.',
        negatable: false,
      )
      ..addFlag(
        'delete-conflicting-outputs',
        help: 'Forward --delete-conflicting-outputs to `build_runner build`.',
        defaultsTo: true,
      );
  }

  final ProcessRunner _runner;

  @override
  String get name => 'gen';

  @override
  String get description =>
      'Run build_runner code generation. Use --clean to clean first, '
      '--watch to stay in watch mode.';

  @override
  Future<int> run() async {
    final results = argResults;
    final watch = results?.flag('watch') ?? false;
    final clean = results?.flag('clean') ?? false;
    if (clean) {
      final cleanCode = await _spawn(const <String>['clean']);
      if (cleanCode != 0) return cleanCode;
    }
    if (watch) return _spawn(const <String>['watch'], streamed: true);
    return _spawn(_buildArguments());
  }

  List<String> _buildArguments() {
    final deleteConflicts =
        argResults?.flag('delete-conflicting-outputs') ?? true;
    return <String>[
      'build',
      if (deleteConflicts) '--delete-conflicting-outputs',
    ];
  }

  Future<int> _spawn(List<String> args, {bool streamed = false}) {
    final invocation = <String>['run', 'build_runner', ...args];
    if (streamed) {
      return _runner.runStreamed(
        'dart',
        invocation,
        stdout: context.out,
        stderr: context.err,
        workingDirectory: context.projectRoot.path,
      );
    }
    return _runner.runSync(
      'dart',
      invocation,
      stdout: context.out,
      stderr: context.err,
      workingDirectory: context.projectRoot.path,
    );
  }
}
