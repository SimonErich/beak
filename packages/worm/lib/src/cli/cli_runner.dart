/// CLI dispatch for the worm command-line tool.
library;

import 'dart:io';

/// Outcome of running a CLI command.
final class CliResult {
  /// Creates a [CliResult].
  const CliResult({required this.exitCode, this.output = ''});

  /// Process exit code (0 for success).
  final int exitCode;

  /// Captured stdout for tests.
  final String output;
}

/// Spawns a child process. Overridable for tests.
typedef ProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

/// CLI entry point invoked by `bin/worm.dart`.
final class CliRunner {
  /// Creates a [CliRunner] with an optional [runner] override.
  CliRunner({ProcessRunner? runner}) : _runner = runner ?? Process.run;

  final ProcessRunner _runner;

  /// Dispatches on [arguments] and returns a [CliResult].
  Future<CliResult> run(List<String> arguments) async {
    if (arguments.isEmpty) {
      return const CliResult(
        exitCode: 64,
        output: 'usage: worm <command> [options]\nCommands:\n  gen',
      );
    }
    final command = arguments.first;
    final rest = arguments.sublist(1);
    return switch (command) {
      'gen' => _runGen(rest),
      '--help' || '-h' || 'help' => const CliResult(
        exitCode: 0,
        output: 'usage: worm <command> [options]\nCommands:\n  gen',
      ),
      _ => CliResult(exitCode: 64, output: 'Unknown command: $command'),
    };
  }

  Future<CliResult> _runGen(List<String> rest) async {
    final result = await _runner('dart', <String>[
      'run',
      'build_runner',
      'build',
      ...rest,
    ]);
    final buffer = StringBuffer()
      ..write(result.stdout)
      ..write(result.stderr);
    return CliResult(exitCode: result.exitCode, output: buffer.toString());
  }
}
