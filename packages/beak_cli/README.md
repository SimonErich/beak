# beak_cli

The `beak` command: it scaffolds Beak projects, generates their wiring from
annotated schema classes, runs their migrations and diagnoses them.

Part of [**Beak**](https://github.com/SimonErich/beak), a low-code,
configuration-driven admin-panel framework for Dart/Flutter. See the
[architecture guide](../../docs/architecture/index.md) for how the packages fit
together.

## Install

```console
$ dart pub global activate --source path packages/beak_cli
$ beak --version
beak 0.9.0
```

The pubspec declares `beak` as an executable, so activating the package puts
it on your `PATH`.

## Usage

```console
$ beak create my_admin
$ cd my_admin
$ beak migrate
$ beak dev
```

`beak dev` regenerates the wiring, serves the API on `:8080` and prints the
`flutter run -d chrome` line that starts the panel in a second terminal.

`beak create` pins the project's Beak dependency to the release tag of this
CLI (`v0.9.0`); `--beak-ref <ref>` pins another ref and `--beak-path <path>`
uses a local checkout instead.

```console
$ beak make:resource Product --fields name:string!,price:decimal!,active:bool
$ beak migrate
```

`make:resource` writes the schema class
`lib/resources/products/models/product.dart` and its `BeakResource` class
`lib/resources/products/product_resource.dart`, then runs `beak prepare`,
which derives the columns, the model, both sides of every relationship and the
create-table migration from the schema. `make:migration` scaffolds an explicit
schema change. `introspect`, `eject`, `seed` and `doctor` support existing
databases, owned overrides, fixture data and setup checks. See the
[command reference](../../docs/reference/cli-commands.md) for flags and
deployment workflows.

## Generated or authored panel

A project boots its panel one of two ways.

- **Generated** (the default): `lib/main.dart` boots the panel `beak prepare`
  builds from every model. Each model gets a default resource, presented as
  `beak.yaml` says, and any `BeakResource` subclass under `lib/` with a
  zero-argument constructor replaces the default of the model it configures.
  `beak eject resource <table>` writes such a class, seeded from `beak.yaml`.
- **Authored**: `lib/main.dart` is a `BeakPanel(resources: [...])` the project
  owns, and `beak prepare` never rewrites it. `beak create --authored` starts a
  project this way; `beak eject main` switches an existing one, listing every
  resource the generated panel showed.

## Embedding

To run the CLI from your own `bin/beak.dart`, forward to `createBeakRunner`:

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

The library exports only that surface:

- `createBeakRunner` builds the `beak` `CommandRunner<int>` with every command
  registered.
- `BeakCliEnvironment` holds the injectable seams (output sink, root
  directory, clock, port probe, process runner); use
  `BeakCliEnvironment.production()` outside tests.
- `BeakPortProbe` and `BeakProcessRunner` are the types of the probe and
  process-runner seams.

The commands, emitters and schema reader are internal, so they can change
without a breaking release.

## Status

Pre-1.0, part of the Beak monorepo. Consumed by the
[canonical shop](../../examples/clean_beak_config). Contributions welcome; see
[CONTRIBUTING](../../CONTRIBUTING.md) at the repo root.

## License

Apache-2.0 © Marqably GmbH. See [LICENSE](LICENSE).
