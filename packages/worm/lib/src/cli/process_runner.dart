/// Subprocess execution abstraction used by [GenCommand](`commands/gen_command.dart`).
///
/// Production code uses [DefaultProcessRunner], which delegates to
/// `dart:io`'s [Process] API. Tests inject a fake implementation so
/// no real subprocess is spawned; that is the primary reason this
/// indirection exists.
library;

import 'dart:async';
import 'dart:io';

/// Sink-driven contract for running subprocesses.
abstract class ProcessRunner {
  /// Const constructor for subclasses.
  const ProcessRunner();

  /// Runs a one-shot subprocess to completion, draining stdout/stderr
  /// into the supplied sinks before returning the exit code.
  Future<int> runSync(
    String executable,
    List<String> arguments, {
    required StringSink stdout,
    required StringSink stderr,
    String? workingDirectory,
  });

  /// Spawns a subprocess and streams stdout/stderr line-buffered into
  /// the supplied sinks as the process runs. Resolves when the child
  /// process terminates and yields its exit code.
  Future<int> runStreamed(
    String executable,
    List<String> arguments, {
    required StringSink stdout,
    required StringSink stderr,
    String? workingDirectory,
  });
}

/// Production [ProcessRunner] backed by `dart:io` [Process].
final class DefaultProcessRunner extends ProcessRunner {
  /// Creates a [DefaultProcessRunner].
  const DefaultProcessRunner();

  @override
  Future<int> runSync(
    String executable,
    List<String> arguments, {
    required StringSink stdout,
    required StringSink stderr,
    String? workingDirectory,
  }) async {
    final result = await Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      stdoutEncoding: systemEncoding,
      stderrEncoding: systemEncoding,
    );
    _writeProcessOutput(result.stdout, stdout);
    _writeProcessOutput(result.stderr, stderr);
    return result.exitCode;
  }

  @override
  Future<int> runStreamed(
    String executable,
    List<String> arguments, {
    required StringSink stdout,
    required StringSink stderr,
    String? workingDirectory,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );
    final stdoutDone = _pipe(process.stdout, stdout);
    final stderrDone = _pipe(process.stderr, stderr);
    final exitCode = await process.exitCode;
    await Future.wait(<Future<void>>[stdoutDone, stderrDone]);
    return exitCode;
  }

  Future<void> _pipe(Stream<List<int>> source, StringSink target) async {
    final lines = source.transform(systemEncoding.decoder);
    await for (final chunk in lines) {
      target.write(chunk);
    }
  }

  /// `ProcessResult.stdout` is declared `dynamic` so we narrow with
  /// pattern matching rather than an `as` cast. When the encoding is
  /// non-null the result is a [String]; otherwise it falls back to
  /// the raw byte list which we decode explicitly.
  void _writeProcessOutput(Object? raw, StringSink target) {
    switch (raw) {
      case final String s:
        target.write(s);
      case final List<int> bytes:
        target.write(systemEncoding.decode(bytes));
      case null:
        return;
      default:
        target.write(raw.toString());
    }
  }
}
