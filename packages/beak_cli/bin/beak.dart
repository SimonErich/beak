import 'dart:io';

import 'package:beak_cli/beak_cli.dart';

/// The `beak` CLI entry point.
Future<void> main(List<String> args) async {
  final runner = createBeakRunner(BeakCliEnvironment.production());
  exit(await runner.run(args) ?? 0);
}
