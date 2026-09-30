# CLI commands

> Look up every beak command, its flags, the files it writes, what it prints and its exit codes.

`beak` scaffolds a project, regenerates its wiring, serves and migrates it, adopts an existing database, hands defaults over to you, feeds coding agents and diagnoses the result. This page lists every command with its flags, the files it writes and its exit codes. The output blocks are real runs of Beak 0.9.0, trimmed.

## Import

The CLI is a Dart executable, not a library you import. Install it once:

```bash
dart pub global activate --source git https://github.com/SimonErich/beak.git \
  --git-path packages/beak_cli
beak --version
```

```console
beak 0.9.0
```

Inside a checkout of this repository, `dart run packages/beak_cli/bin/beak.dart <command>` runs the same code. The package `beak_cli` exports `createBeakRunner` and `BeakCliEnvironment` (output sink, project directory, clock, port probe, process environment and the two process runners) for tests that drive the commands in memory.

Every command works on the current directory. Only `agents` and `docs` take a `--root` for the pub workspace.

## Summary

```console
$ beak --help
Beak: scaffold, generate, and diagnose admin panels.

Usage: beak <command> [arguments]

Global options:
-h, --help       Print this usage information.
    --version    Print the beak version and exit.

Available commands:
  agents           Write the AGENTS.md block, CLAUDE.md, docs and skills for coding agents.
  create           Scaffold a new Beak project.
  dev              Regenerate the wiring and serve the API for development.
  docs             Copy the docs of the resolved Beak version to .dart_tool/beak/docs.
  doctor           Diagnose this Beak project.
  eject            Write a Beak default out as a file this project owns.
  init             Add the Beak admin panel to an existing Flutter app.
  introspect       Write Beak models for the tables an existing database already has.
  make:migration   Scaffold an empty, correctly-named migration.
  make:resource    Scaffold a resource: its schema class and its resource class.
  migrate          Apply, inspect or roll back migrations.
  prepare          Regenerate the Beak wiring from the schema classes, resource classes, screens and beak.yaml.
  seed             Run the project seeders.
```

