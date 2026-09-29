# beak_cli

The `beak` command. It scaffolds a project, generates the wiring from your
annotated schema classes, runs your migrations, adopts a database you already
have, writes the files a coding agent reads, and tells you what is wrong with a
project before you find out the hard way.

Part of [Beak](https://github.com/SimonErich/beak), a configuration-driven
admin-panel framework for Dart and Flutter. It is pure Dart.

## When you install it

Once, globally. A project never depends on `beak_cli`; it depends on
[`beak`](https://github.com/SimonErich/beak/tree/main/packages/beak). The only
reason to import this package is to run the CLI from a `bin/` file of your own
(see [Embedding](#embedding)).

```console
$ git clone https://github.com/SimonErich/beak.git
$ dart pub global activate --source path beak/packages/beak_cli
$ beak --version
beak 0.9.0
```

The pubspec declares `beak` as an executable, so activating the package puts it
on your `PATH` (`$HOME/.pub-cache/bin` on macOS and Linux).

## Start a project

```console
$ beak create acme_admin --beak-path ~/src/beak
$ cd acme_admin
$ beak migrate
$ beak dev
  1 model · 0 resource classes · 0 screens · 0 overrides
  generated  up to date (8 files)
  panel      run this in another terminal:
               flutter run -d chrome
  api        starting…
```

`beak create` refuses a directory that already has files. It writes the
pubspec, `beak.yaml`, one example schema class, a
widget test, `AGENTS.md`, `CLAUDE.md`, a README and Flutter's `web/` scaffold,
then runs `flutter pub get`, `beak prepare` and `beak agents`, so the project is
runnable as created. `beak dev` serves the API on `:8080` (`PORT` or
`server.port` change it) and prints the line that starts the panel; it does not
spawn Flutter for you.

Two things are not ready yet, and both go away at release:

- **The tag.** Without `--beak-path`, the scaffold depends on the Beak repository
  at `ref: v0.9.0`, and that tag does not exist until the release is cut. Until
  then pass `--beak-path <repo root of a checkout>` or `--beak-ref <branch>`.
- **The obers_ui pin.** The panel builds on obers_ui, pinned by git commit, and
  the pinned commit predates obers_ui components `beak_frontend` uses today,
  which are not published yet. A project created outside the Beak repository
  needs `dependency_overrides` for the three obers_ui packages pointing at a
  local checkout until the pin moves. The
  [root README](https://github.com/SimonErich/beak#getting-it-running-today)
  shows how.

## Commands

| Command | What it does |
| --- | --- |
| `beak create <name>` | Scaffold a project and get it running. |
| `beak init` | Add the panel to a Flutter app that already exists. |
| `beak prepare` | Regenerate the wiring from the schema classes, resource classes, screens and `beak.yaml`. |
| `beak dev` | Prepare, serve the API, print the `flutter run` line. |
| `beak migrate [status\|up\|down\|fresh\|refresh]` | Apply, inspect or roll back migrations. |
| `beak seed` | Run the seeders. |
| `beak make:resource <Name>` | Scaffold a schema class and its resource class. |
| `beak make:migration <Name>` | Scaffold a migration; `--from-drift` fills it in. |
| `beak introspect <database-url>` | Write schema classes for the tables a database already has. |
| `beak eject <main\|panel\|resource\|theme\|auth\|server>` | Write a Beak default out as a file you own. |
| `beak agents` | Write the `AGENTS.md` block, `CLAUDE.md`, the docs and the workflow skills. |
| `beak docs` | Copy the docs of the resolved Beak version to `.dart_tool/beak/docs`. |
| `beak doctor` | Diagnose the project. |

`beak --version` prints the version, and `beak help <command>` prints the flags
of one command. Misuse prints the usage message and exits `64`.

### create

`beak create <name> [--authored] [--[no-]example] [--[no-]pub] [--skills ...]
[--beak-ref <ref> | --beak-path <path>]`

| Flag | Effect |
| --- | --- |
| `--beak-path <path>` | Depend on a local Beak checkout instead of git. Give the repository root, as an absolute path: `packages/<name>` is appended and the result goes into the pubspec as written, so a relative path is resolved from the new project. |
| `--beak-ref <ref>` | The git ref to depend on. Defaults to `v0.9.0`, the version of this CLI. |
| `--authored` | Write a `lib/main.dart` you own: a `BeakPanel(resources: [...])`, a `NoteResource` and a smoke test. |
| `--no-example` | Leave out the `Note` example, so you start from `beak make:resource`. A panel needs a resource to show, so the generated widget test only checks the registry until you add one. |
| `--no-pub` | Write the files and stop. It prints `flutter pub get`, `beak prepare` and `beak agents` for you to run, for a machine without a network. |
| `--skills claude,agents,cursor\|none` | Where the workflow skills go. Without it: the agent folders the project has, then `.claude` and `.agents`. |

`create` needs the network for `flutter pub get` unless you pass `--no-pub`.

### prepare and dev

`beak prepare` reads every schema class under `lib/` and writes its
`*.beak.dart` part, then finds the models, `BeakResource` classes, screens,
migrations and seeders, reads `beak.yaml`, and writes the registry, the panel
config, the app widget, the server host and the three entrypoints. A file whose
content is unchanged is not rewritten. The panel config and the app widget belong
to a generated `lib/main.dart`: with an authored one, or a `panel.entrypoint`,
nothing imports them, so they are neither written nor compared, and a pair a
generated entrypoint left behind is deleted. The `generated` line counts the
schema parts among the files it considered, and a project with no model yet gets
a `no models yet` note. `prepare`, `dev`, `migrate`, `seed`, `make:resource` and
`eject main` refuse a directory that is not a Beak project. A `beak.yaml` that is not valid YAML is
reported with file, line and column, and exits `1`.

Every other command that needs the wiring runs `prepare` first. The generated
files are `lib/beak/*.g.dart`, `*.beak.dart`, the create-table migrations under
`lib/migrations/`, and `lib/main.dart`, `bin/serve.dart` and `bin/migrate.dart`
in generated mode.

`beak dev [-d <device>] [--no-serve]` prepares, prints the `flutter run` line for
`<device>` (default `chrome`, plus `-t <entrypoint>` when `beak.yaml` sets
`panel.entrypoint`), and runs `bin/serve.dart`. `--no-serve` stops after the
print. The server stops cleanly on SIGINT and SIGTERM.

### migrate and seed

`beak migrate` and `beak seed` prepare, then run the project's own
`bin/migrate.dart`. Its output is yours and its exit code is theirs:

```console
$ beak migrate
migrated  20260926_000000_beak_commit_receipts
migrated  20260927_000000_beak_outbox
migrated  20260929_121844_create_notes_table
$ beak migrate status              # what ran, what is pending
$ beak migrate up --pretend        # print the SQL, run nothing
$ beak migrate down --steps 2      # roll back two batches
$ beak migrate fresh --seed        # drop everything, migrate, seed (also: refresh)
$ beak seed --class UserSeeder     # one seeder; also --env <name> and --force
$ beak migrate status -- --other   # what follows -- goes to worm untouched
```

| Flag | For | Effect |
| --- | --- | --- |
| `--pretend` | `up` | Print the SQL without running it. |
| `--step N` | `up` | Apply at most N migrations. |
| `--steps N` | `down` | Roll back N batches. |
| `--seed` | `fresh` | Run the seeders afterwards. |
| `--force` | `fresh`, `refresh` | Allow it when `WORM_ENV=production`. |

A flag the verb does not take is a usage error (`64`). `fresh` and `refresh` read
`WORM_ENV` the way the server does, from the environment over `.env`, and refuse
in production without `--force`.

Beak does not apply migrations when the server boots. The one exception is
`DATABASE_URL=sqlite::memory:`, a database that exists only inside the serving
process. The database is a SQLite file (`beak.db`) until `DATABASE_URL` says
otherwise.

### make:resource and make:migration

```console
$ beak make:resource Product --fields name:string!,price:decimal!,active:bool
```

`--fields` takes comma-separated `name:kind` pairs, with `kind` one of `string`,
`text`, `int`, `decimal` (an exact `BeakDecimal`), `double`, `bool` or `datetime`. A trailing `!` marks the field
required; without it the Dart type is nullable. The command writes the schema
class `lib/resources/products/models/product.dart` and its resource class
`lib/resources/products/product_resource.dart`, refuses to overwrite either, and
runs `prepare`. In a project whose `lib/main.dart` is authored it prints the
import and the `ProductResource(),` line to add there.

`beak make:migration <Name>` writes `lib/migrations/<snake_name>.dart` with a
timestamped `name`, which is what worm orders migrations by, and refuses a file
of that name that exists unless `--force`. The generated host lists a
create-table migration behind the ones that create the tables its foreign keys
point at, whatever the names say. With `--from-drift`
it compares the schema classes with the live database and fills the migration in.
Each column is added only when the live table lacks it (so a fresh database, which
already got it from the create-table migration, is fine), and a belongs-to key
gets its index and foreign key as on create. It reads Postgres and SQLite, and
stops with a message when the database does not exist yet or is in-memory SQLite.
`DATABASE_URL` is read from the environment over `.env`, as the server reads it.

### introspect and init

`beak introspect <database-url>` reads a Postgres or SQLite schema (types,
nullability, defaults, foreign keys, enum labels) and writes the annotated schema
class of each table to `lib/resources/<table>/models/`.

| Flag | Effect |
| --- | --- |
| `--ownership adopt` | The default. Beak owns the tables. It writes a baseline migration, `lib/migrations/<stamp>_adopt_existing_schema.dart`, that changes nothing on this database and builds the tables on an empty one. |
| `--ownership external` | Another system owns the tables. The classes are marked `managesSchema: false` and no migration is written. Chosen for you when the database carries another tool's migration history. |
| `--save-url` | Write `DATABASE_URL=<url>` into `.env`. |
| `--only`, `--except` | Restrict the tables. |
| `--schema <name>` | The Postgres schema to read. Defaults to `public`. |
| `--out <dir>` | Write every schema file flat into this directory instead of one folder per table. With `adopt` it must be under `lib/`. |
| `--force` | Replace schema files that exist and differ from what the database implies. Without it, running again refuses and writes nothing. |
| `--dry-run` | Report what would be written. |

A column that looks like a secret is left out and reported, and a `numeric`
column is read as a `double` with a note that it can round. An integer `id` is
declared as `int? id`. Beak's own `_beak_commit_receipts` and `_beak_outbox` are
skipped. A Serverpod database is refused: its admin belongs in the Serverpod
workspace.

`beak init` adds Beak to an app that already exists. It adds the dependency,
writes a `beak.yaml` that records `panel.entrypoint`, an authored entrypoint
(`lib/admin_main.dart`, or `lib/main.dart` when the app has none), and a
`.gitignore` block, and never rewrites the app's own files. It is idempotent.

```console
$ beak init --dry-run
  would add the beak dependency to pubspec.yaml
  would create beak.yaml
  would create lib/admin_main.dart
  would update .gitignore
  analysis_options.yaml is yours, so Beak leaves it alone. Its files are written for these flags:
    analyzer:
      language:
        strict-casts: true
        strict-inference: true
        strict-raw-types: true
```

This is a fresh `flutter create` app, whose `.gitignore` already exists (it says
`create` when the app has none), and whose `analysis_options.yaml` Beak tells
you about instead of rewriting.

The panel then starts with `flutter run -t lib/admin_main.dart`. Flags:
`--entrypoint <path>` (directly under `lib/`), `--beak-ref`, `--beak-path`,
`--example` (also write a `Note`), `--[no-]pub` and `--dry-run`. It refuses a
project that is not Flutter, and a Serverpod workspace (the message names the
admin app and the client bridge).

### eject

`beak eject <target> [--force]` writes a default out as a file you own. `--force`
replaces a file that exists, `eject main` on an authored `lib/main.dart`
included.

| Target | File |
| --- | --- |
| `main` | `lib/main.dart`, as an authored `BeakPanel(resources: [...])` listing what the generated panel showed. |
| `resource <table>` | `lib/resources/<table>/<name>_resource.dart`, a `BeakResource` seeded from the table's `beak.yaml` icon, label and section. Refuses a table marked `hidden: true`. |
| `panel` | `lib/panel.dart`, the last word on the whole panel config. |
| `theme` | `lib/theme.dart`, the light and dark themes. |
| `auth` | `lib/auth.dart`, which auth routes exist and what they call. |
| `server` | `lib/server.dart`, with every hook `defaults.build` accepts. |

### agents and docs

An agent's training data is older than the Beak it is asked to write. Two
commands put the right version in front of it.

```console
$ beak agents
  agents   AGENTS.md updated
  docs     Beak 0.9.0
  skills   .claude/skills: 7 installed
  skills   .agents/skills: 7 installed
$ beak agents --check      # write nothing; exit 1 while a file or skill would change
$ beak docs
  docs   Beak 0.9.0 · 186 pages · .dart_tool/beak/docs/
  start  ai-index: .dart_tool/beak/docs/ai-index.md
```

`beak agents` keeps a block in `AGENTS.md` between
`<!-- BEGIN:beak-agent-rules -->` and `<!-- END:beak-agent-rules -->` and leaves
every other byte alone; a file with damaged markers is refused, not guessed at.
It creates a `CLAUDE.md` holding `@AGENTS.md` unless one exists, copies the docs
of the resolved `beak_core` to `.dart_tool/beak/docs`, and installs the workflow
skills the Beak packages ship. Flags: `--skills claude,agents,cursor|none`,
`--[no-]instructions`, `--[no-]docs`, `--check`, `--dry-run`, `--print` (render
the block and write nothing), `--force` (replace skills you edited), `--remove`
and `--root <dir>` (the pub workspace root). `beak docs` takes `--path`, `--json`
and `--root`. `create`, `prepare` and `init` refresh the same files.

### doctor

`beak doctor [--json]` checks the project it runs in and exits `1` while a check
fails: Beak dependency, `beak.yaml`, discovered models, schema classes that
`prepare` would refuse, generated files current, that every import of a
migration resolves, a migration per model, the `web/` scaffold, that no panel
file imports the server, the database (default SQLite counts as passing; the
URL comes from the environment over `.env`), drift between the database and the
schema classes, each with the command that fixes it, the agent files, and the CLI against the
project's Beak version. In an authored project it warns about each
`BeakResource` class that `lib/main.dart` does not list.

```console
$ beak doctor
  OK   project depends on Beak
  OK   beak.yaml parses
  OK   discovered 1 model · 0 resource classes · 0 screens · 0 overrides
  OK   generated files up to date
  OK   every model has a migration
  ...
  OK   CLI 0.9.0 matches project Beak 0.9.0
All checks passed.
```

## Generated or authored panel

A project boots its panel one of two ways, and both are supported.

- **Generated** (the default). `lib/main.dart` runs the `BeakApp` that
  `beak prepare` builds from every model. Each model gets a default resource,
  presented as `beak.yaml` says, and any public `BeakResource` subclass under
  `lib/` with a zero-argument constructor replaces the default of its model.
  `beak prepare` rewrites the file, so it is git-ignored.
- **Authored.** `lib/main.dart` is a `BeakPanel(resources: [...])` you own and
  commit; `beak prepare` never rewrites it, and you add each resource class to the
  list. `beak create --authored` starts this way, and `beak eject main` switches
  an existing project.

[Two ways to boot a panel](https://simonerich.github.io/beak/start-here/generated-or-authored/)
compares them.

## beak.yaml

Every key is optional, and an unknown key is an error that names it.

| Key | Meaning |
| --- | --- |
| `name` | The panel title. Defaults to the title-cased package name. |
| `api.baseUrl` | The origin the panel calls, `http://localhost:8080` by default. `auto` means the origin the panel was served from. |
| `server.port`, `server.host` | Defaults for the generated server host. A real `PORT` or `HOST` in the environment still wins. |
| `panel.entrypoint` | The Dart file that boots the panel, when it is not `lib/main.dart`. `prepare` never writes `lib/main.dart` then, and `beak dev` prints `-t <entrypoint>`. |
| `agents.instructions` | `all`, `package` or `none`: which `AGENTS.md` files Beak keeps its block in. |
| `agents.docs` | Whether `prepare` copies the docs to `.dart_tool/beak/docs`. Default `true`. |
| `agents.skills` | A list of `claude`, `agents` and `cursor`; `[]` installs none. |
| `theme.sidebar.collapsible`, `theme.sidebar.startCollapsed` | Sidebar behavior. |
| `resources.<table>.icon`, `.label`, `.section`, `.hidden` | Presentation of a generated default resource. |

The [beak.yaml reference](https://simonerich.github.io/beak/reference/beak-yaml/)
has the details.

## Packages of schema classes only

A pure Dart package that only holds schema classes, shared by a server and an
admin that live elsewhere, depends on `beak_core` and on none of `beak`,
`beak_frontend` and `beak_backend`. There `beak prepare` writes the
`*.beak.dart` parts and `lib/beak/registry.g.dart` and nothing else: no panel or
server wiring, no entrypoint, no migration, and no `beak.yaml` to read.
`beak doctor` checks what applies there, and `beak agents` and `beak docs` say
there is no Beak app and exit `0`.

## Embedding

To run the CLI from your own `bin/beak.dart`, forward to `createBeakRunner`. This
is the package's own entry point:

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

The library exports four names and nothing else, so the commands, emitters and
schema reader can change without a breaking release:

| Name | What it is |
| --- | --- |
| `createBeakRunner` | Builds the `CommandRunner<int>` with every command registered. |
| `BeakCliEnvironment` | The injectable seams: `out`, `rootDirectory`, `now`, `probe`, `processEnvironment` (empty unless given, so a test never reads the machine's variables), and two process runners, `runProcess` (captures a command's output) and `runInteractive` (hands it the terminal). `BeakCliEnvironment.production()` outside tests. |
| `BeakPortProbe`, `BeakProcessRunner` | The types of the probe and the process runners. |

## Limits

- **Online by default.** `beak create` runs `flutter pub get`. Pass `--no-pub` on
  a machine without a network and run the printed steps later.
- **Docs need a resolved project.** `beak docs` and `beak agents` read the
  `beak_core` your `.dart_tool/package_config.json` points at, so run
  `flutter pub get` first.
- **The CLI does not watch files.** `beak dev` prepares once at start; run
  `beak prepare` after you change a schema class.

## Continue reading

- [CLI commands](https://simonerich.github.io/beak/reference/cli-commands/): every command and flag.
- [beak.yaml](https://simonerich.github.io/beak/reference/beak-yaml/): every key.
- [Two ways to boot a panel](https://simonerich.github.io/beak/start-here/generated-or-authored/): generated or authored.
- [Migrations](https://simonerich.github.io/beak/backend/migrations/): the migrations `prepare` writes and the ones you write.
- [AI directory](https://simonerich.github.io/beak/ai/): what `beak agents` and `beak docs` give a coding agent.

## Status

Pre-1.0 and versioned in lockstep with the other `beak_*` packages (0.9.0). Not on pub.dev yet: depend on it from git with `ref: v0.9.0` once that tag exists, or from a checkout with `path:`. What changed: the [root changelog](https://github.com/SimonErich/beak/blob/main/CHANGELOG.md). Contributing: [CONTRIBUTING.md](https://github.com/SimonErich/beak/blob/main/CONTRIBUTING.md).

## License

Apache-2.0 © Marqably GmbH. See [LICENSE](https://github.com/SimonErich/beak/blob/main/LICENSE).
