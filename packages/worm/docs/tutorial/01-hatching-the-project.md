---
title: 'Part 1: Hatching the project'
description: Create the Nestwatch package, wire the SQLite adapter, and stand up your own worm CLI.
---

In this part you create the project, connect worm to a SQLite file, and build the command-line tool you will use for the rest of the tutorial.

## Goal

An empty `nestwatch` package that boots the worm runtime against `nestwatch.db` and answers `dart run nestwatch migrate` with a clean "nothing to do yet".

## Create the package

Start a console package and move into it:

```bash
dart create -t console nestwatch
cd nestwatch
```

Open `pubspec.yaml` and set the dependencies. Worm lives in the `beak` monorepo, so this tutorial uses path dependencies. Adjust the paths to wherever worm sits relative to your project. See [Installation](../start-here/installation.md) for the full dependency story.

```yaml title="pubspec.yaml"
name: nestwatch
description: A bird-sighting field journal built on the worm ORM.
publish_to: none

environment:
  sdk: ^3.11.0

dependencies:
  worm:
    path: ../beak/packages/worm
  worm_sqlite:
    path: ../beak/packages/worm_sqlite

dev_dependencies:
  build_runner: ^2.4.0
  lints: ^6.0.0
  test: ^1.25.6
  worm_generator:
    path: ../beak/packages/worm_generator
```

Fetch the dependencies:

```bash
dart pub get
```

`worm` is the core ORM. `worm_sqlite` is the driver that turns worm's queries into SQLite calls. `worm_generator` is optional; you will hand-write your models in this tutorial, so you never have to run a build step.

## A tiny id helper

Worm uses string primary keys and leaves generating them to you. Add a helper that mints a random hex id:

```dart title="lib/ids.dart"
import 'dart:math';

final Random _random = Random.secure();

/// Returns a fresh 32-character hex id.
///
/// worm defaults to string primary keys but leaves generating them
/// to you. This is plenty for a field journal.
String newId() =>
    List.generate(32, (_) => _random.nextInt(16).toRadixString(16)).join();
```

## Boot the runtime

Every entry point needs to open the database and call `Worm.initialize` once before touching a model. Put that in one place:

```dart title="lib/nestwatch.dart"
import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

/// Opens the journal database and boots the worm runtime.
///
/// Every entry point (the CLI and the journal scripts) calls this
/// once before touching a model.
Future<DatabaseAdapter> bootNestwatch({String path = 'nestwatch.db'}) async {
  final adapter = SqliteAdapter.open(path);
  await adapter.connect();
  await Worm.initialize(
    config: const WormConfig(),
    adapters: <String, DatabaseAdapter>{'default': adapter},
    models: const <ModelRegistration>[],
  );
  return adapter;
}
```

`SqliteAdapter.open(path)` points at a file. `Worm.initialize` registers that adapter under the connection name `'default'`, which every query uses unless you say otherwise.

## Wire your own CLI

Worm ships a command-line tool, but its commands need to know about *your* database, *your* migrations, and *your* seeders. You give it that through a `CliContext` in your own entry point:

```dart title="bin/nestwatch.dart"
import 'dart:io';

import 'package:nestwatch/nestwatch.dart';
import 'package:worm/worm.dart';

/// Nestwatch's own worm CLI, wired to the real database.
Future<void> main(List<String> args) async {
  final adapter = await bootNestwatch();
  final context = CliContext(
    out: stdout,
    err: stderr,
    projectRoot: Directory.current,
    environment: Worm.environment,
    now: DateTime.now,
    adapterFactory: () => adapter,
    migrations: const <Migration>[],
    seeders: const <Seeder>[],
  );
  final code = await WormCommandRunner(context).run(args) ?? 0;
  if (code != 0) exit(code);
}
```

The `migrations` and `seeders` lists are empty for now. You fill them in later parts. This is the single most important wiring detail in the tutorial: the generic `dart run worm:worm ...` CLI uses an in-memory database by default, so migrations and seeds only touch your real file when you run *your* CLI, `dart run nestwatch ...`.

:::note
Use `dart run worm:worm ...` for scaffolding commands that write files (`init`, `make:model`, `make:migration`). Use `dart run nestwatch ...` for commands that touch the database (`migrate`, `db:seed`), because only your entry point knows about `nestwatch.db`.
:::

## Scaffold the worm layout

Let worm create the standard folders:

```bash
dart run worm:worm init
```

You see it create the project layout:

```text
created         lib/src/adapter/
created         lib/src/cast/
...
created         migrations/
created         seeds/
created         lib/models/
created         lib/factories/
created         config/
created         config/worm_config.dart
```

`init` also scaffolds a set of `lib/src/` folders. You can ignore those for this tutorial. The folders that matter are `migrations/`, `seeds/`, `lib/models/`, `lib/factories/`, and the generated `config/worm_config.dart`.

## Checkpoint

Run your CLI's migrate command:

```bash
dart run nestwatch migrate
```

```text
Nothing to migrate.
```

Nothing to migrate is exactly right. You have no migrations yet, and worm confirms it read your (empty) list rather than guessing. Your database file `nestwatch.db` now exists on disk.

## What just happened

You built the smallest complete worm app: one adapter, one `Worm.initialize`, and a CLI wired to both. The empty migration list is the proof that your context reached the runner. In the next part you give it something to run.

## Gotchas

- **The default adapter is in-memory.** The generic `dart run worm:worm` CLI builds its own throwaway in-memory database. Only your `bin/nestwatch.dart` opens `nestwatch.db`, so run database commands through `dart run nestwatch ...`.
- **Initialize once.** `Worm.initialize` runs a single time per process. `bootNestwatch` centralizes it so every script and command shares the same setup.
- **The connection name matters.** Registering the adapter under `'default'` is what lets a bare `Bird.query()` find it later. A model on another connection would name it explicitly.

## Continue reading

- [Part 2: Your first model](./02-your-first-model.md)
- [Installation](../start-here/installation.md)
- [CLI commands reference](../reference/cli-commands.md)
