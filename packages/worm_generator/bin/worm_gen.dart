/// Standalone executable for the worm code generator.
///
/// Thin wrapper that forwards all arguments to
/// `dart run build_runner build`. Exit code is propagated so
/// CI/CD pipelines detect generation failures.
///
/// Usage:
///
/// ```sh
/// dart run worm_generator:worm_gen
/// dart run worm_generator:worm_gen --delete-conflicting-outputs
/// ```
library;

import 'dart:io';

Future<void> main(List<String> arguments) async {
  final process = await Process.start('dart', <String>[
    'run',
    'build_runner',
    'build',
    ...arguments,
  ], mode: ProcessStartMode.inheritStdio);
  exitCode = await process.exitCode;
}
