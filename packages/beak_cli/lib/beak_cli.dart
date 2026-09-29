/// Beak's command-line tool: `beak create`, `init`, `prepare`, `dev`,
/// `migrate`, `eject`, `introspect`, `docs`, `agents`, `make:resource`,
/// `make:migration` and `doctor`.
///
/// The public surface is the runner and the seams it runs against, which is
/// all a `bin/` entry point needs. Everything the commands are built from,
/// the emitters, the schema reader and the project scanner, stays private
/// to this package so it can change without a breaking release.
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
/// $ beak make:resource Product --fields name:string!,price:decimal,active:bool
/// ```
///
/// writes the `@Resource` schema class and its `BeakResource` class, then
/// runs `beak prepare`, which derives the columns, the model, both sides of
/// every relationship and the create-table migration from the schema.
library;

export 'src/cli_runner.dart'
    show BeakCliEnvironment, BeakPortProbe, BeakProcessRunner, createBeakRunner;
