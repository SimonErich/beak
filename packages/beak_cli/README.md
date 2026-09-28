# beak_cli

Scaffolding for Beak projects: `beak make:resource` and friends, plus
`beak doctor`.

Part of [**Beak**](https://github.com/SimonErich/beak), a low-code,
configuration-driven admin-panel framework for Dart/Flutter. See the
[architecture guide](../../docs/architecture/index.md) for how the packages fit
together.

## What it is

`beak_cli` creates projects and turns annotated schema classes into model parts,
typed field helpers, migrations and panel/server wiring. `beak prepare` updates
generated files while preserving application-owned entrypoints. Changes to an
existing database require an explicit migration.

## Usage

```console
$ beak create my_admin
$ cd my_admin
$ beak make:resource Product --fields name:string,price:decimal,active:bool
$ beak migrate
$ beak dev
```

`make:resource` writes one annotated schema class and runs preparation.
`make:migration` scaffolds an explicit schema change. `introspect`, `eject`,
`seed` and `doctor` support existing databases, owned overrides, fixture data
and setup checks. See the [command reference](../../docs/reference/cli-commands.md)
for flags and deployment workflows.

To embed the CLI in your own `bin/beak.dart`, forward to `createBeakRunner`:

```dart
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:beak_cli/beak_cli.dart';

Future<void> main(List<String> args) async {
  final runner = createBeakRunner(BeakCliEnvironment.production());
  try {
    exit(await runner.run(args) ?? 0);
  } on UsageException catch (error) {
    stderr.writeln(error);
    exit(64); // EX_USAGE
  }
}
```

## Key types

- `createBeakRunner` — builds the `beak` `CommandRunner<int>` with every
  command registered.
- `BeakCliEnvironment` — the injectable seams (output sink, root directory,
  clock, port probe); use `BeakCliEnvironment.production()` outside tests.
- `PrepareCommand` / `runPrepare` — schema generation and project wiring.
- `MakeResourceCommand` / `MakeMigrationCommand` — schema and migration scaffolds.
- `DoctorCommand` — environment and generated-file checks.
- `BeakFieldSpec` / `BeakFieldKind` — typed parsing for `--fields` declarations.

## Status

Pre-1.0, part of the Beak monorepo. Consumed by the
[canonical shop](../../examples/clean_beak_config). Contributions welcome — see
[CONTRIBUTING](../../CONTRIBUTING.md) at the repo root.

## License

Apache-2.0 © Marqably GmbH. See [LICENSE](LICENSE).
