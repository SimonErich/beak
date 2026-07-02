/// `worm` CLI entry point.
///
/// Run via `dart run worm:worm <command>`. Includes `gen` (delegates
/// to `dart run build_runner build`), `migrate`, `migrate:rollback`,
/// `migrate:status`, `migrate:fresh`, `migrate:refresh`, `db:seed`,
/// `make:model`, `make:migration`, `make:factory`, `make:seeder`,
/// `make:observer`, `model:show`, `schema:dump`, and `init`.
library;

import 'dart:io';

import 'package:worm/src/cli/cli_context.dart';
import 'package:worm/src/cli/worm_command_runner.dart';
import 'package:worm/src/registry/worm.dart';

Future<void> main(List<String> args) async {
  final context = CliContext(
    out: stdout,
    err: stderr,
    projectRoot: Directory.current,
    environment: Worm.environment,
    now: DateTime.now,
    adapterFactory: CliContext.defaultAdapterFactory,
  );
  final runner = WormCommandRunner(context);
  final code = await runner.run(args) ?? 0;
  if (code != 0) exit(code);
}
