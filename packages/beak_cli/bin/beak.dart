import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:beak_cli/beak_cli.dart';

/// The `beak` CLI entry point.
///
/// Misuse — an unknown command, a bad option, a lowercase resource name, or
/// a malformed `--fields` spec — surfaces the crafted usage message on
/// stderr and exits `64` (the conventional `EX_USAGE`), rather than dumping
/// a Dart stack trace.
// --8<-- [start:main]
Future<void> main(List<String> args) async {
  final runner = createBeakRunner(BeakCliEnvironment.production());
  try {
    exit(await runner.run(args) ?? 0);
  } on UsageException catch (error) {
    stderr.writeln(error);
    exit(64);
  }
}

// --8<-- [end:main]