| Command | Arguments | Runs `prepare` first | Writes |
| --- | --- | --- | --- |
| [`create`](#beak-create) | `<name>` | at the end | A new project directory: pubspec, `beak.yaml`, entrypoint, agent files, `web/` |
| [`init`](#beak-init) | none | at the end | `beak.yaml`, an entrypoint, a `.gitignore` block and a pubspec dependency in an existing Flutter app |
| [`prepare`](#beak-prepare) | none | it is `prepare` | Schema parts, wiring, first migrations, agent files |
| [`dev`](#beak-dev) | none | yes | Nothing itself; serves the API |
| [`migrate`](#beak-migrate) | `[up\|status\|down\|fresh\|refresh]` | yes | Nothing itself; changes the database |
| [`seed`](#beak-seed) | none | yes | Nothing itself; changes the database |
| [`make:resource`](#beak-makeresource) | `<Name>` | at the end | A schema class and a resource class |
| [`make:migration`](#beak-makemigration) | `<Name>` | no | One migration file |
| [`introspect`](#beak-introspect) | `<database-url>` | no | Schema classes, a baseline migration, optionally `.env` |
| [`eject`](#beak-eject) | `<target> [table]` | `main` only | One file the project owns |
| [`docs`](#beak-docs) | none | no | `.dart_tool/beak/docs/` |
| [`agents`](#beak-agents) | none | no | `AGENTS.md`, `CLAUDE.md`, docs, skills |
| [`doctor`](#beak-doctor) | none | no | Nothing |

### Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Success, `--help`, `--version`, a run that found nothing to do, or a `doctor` run with warnings only |
| `1` | A generation error, a failed check, a file it refuses to replace, a `beak.yaml` it cannot read, a failed `flutter pub get`, `migrate fresh` or `refresh` refused in production, or `agents --check` finding a change |
| `64` | Bad input: an unknown command, a bad option, a malformed argument. The usage text goes to stderr |
| `74` | The disk refused: a folder it cannot write to, a file it cannot read. One `error:` line names the path |
| `78` | The generated `bin/serve.dart` or `bin/migrate.dart` refused its configuration: a `PORT` that is not a number, an unusable `DATABASE_URL` or storage variable, a port already in use. One `error:` line on stderr |
| child's | `dev`, `migrate` and `seed` return the exit code of the process they start, so `78` reaches you through them. Worm's own usage errors are `2` |

The entry point maps usage errors to `64`:

```dart title="packages/beak_cli/bin/beak.dart"
Future<void> main(List<String> args) async {
  final runner = createBeakRunner(BeakCliEnvironment.production());
  try {
    exit(await runner.run(args) ?? 0);
  } on UsageException catch (error) {
    stderr.writeln(error);
    exit(64);
  }
}

```

A `beak.yaml` problem prints to stdout and exits `1`, and a file system error prints one `error:` line to stdout and exits `74`.

### Commands that run prepare first

Commands marked "yes" regenerate the wiring before their own work, so a migration or a seeder you just added is already in the generated host when `migrate` runs. They stop with `prepare`'s exit code when generation fails. `dev`, `migrate` and `seed` do not refresh the agent files; `prepare` does.

## beak create

Scaffolds a project directory named after the package.

```console
beak create <name> [--authored] [--[no-]example] [--[no-]pub]
                   [--skills claude,agents,cursor|none]
                   [--beak-ref <ref> | --beak-path <path>]
```

| Flag | Default | Meaning |
| --- | --- | --- |
| `<name>` | required | A Dart package name, `^[a-z][a-z0-9_]*$` |
| `--authored` | off | Write a `lib/main.dart` you own, a `BeakPanel(resources: [...])`, plus the example's `NoteResource`. Otherwise `lib/main.dart` is generated. Same result as `beak eject main` afterwards |
| `--[no-]example` | on | Write the example `Note` schema class and its `resources:` entry in `beak.yaml`. `--no-example` starts empty, for `make:resource` |
| `--[no-]pub` | on | Run `flutter pub get`, then `prepare` and the agent files. `--no-pub` writes the files, prints what to run, and needs no network |
| `--skills` | the agent folders the project has, then `claude` and `agents` | Where the workflow skills are installed: any of `claude`, `agents`, `cursor`, comma separated, or `none` |
| `--beak-ref` | `v0.9.0` (the CLI's release tag) | The git ref the pubspec depends on |
| `--beak-path` | none | Depend on a local checkout (`<path>/packages/beak`) instead of git, written into the pubspec as a normalised absolute path. `<path>` is the repo root: without `packages/beak` under it the command stops. Cannot be combined with `--beak-ref` |

```console
$ beak create shop_admin --no-example --skills claude
  created shop_admin/pubspec.yaml
  created shop_admin/beak.yaml
  created shop_admin/lib/main.dart
  created shop_admin/.gitignore
  created shop_admin/analysis_options.yaml
  created shop_admin/AGENTS.md
  created shop_admin/CLAUDE.md
  created shop_admin/test/widget_test.dart
  created shop_admin/README.md
Resolving dependencies...
Changed 142 dependencies!
  0 models · 0 resource classes · 0 screens · 0 overrides
  generated  6 of 7 files
  agents     AGENTS.md updated · docs Beak 0.9.0, .dart_tool/beak/docs/ai-index.md

  next:
    cd shop_admin
    beak make:resource Product --fields name:string!
    beak migrate
    beak dev
```

The sequence is fixed:

1. It writes the scaffold, before anything can fail on the network: `pubspec.yaml`, `beak.yaml`, the `Note` schema class at `lib/resources/notes/models/note.dart` (unless `--no-example`), `lib/main.dart`, `.gitignore`, `analysis_options.yaml`, `AGENTS.md` and `CLAUDE.md`.
2. It runs `flutter create --platforms=web --no-pub --project-name <name> .` inside the new directory for `web/`. If that fails it prints a `skipped web/` line and carries on; `beak doctor` warns about the missing scaffold later.
3. It writes `test/widget_test.dart` and `README.md`, replacing what `flutter create` left.
4. Unless `--no-pub`: `flutter pub get`, `beak prepare`, then the agent files and skills. A failed `pub get` still attempts `prepare` and the agent files, then exits `1`.

The pubspec depends on one package, `beak`, by git at the release tag (or by path). The tag has to exist on the remote: while a release is untagged, `flutter pub get` fails with `Could not find git ref`, and `--beak-ref <branch>` or `--beak-path` is the way around it.

Usage errors, all exit `64`: a name that is not lower_snake_case, a name that is a Dart keyword or a package the project depends on (`beak`, `flutter`, `class`), both `--beak-ref` and `--beak-path`, a `--beak-path` with no `packages/beak` under it (for example `beak/packages/beak`, which names the package and not the repo root), an unknown `--skills` value, and any count of arguments other than one name.

It refuses, with exit `1` and nothing written, when `<name>/` already exists and is not empty, or is a file. An empty directory is used. To add Beak to a project that is already there, use [`beak init`](#beak-init).

> **Note: beak create --help**
>
> ```console
> Scaffold a new Beak project.
>
> Usage: beak create <name> [--authored] [--[no-]example] [--[no-]pub] [--skills claude,agents,cursor|none] [--beak-ref <ref> | --beak-path <path>]
> -h, --help                                  Print this usage information.
>     --beak-path=<path/to/beak>              Depend on a local Beak checkout, the repo root that holds packages/beak, instead of git. Use it when developing Beak itself.
>     --beak-ref=<ref>                        The git ref of Beak to depend on.
>                                             (defaults to "v0.9.0")
>     --authored                              Write a lib/main.dart the project owns, composing the panel from resource classes, instead of the generated one.
>     --[no-]example                          Write a first schema class, a Note. Pass --no-example to start from `beak make:resource`.
>                                             (defaults to on)
>     --[no-]pub                              Run `flutter pub get`, then `beak prepare` and the agent files. Pass --no-pub to only write the files and print what to run.
>                                             (defaults to on)
>     --skills=<claude,agents,cursor|none>    Where to install the workflow skills: any of claude, agents and cursor, comma separated, or none. Defaults to the agent folders the project has, then claude and agents.
> ```

## beak init

Adds the panel to a Flutter app that already exists and keeps its own `lib/main.dart`. The app's files are not rewritten.

```console
beak init [--entrypoint <path>] [--beak-ref <ref> | --beak-path <dir>]
          [--example] [--[no-]pub] [--dry-run]
```

| Flag | Default | Meaning |
| --- | --- | --- |
| `--entrypoint` | `lib/main.dart` when the app has none of its own, otherwise `lib/admin_main.dart` | The Dart file that boots the panel. Must sit directly under `lib/`. Refused when `beak.yaml` already sets a different `panel.entrypoint` |
| `--beak-ref` | `v0.9.0` | Git ref of the dependency |
| `--beak-path` | none | Local checkout instead of git, the repo root that holds `packages/beak`. A relative path is relative to the app and is written normalised and absolute, as `beak create` does; a directory without `packages/beak` is a usage error (exit `64`) |
| `--example` | off | Also write the `Note` schema class and `NoteResource` |
| `--[no-]pub` | on | `flutter pub get`, `beak prepare`, the agent files |
| `--dry-run` | off | Print what would be written |

```console
$ beak init --dry-run
  would add the beak dependency to pubspec.yaml
  would create beak.yaml
  would create lib/admin_main.dart
  would create .gitignore
  analysis_options.yaml is yours, so Beak leaves it alone. Its files are written for these flags:
    analyzer:
      language:
        strict-casts: true
        strict-inference: true
        strict-raw-types: true
```

What it writes, each step only when missing, so a second run repairs and changes nothing else:

| File | Content |
| --- | --- |
| `pubspec.yaml` | The `beak` dependency, added with comments preserved |
| `beak.yaml` | `name`, `api.baseUrl` and `panel.entrypoint`. An existing file gets only the `panel:` key |
| the entrypoint | An authored `BeakPanel(resources: [...])`. An existing file is left as it was |
| `.gitignore` | A `# BEGIN beak` to `# END beak` block: `/bin/serve.dart`, `/bin/migrate.dart`, `/*.db*`, `/storage/`, `.env` |

Then, unless `--no-pub` or `--dry-run`, it runs `flutter pub get`, `prepare` and the agent files, and prints what to run next: `beak make:resource` unless `--example` wrote a `Note`, then `beak migrate`, `beak dev` and the `flutter run -d chrome -t <entrypoint>` line. `panel.entrypoint` is what stops `prepare` from writing `lib/main.dart`, see [beak.yaml](beak-yaml.md#panel).

`beak init` takes no arguments (`64`), and `64` is also the exit for `--beak-ref` together with `--beak-path` and for an `--entrypoint` that is not a Dart file directly under `lib/`.

It exits `1` for: no `pubspec.yaml`, a pubspec that is not valid YAML, a project without `flutter: sdk: flutter`, and any project that belongs to a Serverpod workspace. The message names both ways into one: [the admin app in your workspace](../serverpod/admin-app/index.md), and the [client bridge](../serverpod/bridge/index.md), which is wired by hand.

> **Note: beak init --help**
>
> ```console
> Add the Beak admin panel to an existing Flutter app.
>
> Usage: beak init [--entrypoint <path>] [--beak-ref <ref> | --beak-path <dir>] [--example] [--[no-]pub] [--dry-run]
> -h, --help                 Print this usage information.
>     --entrypoint=<path>    The Dart file, directly under lib/, that boots the panel. Defaults to lib/main.dart when the app has none of its own, and lib/admin_main.dart otherwise.
>     --beak-ref=<ref>       The git ref of Beak to depend on.
>                            (defaults to "v0.9.0")
>     --beak-path=<dir>      Depend on a local Beak checkout, the repo root that holds packages/beak, instead of git. Use it when developing Beak itself.
>     --example              Also write a first schema class and resource, a Note.
>     --[no-]pub             Run `flutter pub get` and `beak prepare` afterwards.
>                            (defaults to on)
>     --dry-run              Report what would be written without writing it.
> ```

## beak prepare

Regenerates everything Beak derives from what you declare. It takes no flags.

```console
$ beak prepare
  2 models · 2 resource classes · 0 screens · 1 override
  generated  5 of 9 files
  agents     up to date · docs Beak 0.9.0, .dart_tool/beak/docs/ai-index.md
```

| Step | Reads | Writes |
| --- | --- | --- |
| 1. Schema parts | every `@Resource` class under `lib/` | one `*.beak.dart` beside each class |
| 2. Discovery | models, `BeakResource` subclasses, `lib/screens/`, `lib/migrations/`, `lib/seeders/`, override files, `beak.yaml` | nothing |
| 3. Migrations | models with no migration creating their table | `lib/migrations/create_<table>_table.dart`, once, never rewritten |
| 4. Wiring | the discovery result | `lib/beak/registry.g.dart`, `server.g.dart`, `bin/serve.dart`, `bin/migrate.dart`, `panel.g.dart` and `app.g.dart` while something uses them, and `lib/main.dart` unless it is yours |
| 5. Agent files | `beak.yaml` `agents:` | the `AGENTS.md` block and the docs copy, see [beak agents](#beak-agents) |

The exact content of each file is in [Generated files and symbols](generated-files.md). A file whose text is unchanged is not rewritten, which keeps Flutter's file watcher quiet. An entrypoint without the `// GENERATED BY` header belongs to the project and is left alone.

The `generated` line reports the files written out of the files considered (`5 of 9`), or `up to date (N files)` when nothing changed. The files considered are the schema parts, whether they changed or not, and the wiring and entrypoints this project has.

`panel.g.dart` and `app.g.dart` exist for a generated `lib/main.dart`, which runs the `BeakApp` in the second. With an authored `lib/main.dart`, or a `panel.entrypoint` in `beak.yaml`, the entrypoint builds its own `BeakPanel`, so `prepare` writes neither, `doctor` does not compare them, and it deletes a pair a generated entrypoint left behind (`removed    lib/beak/panel.g.dart, lib/beak/app.g.dart: nothing imports them`). A file of the project that imports either one, a widget test for `BeakApp` for instance, keeps both.

When the project declares no model yet, it says so and succeeds:

```console
$ beak prepare
  0 models · 0 resource classes · 0 screens · 0 overrides
  no models yet: add a @Resource class under lib/, or run `beak make:resource Product`, then `beak prepare` again
  generated  7 of 7 files
```

On a problem it writes no wiring and exits `1`, listing everything at once:

```console
$ beak prepare
Cannot generate: fix these first:
  lib/resources/notes/models/note.dart: Note.site is a Uri, which Beak cannot map to a column. Use a supported type, annotate it with @BelongsTo / @HasMany for a relationship, or @Custom for an opaque value.
```

Schema parts are written before the scan can find a second kind of problem, so a refused run can have refreshed some. It ends with `Schema parts written before these were found: <paths>. Nothing else was generated.` when it did.

The messages of the schema reader are listed in [Annotations](annotations.md#errors-from-beak-prepare). Discovery reports a model it cannot construct instead of skipping it, and `beak.yaml` keys that name no table with a did-you-mean. Beyond the reader's own messages, `prepare` refuses a schema file without its `part '<file>.beak.dart';` directive, and a project that is not a Beak project (below).

A package that depends on `beak_core` alone (schema classes for a server and an admin that live elsewhere) is generated as a models-only package: the parts and `lib/beak/registry.g.dart`, no wiring, no entrypoint, no migration and no `beak.yaml`.

> **Note: beak prepare --help**
>
> ```console
> Regenerate the Beak wiring from the schema classes, resource classes, screens and beak.yaml.
>
> Usage: beak prepare [arguments]
> -h, --help    Print this usage information.
> ```

`prepare`, `dev`, `migrate`, `seed`, `make:resource` and `eject main` refuse a directory that is not a Beak project, one without a `pubspec.yaml` or without a Beak dependency, with nothing written:

```console
$ beak prepare
Cannot generate: fix these first:
  pubspec.yaml: no Beak dependency here; run `beak init`
```

A package that depends on `beak_core` alone is a Beak project of the models-only kind.

## beak dev

Regenerates, prints the `flutter run` line for the panel, and starts the API.

```console
beak dev [-d <device>] [--[no-]serve]
```

| Flag | Default | Meaning |
| --- | --- | --- |
| `-d`, `--device` | `chrome` | The device in the printed `flutter run` line |
| `--[no-]serve` | on | `--no-serve` regenerates and prints only |

```console
$ beak dev
  2 models · 2 resource classes · 0 screens · 1 override
  generated  up to date (9 files)
  panel      run this in another terminal:
               flutter run -d chrome
  api        starting…
warning: Beak is listening on 0.0.0.0:8080 with BeakAllowAllPolicy, so every route answers every caller and CORS admits any origin. Pass a BeakPolicy to defaults.build(policy: ...), or set HOST=127.0.0.1 to keep it on this machine.
listening on http://0.0.0.0:8080
```

The panel is not started by `beak dev`: proxying Flutter's interactive console is fragile, so you run the printed line in a second terminal. In an app with `panel.entrypoint` the line carries `-t lib/admin_main.dart`. The API is `dart run bin/serve.dart` with the terminal attached; its port comes from `PORT`, `.env` or `beak.yaml`, see [Configuration and environment](configuration.md#environment-variables). The first start in a new project compiles native code and can take about 30 seconds; when nothing listens on the port after 3 seconds, `beak dev` prints `api        still starting (the first run compiles native code, ~30 s)`. `beak dev` returns the server's exit code, and `Ctrl-C` shuts it down. A setting the host refuses (a `PORT` that is not a number, an unusable `DATABASE_URL`, a port that is already in use) ends the server with one `error:` line and exit `78`; the port message names `PORT` and `server.port`.

> **Note: beak dev --help**
>
> ```console
> Regenerate the wiring and serve the API for development.
>
> Usage: beak dev [arguments]
> -h, --help          Print this usage information.
> -d, --device        Device the printed `flutter run` line targets.
>                     (defaults to "chrome")
>     --[no-]serve    Start the API. Pass --no-serve to only regenerate.
>                     (defaults to on)
> ```

## beak migrate

Applies, inspects or rolls back migrations by running the project's generated `bin/migrate.dart`, which is worm's CLI over the same host the server uses. Migrations are never applied on boot, except for an in-memory SQLite database, which no other process could prepare.

```console
beak migrate [up|status|down|fresh|refresh] [--pretend] [--step N]
             [--steps N] [--seed] [--force] [-- <worm args>]
```

The verbs, quoted from the source:

```dart title="packages/beak_cli/lib/src/commands/dev_command.dart"
/// Apply the pending migrations.
up('migrate'),

/// List which migrations are applied and which are pending.
status('migrate:status'),

/// Roll back the latest batch, or `--steps` of them.
down('migrate:rollback'),

/// Drop the tables and apply every migration again.
fresh('migrate:fresh'),

/// Roll every migration back, then apply them again.
refresh('migrate:refresh');

```

| Verb | Worm command | Meaning |
| --- | --- | --- |
| `up` (default) | `migrate` | Apply pending migrations in one batch |
| `status` | `migrate:status` | List each migration as applied or pending |
| `down` | `migrate:rollback` | Roll back the latest batch |
| `fresh` | `migrate:fresh` | Drop the migration log and apply everything again |
| `refresh` | `migrate:refresh` | Roll everything back, then apply again |

| Flag | Applies to | Meaning |
| --- | --- | --- |
| `--pretend` | `up` | Print the SQL, run nothing |
| `--step=N` | `up` | Apply at most `N` pending migrations |
| `--steps=N` | `down` | Roll back `N` batches (worm's default is `1`) |
| `--seed` | `fresh` | Run the seeders afterwards |
| `--force` | `fresh`, `refresh` | Required when `WORM_ENV=production` |
| `-- <args>` | any | Everything after `--` goes to worm untouched |

A flag the verb does not take is a usage error (exit `64`) that names the verb it belongs to, so `beak migrate up --steps 2` says ``--steps applies to `beak migrate down` ``, where it used to reach worm and end in worm's own usage with exit `2`.

```console
$ beak migrate status
Migration                            | Batch | Status
-----------------------------------------------------
[ ] 20260926_000000_beak_commit_receipts | -     | pending
[ ] 20260927_000000_beak_outbox          | -     | pending
[ ] 20260929_121618_create_notes_table   | -     | pending

$ beak migrate --pretend
-- 20260929_121618_create_notes_table
CREATE TABLE "notes" ("id" TEXT PRIMARY KEY, "title" TEXT NOT NULL, "body" TEXT, "pinned" INTEGER NOT NULL DEFAULT 0, "created_at" TEXT, "updated_at" TEXT)
-- Params: []
Dry run complete — no changes made.

$ beak migrate
migrated  20260926_000000_beak_commit_receipts
migrated  20260927_000000_beak_outbox
migrated  20260929_121618_create_notes_table

$ beak migrate down --steps 1
reverted  20260929_121618_create_notes_table
reverted  20260927_000000_beak_outbox
reverted  20260926_000000_beak_commit_receipts

$ WORM_ENV=production beak migrate fresh
error: refusing to run destructive command in production without --force
```

The first two migrations are Beak's own tables for graph-commit receipts and the outbox; they are always in the host. A batch is one `migrate` run, so `down --steps 1` above undid all three. Output from `dart run` may add a `Running build hooks...` line in front of the child's output.

`WORM_ENV` selects `development` (the default), `staging`, `production` or `testing`. `beak migrate fresh` and `refresh` read it the way the server does, from the process environment over the project's `.env`, and refuse in production without `--force` with the message above. `beak seed` resolves it the same way and hands it to worm as `--env`. Worm's own gate and seeder filter, reached by running `dart run bin/migrate.dart` directly, read the process environment only. The database comes from `DATABASE_URL`, see [Configuration and environment](configuration.md#the-server).

Unknown verbs and more than one verb exit `64`. Known limit on SQLite: `migrate:refresh` cannot roll back a belongs-to column made by a create-table migration, because the foreign key is a table-level constraint. Postgres is fine.

> **Note: beak migrate --help**
>
> ```console
> Apply, inspect or roll back migrations.
>
> Usage: beak migrate [up|status|down|fresh|refresh] [--pretend] [--step N] [--steps N] [--seed] [--force] [-- <worm args>]
> -h, --help         Print this usage information.
>     --pretend      Print the SQL without running it (up).
>     --seed         Run the seeders afterwards (fresh).
>     --force        Allow it when WORM_ENV=production (fresh, refresh).
>     --step=<N>     Apply at most this many migrations (up).
>     --steps=<N>    Roll back this many batches (down).
> ```

## beak seed

Runs the seeders discovered under `lib/seeders/`, through the same `bin/migrate.dart` as `migrate`.

```console
beak seed [--class <SeederName>] [--env <name>] [--force] [-- <worm args>]
```

| Flag | Meaning |
| --- | --- |
| `--class=<SeederName>` | Run only the seeder with this name |
| `--env=<name>` | Filter seeders by this environment instead of `WORM_ENV`, which `beak seed` reads from the shell over `.env` |
| `--force` | Ignore the environment filter and run every seeder |

```console
$ beak seed
  2 models · 2 resource classes · 0 screens · 1 override
  generated  up to date (9 files)
No seeders applicable to development environment.
```

It takes no positional arguments (`64`). Seeders are worm `Seeder` classes; see [Seeding](../backend/seeding.md).

> **Note: beak seed --help**
>
> ```console
> Run the project seeders.
>
> Usage: beak seed [--class <SeederName>] [--env <name>] [--force] [-- <worm args>]
> -h, --help                  Print this usage information.
>     --class=<SeederName>    Run only the seeder with this name.
>     --env=<name>            Filter the seeders by this environment instead of the active one.
>     --force                 Ignore the environment filter and run every seeder.
> ```

## beak make:resource

Writes the schema class and the resource class of a new model, then runs `prepare`.

```console
beak make:resource <Name> [--fields name:kind[!],...]
```

`Name` is `UpperCamelCase` (`^[A-Z][A-Za-z0-9]*$`), and not one the generated code needs for something else (`List`, `String`, `Resource`, `Schema`, `Migration` and the others in [Annotations](annotations.md#rules-and-limits)), which is a usage error (exit `64`).

```console
$ beak make:resource Product --fields name:string!,price:decimal!,active:bool
  created lib/resources/products/models/product.dart
  created lib/resources/products/product_resource.dart
  2 models · 1 resource class · 0 screens · 0 overrides
  generated  5 of 9 files
```

| File | Content |
| --- | --- |
| `lib/resources/<plural>/models/<snake>.dart` | An annotated `BeakSchema` class with `@Resource(timestamps: true)` |
| `lib/resources/<plural>/<snake>_resource.dart` | A `BeakResource` subclass with the model and a `table` icon |

It refuses, with exit `1`, when either file exists. If the panel entrypoint is authored, it prints the import and the `ProductResource(),` line to add to `resources: [...]`, because `prepare` never rewrites that file.

### The `--fields` grammar

A comma-separated list of `name:kind`, `name` in `lower_snake_case` (becomes a camelCase Dart identifier: `placed_at` is `placedAt`). A trailing `!` makes the field required, which is Dart's own non-nullable type; without it the type is nullable. A name that is a Dart keyword (`class`, `default`) or one Beak adds itself (`id`, `created_at`, `updated_at`, `record`) is a usage error (exit `64`). Without `--fields` the class gets one required `name:string`.

| Token (aliases) | Dart type | Options added |
| --- | --- | --- |
| `string` | `String` | `searchable: true`; the first `string` also gets `@Display()` |
| `text` | `BeakText` | `searchable: true` |
| `int` (`integer`) | `int` | `sortable: true` |
| `decimal` | `BeakDecimal` | `sortable: true` |
| `double` (`float`) | `double` | `sortable: true` |
| `bool` (`boolean`) | `bool` | `filterable: true` |
| `datetime` (`date`) | `DateTime` | `sortable: true` |

```dart title="packages/beak_cli/lib/src/field_spec.dart"
static BeakFieldKind? parse(String token) => switch (token) {
  'string' => string,
  'text' => text,
  'int' || 'integer' => integer,
  'decimal' => decimal,
  'double' || 'float' => floating,
  'bool' || 'boolean' => boolean,
  'datetime' || 'date' => dateTime,
  _ => null,
};
```

`decimal` is a `BeakDecimal`, an exact fixed-scale number stored as integer units (scale 2 unless you add a `BeakSemantic`), which is what a price needs, see [Field types](field-types.md). `double` is the floating-point number, for a measurement that may round. An unknown kind or a malformed pair is a usage error (`64`), and its message lists the kinds. Relationships and the other authoring types are added by editing the class.

The default table name comes from a small pluraliser (`Day` becomes `days`, `Person` becomes `people`); see [Annotations](annotations.md#rules-and-limits).

> **Note: beak make:resource --help**
>
> ```console
> Scaffold a resource: its schema class and its resource class.
>
> Usage: beak make:resource [arguments]
> -h, --help      Print this usage information.
>     --fields    Comma-separated name:kind pairs (string|text|int|decimal|double|bool|datetime).
>                 (defaults to "")
> ```

## beak make:migration

Writes a migration for a change `prepare` cannot derive: a column on a shipped table, a backfill, a drop.

```console
beak make:migration <Name> [--from-drift] [--force]
```

| Flag | Meaning |
| --- | --- |
| `--from-drift` | Fill the body from the difference between the schema classes and the database |
| `--force` | Replace the file if a migration of this name already exists |

```console
$ beak make:migration AddStatusToProducts
  created lib/migrations/add_status_to_products.dart
```

The scaffold is `lib/migrations/<snake>.dart`, class `<Name>` extending `Migration`, named `<yyyymmdd_hhmmss>_<snake>`. Migrations run ordered by that name, and `prepare` lists them on the generated host, so there is nothing to register. The one exception is a create-table migration whose table points at a table a later migration creates: the host lists the target first, see [Migrations](../backend/migrations.md#order).

Both forms refuse, with exit `1`, when a file of the same name exists, because a migration is edited by hand as soon as it is written. `--force` replaces it.

### `--from-drift`

It reads the schema classes and the live database (Postgres or SQLite, from `DATABASE_URL`, default `sqlite:beak.db`) and writes the columns the classes declare and the database lacks. Every alteration first asks the database, because a fresh database already has the column from the create-table migration, which reads the model as it is now:

```console
$ beak make:migration AddStockToProducts --from-drift
  created lib/migrations/add_stock_to_products.dart
  run `beak migrate` to apply it
```

```dart title="lib/migrations/add_stock_to_products.dart"
  @override
  Future<void> upSchema(Schema schema) async {
    final live = await schema.adapter.introspectSchema();
    if (!_has(live, 'products', 'stock')) {
      await schema.alter('products', (table) {
        BeakBlueprint.defineColumn(table, ProductColumns.stock);
      });
    }
  }
```

Both `upSchema` and `downSchema` are guarded, so the file applies and rolls back on a database that already has, or lacks, the column. A belongs-to key is written as an indexed foreign key, with the same constraint the create-table migration makes. Run again before applying, it writes the same file with a new timestamp. Run after applying:

```console
$ beak make:migration AddStockToProducts --from-drift
  nothing to add: the database already has every column the schema classes declare
```

A column that needs a decision is reported with `!`, not written:

```console
$ beak make:migration AddWeight --from-drift
  ! products.weight: a required column needs a value for the rows already there; give it `@Column(defaultValue: ...)`, or make it nullable and backfill
  ! products.barcode: SQLite cannot add a unique column to an existing table; declare it without `unique: true` for now, backfill, then add the unique index in a migration of its own
  nothing written: every missing column needs a decision first
```

That run exits `1`. Also reported: `in-memory SQLite` (nothing on disk to compare), a URL scheme other than Postgres or SQLite, and a SQLite file that does not exist yet (`run beak migrate first`). Missing tables, missing `deleted_at`, and database columns no class declares are left to you; `beak doctor` reports them. `DATABASE_URL` is read from the process environment first and the project's `.env` second, the order the server uses.

> **Note: beak make:migration --help**
>
> ```console
> Scaffold an empty, correctly-named migration.
>
> Usage: beak make:migration <Name> [--from-drift] [--force]
> -h, --help          Print this usage information.
>     --from-drift    Fill the migration in from the difference between the schema classes and the database.
>     --force         Replace the file if a migration of this name already exists.
> ```

## beak introspect

Writes schema classes for the tables an existing database already has.

```console
beak introspect <database-url> [--out <dir>] [--schema <name>]
                [--only t1,t2] [--except t1,t2]
                [--ownership adopt|external] [--save-url] [--force]
                [--dry-run]
```

| Flag | Default | Meaning |
| --- | --- | --- |
| `<database-url>` | required | `postgres://user:pass@host:5432/db` or `sqlite:path/to.db`. Other schemes exit `1`, and so does a SQLite file that is not there (it is never created) or a database that cannot be read |
| `--out` | `lib/resources/<table>/models/` per table | One flat directory instead. It must be inside the project, and with `adopt` under `lib/` (exit `64` otherwise) |
| `--schema` | `public` | The Postgres schema to read |
| `--only`, `--except` | all tables | Table filters, comma separated or repeated |
| `--ownership` | `adopt`, or `external` when another tool's migration history is present | Who owns the schema from here on |
| `--save-url` | off | Upsert `DATABASE_URL=<url>` into `.env` and warn if `.env` is not ignored by git |
| `--force` | off | Replace schema files that already exist and differ from what the database implies |
| `--dry-run` | off | Print what would be written |

```console
$ beak introspect sqlite:legacy.db --save-url
  read 4 tables, 25 columns, 0 foreign keys
  created lib/resources/notes/models/note.dart
  created lib/resources/products/models/product.dart
  created lib/migrations/adopt_existing_schema.dart
  skipped worm_migrations (migration bookkeeping)
  created .env
  adopting   the migration records these tables as Beak's. On this database it changes nothing;
             on an empty one it creates them.

  run `beak prepare` to wire them up
```

| Ownership | Classes | Migration |
| --- | --- | --- |
| `adopt` | Own their tables | A baseline `AdoptExistingSchema` at `lib/migrations/adopt_existing_schema.dart`, whose `name` carries the stamp: changes nothing on this database, creates the tables on an empty one. Written once; a project with a baseline keeps it |
| `external` | `@Resource(managesSchema: false, ...)` | None. Run `beak migrate` once for Beak's own tables (`_beak_commit_receipts`, `_beak_outbox`, `worm_migrations`): saves fail without them, and it touches none of yours |

What it decides for you, and says so:

- Display column: The best-named of `name`, `title`, `label`, `email`, `code`, `subject` that the table has as a text column gets `@Display()`. `varchar` becomes `String`, `text` becomes `BeakText`.
- Column names: A column whose name is not what its field name gives back (`firstName`, `address_line_1`, `Email`) keeps its stored name with `@Column(columnName:)`. A name Dart cannot spell as a field (`class`, `2fa`) gets a field name it can, such as `classValue`, under the same option.
- Keys not called `id`: Beak keys a record by a column called `id`. A table without one gets a `!` note, because it cannot be read or written until it has one.
- Integer keys: A table whose primary key is an integer `id` (a serial or an SQLite `INTEGER PRIMARY KEY`) is written with `late final int? id;`. The server mints a string id only for a string key and leaves an integer one to the database, and every foreign key that points at the table takes the key's type.
- Numbers: A `numeric` or `decimal` column is read as a `double`, with a note that it can round. An exact `BeakDecimal` is stored as integer units, so switching a column means converting it in a migration.
- Existing files: Running it again over a schema file that was edited refuses, names the file and writes nothing. `--force` replaces it, and `--only` or `--except` leaves the table out. A file that already holds exactly what would be written is reported as `unchanged`.
- Secrets: A column with the word `password`, `secret` or `token` in its name (`password_hash`, `card_token`, `passwordHash`), or an api, private, secret, access or signing key (`api_key`), is omitted with a `!` note.
- Class names: A table whose singular is a name the generated code needs (`lists`, `strings`, `resources`, `columns`, `schemas`) gets a class called `ListEntry`, `StringEntry` and so on, with `@Resource(table: 'lists')` saying which table it is.
- Pivots: A table that is only two foreign keys is a relationship, not a resource, and is skipped.
- Bookkeeping: `migrations`, `worm_migrations`, Beak's own `_beak_commit_receipts` and `_beak_outbox`, other frameworks' migration tables (Prisma, Django, Flyway, Alembic, Knex, EF, `schema_migrations`) and `serverpod_migrations` are skipped. Another tool's table switches the default to `external`, with a note.
- Serverpod: A database with `serverpod_*` tables is refused (exit `1`); its admin app belongs in the Serverpod workspace, see [Serverpod](../serverpod/index.md).

> **Note: beak introspect --help**
>
> ```console
> Write Beak models for the tables an existing database already has.
>
> Usage: beak introspect <database-url>
> -h, --help              Print this usage information.
>     --out=<dir>         Write every schema file flat into this directory, instead of into lib/resources/<table>/models/ for each table.
>     --schema            Postgres schema to read.
>                         (defaults to "public")
>     --only              Only these tables.
>     --except            Every table but these.
>     --ownership         Who owns the schema from here on. Defaults to adopt, or to external when another tool's migration history is in the database.
>
>           [adopt]       Beak owns the tables; a baseline migration records them.
>           [external]    Another system owns them; Beak writes no migration.
>
>     --save-url          Write DATABASE_URL=<url> into .env, where the server reads it.
>     --force             Replace schema files that already exist and differ from what the database implies.
>     --dry-run           Report what would be written without writing it.
> ```

## beak eject

Writes a Beak default out as a file the project owns, pre-filled so that it compiles and changes nothing until your first edit.

```console
beak eject <main|panel|resource|theme|auth|server> [table] [--force]
```

```dart title="packages/beak_cli/lib/src/commands/eject_command.dart"
/// `lib/main.dart` — an authored `BeakPanel(resources: [...])` in place of
/// the generated entrypoint.
main('main', 'lib/main.dart, composed by you instead of generated'),

/// `lib/panel.dart` — the last word on the whole panel config.
panel('panel', 'lib/panel.dart'),

/// A `BeakResource` class for one model, without taking the whole panel.
resource(
  'resource',
  'lib/resources/<table>/<name>_resource.dart (takes a table name)',
),

/// `lib/theme.dart` — the light and dark themes.
theme('theme', 'lib/theme.dart'),

/// `lib/auth.dart` — which auth routes exist and what they call.
auth('auth', 'lib/auth.dart'),

/// `lib/server.dart` — policy, sessions, middleware, extra routes, graph
/// rules and the outbox schedule.
server('server', 'lib/server.dart');

```

| Target | Writes | Picked up by |
| --- | --- | --- |
| `main` | `lib/main.dart` as an authored `BeakPanel(resources: [...])` listing every resource the generated panel showed, and removes `/lib/main.dart` from `.gitignore` | `prepare` never rewrites it again |
| `panel` | `lib/panel.dart`: `BeakPanelConfig beakPanel(BeakPanelConfig defaults) => defaults;` | the generated `panel.g.dart` |
| `resource <table>` | `lib/resources/<table>/<name>_resource.dart`, a `BeakResource` subclass for the model of that table, with the `beak.yaml` icon, label and section written in | the generated panel, in place of the default resource |
| `theme` | `lib/theme.dart`: `beakLightTheme()` and `beakDarkTheme()` | `panel.g.dart` |
| `auth` | `lib/auth.dart`: `BeakAuthConfig beakAuth()` | `panel.g.dart` |
| `server` | `lib/server.dart`: `BeakServer beakServer(BeakServerDefaults defaults)` with the options documented in its comment | `server.g.dart` |

The four override files are found by name and function, quoted from the scanner:

```dart title="packages/beak_cli/lib/src/project/beak_discovery.dart"
/// The convention files a project may supply to override a Beak default.
///
/// Each is optional: absent means Beak uses its own default, and nothing
/// about it appears in the project.
enum BeakOverrideKind {
  /// `lib/panel.dart` — the whole panel config, last word.
  panel(path: 'panel.dart', symbol: 'beakPanel'),

  /// `lib/theme.dart` — light and dark themes.
  theme(path: 'theme.dart', symbol: 'beakLightTheme'),

  /// `lib/auth.dart` — auth routes and callbacks.
  auth(path: 'auth.dart', symbol: 'beakAuth'),

  /// `lib/server.dart` — middleware, extra routes and policy.
  server(path: 'server.dart', symbol: 'beakServer');

  const BeakOverrideKind({required this.path, required this.symbol});
```

```console
$ beak eject theme
  created lib/theme.dart

  run `beak prepare` to wire it up
$ beak eject resource nope
  No model declares the table "nope", did you mean notes?
```

An existing file is not replaced without `--force` (exit `1`). `eject resource` also refuses when the model already has a resource class, or when its table is `hidden: true` in `beak.yaml`, because a resource class is always shown. `eject main` on an authored `lib/main.dart` only un-ignores it and says `lib/main.dart is already yours`; with `--force` it writes the entrypoint again from what the generated panel would show, over the file. In an app whose `beak.yaml` sets `panel.entrypoint`, `lib/main.dart` is the app's own, and `eject main` refuses with exit `1`, `--force` or not. Which bootstrap suits you is on [Two ways to boot a panel](../start-here/generated-or-authored.md).

> **Note: beak eject --help**
>
> ```console
> Write a Beak default out as a file this project owns.
>
> Usage: beak eject <main|panel|resource|theme|auth|server>
> -h, --help     Print this usage information.
>     --force    Overwrite the file if it already exists, `lib/main.dart` of `eject main` included.
> ```

## beak docs

Copies the docs of the Beak version the project resolved to `.dart_tool/beak/docs/`, where a coding agent can read pages that match the code it is writing.

```console
beak docs [--path] [--json] [--root <dir>]
```

| Flag | Meaning |
| --- | --- |
| `--path` | Print only the absolute path of the docs folder |
| `--json` | Print `version`, `path`, `index`, `source` and `pages` as JSON |
| `--root` | The pub workspace root, when walking up from the project does not find it |

```console
$ beak docs
  docs   Beak 0.9.0 · 186 pages · .dart_tool/beak/docs/
  start  ai-index: .dart_tool/beak/docs/ai-index.md
```

The docs ship inside `beak_core`, so the project needs `flutter pub get` first; without a resolved package it prints `docs  not available: <reason>` and exits `1`. A models-only package exits `0` with a note. `prepare` and `agents` refresh the copy too; see [Machine-readable docs](../ai/machine-readable-docs.md).

> **Note: beak docs --help**
>
> ```console
> Copy the docs of the resolved Beak version to .dart_tool/beak/docs.
>
> Usage: beak docs [--path] [--json] [--root <dir>]
> -h, --help          Print this usage information.
>     --path          Print only the absolute path of the docs folder.
>     --json          Print version, path, index, source and page count as JSON.
>     --root=<dir>    The pub workspace root, when it cannot be found by walking up from this project.
> ```

## beak agents

Writes what a coding agent needs in the project: a managed block in `AGENTS.md`, a `CLAUDE.md` that imports it, the docs copy, and Beak's workflow skills.

```console
beak agents [--skills claude,agents,cursor|none] [--[no-]instructions]
            [--[no-]docs] [--check] [--dry-run] [--print] [--force]
            [--remove] [--root <dir>]
```

| Flag | Default | Meaning |
| --- | --- | --- |
| `--skills` | `agents.skills` in `beak.yaml`, else the agent folders the workspace has, else `claude` and `agents` | Where to install skills: `.claude/skills`, `.agents/skills`, `.cursor/skills` |
| `--[no-]instructions` | `agents.instructions` in `beak.yaml` | Write `AGENTS.md` and `CLAUDE.md` |
| `--[no-]docs` | `agents.docs` in `beak.yaml` | Copy the docs to `.dart_tool/beak/docs` |
| `--check` | off | Write nothing; exit `1` when `AGENTS.md`, `CLAUDE.md` or a skill would change |
| `--dry-run` | off | Write nothing; print what would change |
| `--print` | off | Print the `AGENTS.md` block and write nothing |
| `--force` | off | Replace skills that were edited |
| `--remove` | off | Strip the blocks, delete a `CLAUDE.md` that only imports `AGENTS.md`, uninstall unedited skills |
| `--root` | found by walking up | The pub workspace root |

```console
$ beak agents
  agents   AGENTS.md updated
  docs     Beak 0.9.0
  skills   .claude/skills: 7 installed
  skills   .agents/skills: 7 installed
$ beak agents --check
  docs     Beak 0.9.0
  skills   .claude/skills: 7 up to date
  skills   .agents/skills: 7 up to date
$ beak agents --remove --dry-run
  would delete CLAUDE.md
  would strip the block from AGENTS.md
  skills   .claude/skills: 7 to be removed
  skills   .agents/skills: 7 to be removed
```

Beak edits `AGENTS.md` only between `<!-- BEGIN:beak-agent-rules -->` and `<!-- END:beak-agent-rules -->` and keeps everything else byte for byte; damaged markers make it stop with exit `1`. A run with nothing to change writes nothing, so `--check` is a CI gate. The skills come from the resolved packages (six in `beak`, one in `beak_frontend`, and `beak-serverpod-setup` in `beak_serverpod`) and carry a `.beak-skill.json`, so an edited skill is kept unless `--force`. The block's wording follows the project kind: standalone, embedded (`panel.entrypoint` names a file other than `lib/main.dart`) or Serverpod admin (a dependency on `beak_serverpod_flutter` and the tunnel to a Serverpod server: a use of `serverpodBeakDataSource`, or a package in the workspace that depends on `beak_serverpod_server`). An app that depends on `beak_serverpod_flutter` for its sign-in screens alone, as the client bridge does, gets the standalone or embedded block. Setup and the block content are on [Set up your agent](../ai/setup.md); the `agents:` keys are in [beak.yaml](beak-yaml.md#agents).

> **Note: beak agents --help**
>
> ```console
> Write the AGENTS.md block, CLAUDE.md, docs and skills for coding agents.
>
> Usage: beak agents [--skills claude,agents,cursor|none] [--[no-]instructions] [--[no-]docs] [--check] [--dry-run] [--print] [--force] [--remove] [--root <dir>]
> -h, --help                                  Print this usage information.
>     --skills=<claude,agents,cursor|none>    Where to install the workflow skills: any of claude, agents and cursor, comma separated, or none. Defaults to agents.skills in beak.yaml, then the agent folders the workspace has.
>     --[no-]instructions                     Write AGENTS.md and CLAUDE.md. Defaults to beak.yaml.
>     --[no-]docs                             Copy the docs to .dart_tool/beak/docs. Defaults to beak.yaml.
>     --check                                 Write nothing; exit 1 when AGENTS.md, CLAUDE.md or a skill would change.
>     --dry-run                               Write nothing; print what would change.
>     --print                                 Print the AGENTS.md block and write nothing.
>     --force                                 Replace skills that were edited.
>     --remove                                Undo it: strip the blocks, delete a CLAUDE.md that only imports AGENTS.md, and uninstall unedited skills.
>     --root=<dir>                            The pub workspace root, when it cannot be found by walking up from this project.
> ```

## beak doctor

Diagnoses the project it runs in. It takes one flag, `--json`, and exits `1` only when a check fails; a warning does not fail it.

```console
$ beak doctor
  OK   project depends on Beak
  OK   beak.yaml parses
  OK   discovered 2 models · 2 resource classes · screens and overrides not applicable (lib/main.dart is authored)
  OK   lib/main.dart lists every resource class
  OK   generated files up to date
  OK   every model has a migration
  OK   web/ scaffold present
  OK   no panel file imports the server
  OK   no DATABASE_URL: using the default SQLite file (beak.db)
  WARN products.sku is declared by Product.sku but missing from the database
       → beak make:migration AddSkuToProducts --from-drift, then beak migrate
  OK   AGENTS.md has the Beak 0.9.0 block
  OK   CLAUDE.md reads AGENTS.md
  OK   AGENTS.md is 2 KiB
  OK   docs bundle for Beak 0.9.0 is in .dart_tool/beak/docs
  OK   7 Beak skills installed, all current
  OK   CLI 0.9.0 matches project Beak 0.9.0
All checks passed.
```

`--json` prints `{"healthy": bool, "checks": [{"status", "label", "remedy"?, "group"?}]}` with `status` one of `ok`, `warn`, `fail`; the agent checks carry `"group": "agents"`.

| Check | `fail` when | `warn` when |
| --- | --- | --- |
| Dependency | `pubspec.yaml` missing, or no `beak` (or `beak_core`, `beak_frontend`, `beak_backend`) dependency | |
| `beak.yaml` | it does not parse: the key or the line is named, and the run stops there | |
| Discovery | a scan issue, or a `resources:` key naming no table | no models under `lib/` |
| Schema classes | a schema class `prepare` refuses, such as a `Uri` field or a missing `part` directive | |
| Entrypoint | | a `BeakResource` class the authored entrypoint does not list |
| Generated files | any expected file is missing or stale (`beak prepare`) | `panel.g.dart` and `app.g.dart` left over from a generated entrypoint that nothing imports |
| Migration imports | a migration imports a file that does not exist, a schema file that moved for instance | |
| Migrations | a model has no migration creating its table | |
| `web/` | | `web/index.html` missing |
| Server imports | a file the panel reaches imports `package:beak/server.dart` or `migrations.dart` | |
| Database | | Postgres not reachable; the schema unreadable; drift, see below |
| Agents | | `AGENTS.md` block missing or old; no `CLAUDE.md` reading it; `AGENTS.md` over 32 KiB; docs bundle missing or from another version; skills out of date; CLI and project differ in major or minor version |

The database check reads a SQLite file or a Postgres server, from `DATABASE_URL` or the default. `DATABASE_URL` comes from the process environment first and the project's `.env` second, the order the server uses. A SQLite file that does not exist yet is fine. Each drift line carries the fix that fits it: a table that is missing while a migration creates it says `beak migrate`, a column a class declares that the table lacks says `beak make:migration Add<Column>To<Table> --from-drift`, and a column no class declares says to declare the field or drop the column in a migration. A models-only package gets its own short list: schema classes read cleanly, parts current, and no import of `package:beak/`, `beak_frontend`, `beak_backend`, `flutter` or `dart:io`.

> **Note: beak doctor --help**
>
> ```console
> Diagnose this Beak project.
>
> Usage: beak doctor [arguments]
> -h, --help    Print this usage information.
>     --json    Report as JSON, for CI.
> ```

## Rules and limits

- Generated files are overwritten without asking; put your code in other files. Migrations and `bin/*.dart` entrypoints are the exceptions: migrations are written once, an entrypoint without the generated header is yours.
- `beak.yaml` is read by every command that generates. An unknown key is an error naming the key, see [beak.yaml](beak-yaml.md#errors).
- `create`, `make:migration`, `make:resource`, `eject` and `introspect` refuse to replace what exists; `make:migration`, `eject` and `introspect` take `--force`.
- `--fields` covers seven kinds. Everything else is an edit of the generated class.
- `introspect` reads Postgres and SQLite only.
- `make:migration --from-drift` adds columns. It does not create tables, drop columns or change types.
- `migrate` and `seed` need the project to compile: they run `dart run bin/migrate.dart`.

## Source

- `packages/beak_cli/bin/beak.dart` is the entry point and maps usage errors to `64`.
- `packages/beak_cli/lib/src/cli_runner.dart` registers the commands and holds `make:resource` and `make:migration`.
- `packages/beak_cli/lib/src/commands/` holds `create`, `init`, `prepare`, `dev` (with `migrate` and `seed`), `introspect`, `eject`, `docs`, `agents` and `doctor`.
- `packages/beak_cli/lib/src/field_spec.dart` parses `--fields`; `templates.dart` writes the scaffolds.
- `packages/beak_cli/lib/src/project/beak_project_config.dart` reads `beak.yaml`.
- `packages/beak_cli/lib/src/introspect/` reads live schemas and writes the introspected classes.
- `packages/beak_cli/lib/src/agents/` writes the agent files, docs copy and skills.
- `packages/beak_cli/README.md` is the short version of this page.

## Continue reading

- [beak.yaml](beak-yaml.md) the file every generating command reads.
- [Generated files and symbols](generated-files.md) what `prepare` writes, file by file.
- [Migrations](../backend/migrations.md) taking over and applying the migrations these commands write.
- [Set up your agent](../ai/setup.md) what `beak agents` installs and how agents use it.
