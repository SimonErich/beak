---
title: Installation
description: Add the worm packages to a Dart project, scaffold the folder layout, and wire up the CLI.
---

This page takes you from an empty pubspec to a working `worm` CLI. If you just want to see a query run first, jump to the [quickstart](./quickstart.md).

## Requirements

- Dart SDK `^3.11.0` or newer.
- A server-side Dart project. Worm targets Shelf, Dart Frog, and custom servers, not Flutter apps.

## Add the packages

The worm packages are not published to pub.dev yet (every pubspec says `publish_to: none`). Depend on them by path from a checkout of the beak monorepo, or by git.

Every project needs `worm` itself plus one database driver. The in-memory adapter for tests ships inside `worm`, so this is the complete minimum:

```yaml title="pubspec.yaml"
environment:
  sdk: ^3.11.0

dependencies:
  worm:
    path: ../beak/packages/worm
  worm_sqlite: # or worm_postgres, worm_mysql, worm_mongodb
    path: ../beak/packages/worm_sqlite
```

Swap the driver line for the backend you picked in [choosing a database](../drivers/choosing-a-database.mdx).

### Code generation (optional)

To generate typed companions from annotated models, add the generator and build_runner as dev dependencies:

```yaml title="pubspec.yaml"
dev_dependencies:
  build_runner: ^2.4.0
  worm_generator:
    path: ../beak/packages/worm_generator
```

[Code generation](../models/code-generation.md) covers what gets emitted and how to run it. Everything the generator emits can also be written by hand; the [quickstart](./quickstart.md) shows the hand-written form.

### Lints (optional)

`worm_lints` is a `custom_lint` plugin carrying worm's coding-convention rules. The `custom_lint` version is pinned exactly:

```yaml title="pubspec.yaml"
dev_dependencies:
  custom_lint: 0.8.1
  worm_lints:
    path: ../beak/packages/worm_lints
```

```yaml title="analysis_options.yaml"
analyzer:
  plugins:
    - custom_lint
```

## Scaffold the project layout

`worm init` creates the conventional folder layout. It is idempotent: rerunning prints `Already exists` for anything already present and never overwrites.

```sh
dart run worm:worm init
```

It creates 18 `lib/src/` subdirectories (adapter, cast, cli, config, exception, factory, logging, migration, model, naming, observer, predicate, query, registry, relation, schema, seeder, validation) plus:

- `migrations/` for migration classes
- `seeds/` for seeders
- `lib/models/` for your models
- `lib/factories/` for model factories
- `config/worm_config.dart`, a commented `WormConfig` template to fill in

You do not have to keep the whole tree. `migrations/`, `seeds/`, `lib/models/`, and `config/` are the ones the `make:*` commands write into.

## Wire the CLI to your project

The stock CLI (`dart run worm:worm`) knows nothing about your project: it ships with empty migration, seeder, and model lists and an in-memory adapter. To make `migrate` and `db:seed` act on your real database, create your own entry point and register everything explicitly:

```dart title="bin/worm.dart"
import 'dart:io';

import 'package:worm/worm.dart';
import 'package:worm_sqlite/worm_sqlite.dart';

Future<void> main(List<String> args) async {
  final context = CliContext(
    out: stdout,
    err: stderr,
    projectRoot: Directory.current,
    environment: Worm.environment, // reads WORM_ENV
    now: DateTime.now,
    adapterFactory: () async {
      final adapter = SqliteAdapter.open('app.db');
      await adapter.connect();
      return adapter;
    },
    migrations: const [], // register your Migration instances here
    seeders: const [],    // and your Seeder instances here
    models: const [],     // ModelInfo entries power model:show
  );
  exit(await WormCommandRunner(context).run(args) ?? 0);
}
```

Run it with `dart run bin/worm.dart <command>`. Migrations and seeders only run if they appear in those lists; there is no filesystem scanning. The full command reference lives in [CLI commands](../reference/cli-commands.md).

## Verify

```sh
dart run worm:worm --help
```

You should see the 15 commands, from `db:seed` to `schema:dump`. If Dart complains that the package is missing, run `dart pub get` first.

## Gotchas

- The default `adapterFactory` builds a connected `InMemoryAdapter`. Until you wire a real adapter into your own entry point, database commands succeed against RAM and touch no real database.
- `worm:worm` always runs the stock, empty-registry CLI from the worm package. Your project-aware entry point is the `bin/worm.dart` you wrote yourself.
- `custom_lint` must be exactly `0.8.1`; `worm_lints` pins `custom_lint_builder` to that version.
- Migrations, seeders, and models are registered in code, not discovered from disk. A migration file that is not in the `migrations:` list does not exist as far as the CLI is concerned.

## Continue reading

- [Quickstart](./quickstart.md) Prove the install with a passing typed query.
- [Configuration](./configuration.md) `Worm.initialize`, connections, and environments.
- [CLI commands](../reference/cli-commands.md) Every command, flag, and exit code.
