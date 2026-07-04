# beak_cli

Scaffolding for Beak projects: `beak make:resource` and friends, plus
`beak doctor`.

Part of [**Beak**](https://github.com/marqably/beak), a low-code,
configuration-driven admin-panel framework for Dart/Flutter. See the
[architecture guide](../../docs/architecture.md) for how the packages fit
together.

## What it is

`beak_cli` is a pure-Dart console tool (only `args`, no Beak-specific
dependencies) that scaffolds convention-following code so a developer defines
a resource once and gets every layer wired for free. Its `make:*` commands
emit a worm model, its create-table migration, and the Beak columns + model
that both the server and the Flutter panel consume; `doctor` checks the local
dev setup. The entry points are the `beak` executable (`bin/beak.dart`) and
`createBeakRunner`, which builds the `CommandRunner` for embedding.

## Usage

From a project root, scaffold a full resource — worm model, migration, and
Beak columns/model in one shot:

```console
$ beak make:resource Product --fields name:string,price:decimal,active:bool
```

Narrower generators (`make:model`, `make:columns`, `make:migration`) emit a
single artifact, and `beak doctor` verifies worm/obers_ui paths, the `.env`
file, and the Postgres/MinIO services.

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
- `MakeResourceCommand` / `MakeModelCommand` / `MakeColumnsCommand` /
  `MakeMigrationCommand` — the `make:*` scaffolders.
- `DoctorCommand` — the `beak doctor` environment check.
- `BeakFieldSpec` / `BeakFieldKind` — a parsed `name:kind` field and its
  typed column kind, from `--fields`.
- `generateWormModel` / `generateMigration` / `generateBeakColumns` — the
  string code generators behind the commands.

## Status

Pre-1.0, part of the Beak monorepo. Consumed by the
[reference admin](../../apps/reference_admin). Contributions welcome — see
[CONTRIBUTING](../../CONTRIBUTING.md) at the repo root.

## License

Apache-2.0 © Marqably GmbH. See [LICENSE](LICENSE).
