/// Beak's scaffolding CLI — the `beak make:*` and `beak doctor` commands
/// that generate convention-following worm models, migrations, and Beak
/// column/model definitions so a developer defines a resource once and gets
/// every layer wired for free.
///
/// The entry point is [createBeakRunner], which builds an `args`
/// [CommandRunner] wired to a [BeakCliEnvironment]. A `bin/beak.dart` that
/// forwards to it is all a project needs:
///
/// ```dart
/// import 'dart:io';
///
/// import 'package:args/command_runner.dart';
/// import 'package:beak_cli/beak_cli.dart';
///
/// Future<void> main(List<String> args) async {
///   final runner = createBeakRunner(BeakCliEnvironment.production());
///   try {
///     exit(await runner.run(args) ?? 0);
///   } on UsageException catch (error) {
///     stderr.writeln(error);
///     exit(64); // EX_USAGE
///   }
/// }
/// ```
///
/// Then, from a project root:
///
/// ```console
/// $ beak make:resource Product --fields name:string,price:decimal,active:bool
/// ```
///
/// generates the worm model, its migration, and the Beak columns + model.
library;

export 'src/cli_runner.dart';
export 'src/commands/create_command.dart';
export 'src/commands/prepare_command.dart';
export 'src/field_spec.dart';
export 'src/project/beak_discovery.dart';
export 'src/project/beak_emitters.dart';
export 'src/project/beak_project_config.dart';
export 'src/templates.dart';
