# A new project

> Make the first decisions of a greenfield Beak project, database, entrypoint and authentication, with the commands that set each one.

You have nothing yet and you are about to run `beak create`. Three choices are cheap now and awkward later: which database, which entrypoint and when to add sign-in. After this page you have made each one on purpose and know the command that changes it.

None of them is a trap. Every default runs, and every default can be swapped in a few lines. The point is to swap it because you decided to, not because a migration surprised you.

## At a glance

| Decision | Default | Change it when | How |
| --- | --- | --- | --- |
| Database | A SQLite file, `beak.db` | You need a second server process, a managed database or backups you do not run | `DATABASE_URL=postgres://...` in `.env` |
| Entrypoint | Generated: `beak prepare` writes `lib/main.dart` | You want theme, formatting, pages, navigation or auth in code you own | `beak create --authored`, or `beak eject main` later |
| Sign-in | None, and the API allows everything | The URL leaves your machine | `BeakPanel(auth:)` plus a server policy |
| First resource | The `Note` example | You know your domain | `beak create --no-example`, then `beak make:resource` |

The whole start, for a shop-like project with the entrypoint you will keep:

```bash
beak create shop --authored --no-example --beak-path "$PWD/beak"
cd shop
beak make:resource Product --fields name:string!,price:decimal!
# an authored panel shows a resource only once lib/main.dart lists it:
# add `const ProductResource()` to resources: [...], as make:resource prints
beak migrate
beak dev
```

`--beak-path` is the pre-release workaround from [Installation](../installation.md#the-release-is-not-tagged-yet), and the panel needs its `pubspec_overrides.yaml` until the obers_ui pin moves. Drop both once `v0.9.0` is tagged.

## Database: SQLite first, Postgres when it stops fitting

Start on SQLite. There is nothing to install, the schema classes and migrations are identical on both databases, and moving is one line in `.env`. Move earlier than you think if any of these is true:

| Situation | Why SQLite stops fitting |
| --- | --- |
| Two server processes will serve the API | SQLite runs on one connection. Each process also keeps its own session store and its own outbox worker. |
| The database is somebody else's job (a managed instance, a shared team server) | The file lives beside the process. |
| You need point-in-time backups or replication | Copying `beak.db` while the server runs can miss the newest writes. |

Moving later is not a rewrite: change `DATABASE_URL`, run `beak migrate` against the empty Postgres, and copy the data you care about. The row data is yours to move, because Beak does not ship a data-copy tool. [Databases](../../backend/databases.md) has the connection settings and what the same model becomes on each database.

## Entrypoint: generated for a day, authored for the project

The generated entrypoint is one line and needs no list of resources. The authored one is a file you read top to bottom:

```console
$ beak create shop --authored --no-example
...
$ cat shop/lib/main.dart
BeakPanel buildPanel({BeakDataSource? dataSource}) =>
    BeakPanel(title: 'Shop', resources: [], dataSource: dataSource);
```

Pick authored when you already know the panel needs a theme, a locale, custom pages, navigation or sign-in, because those are `BeakPanel` arguments and you would eject on day two anyway. Pick generated to look around. `beak eject main` converts one into the other without changing what the panel shows. [Two ways to boot a panel](../generated-or-authored.md) has both sides.

With an authored panel, `beak make:resource` tells you what to add:

```console
$ beak make:resource Product --fields name:string!,price:decimal!
  created lib/resources/products/models/product.dart
  created lib/resources/products/product_resource.dart
  1 model · 1 resource class · screens and overrides not applicable (lib/main.dart is authored)
  generated  4 of 7 files

  lib/main.dart is yours; register the resource there:
    import 'resources/products/product_resource.dart';
    const ProductResource(),  // in resources: [...]
```

## Authentication: later is fine, exposed is not

A new project has no sign-in. The panel renders for everyone and the API allows every request. That is the right state for a laptop and the wrong state for any URL another person can reach. `beak dev` listens on `0.0.0.0`, so the API is reachable from your network, and it prints a warning that says so; `HOST=127.0.0.1 beak dev` keeps it on your machine and silences the warning. Sign-in has two halves, and neither is enough alone:

- **Server.** Sessions say who is calling, and a policy says what they may do. Without a policy, `BeakServer` allows everything, whoever the caller is. [Auth and policies](../../backend/auth-and-policies.md) and [Security](../../shipping/security.md) close the seams in order.
- **Panel.** `BeakPanel(auth: ...)` puts a sign-in in front of the shell. It only hides UI. [Auth and idle-lock](../../panel/auth-and-idle-lock.md) covers it.

Do the server half before you share a link, not after.

## Rules and limits

- `beak create` refuses a directory that already has files. It exits `1` and writes nothing, so give it a new name or an empty directory.
- A project name is `lower_snake_case`, because it becomes the Dart package name. `beak create Acme` is a usage error (exit `64`).
- `beak create` runs `flutter pub get`, so it needs the network unless you pass `--no-pub`. With `--no-pub` you run `flutter pub get`, `beak prepare` and `beak agents` yourself.
- `beak prepare` on a project with no models succeeds, and says so. It prints ``no models yet: add a @Resource class under lib/, or run `beak make:resource Product`, then `beak prepare` again``.
- The default `.gitignore` keeps `beak.db`, `.env` and `storage/` out of git. A generated project also ignores `lib/main.dart`; an authored one commits it.
- Coding agents get a head start. `beak create` writes `AGENTS.md` and `CLAUDE.md` and installs the workflow skills into `.claude/skills` and `.agents/skills`. `--skills none` skips them, and `beak agents` updates them later.

## Verify it

```console
$ beak doctor
  OK   project depends on Beak
  OK   beak.yaml parses
  OK   discovered 1 model · 1 resource class · screens and overrides not applicable (lib/main.dart is authored)
  OK   lib/main.dart lists every resource class
  OK   migrations import files that exist
  OK   generated files up to date
  OK   every model has a migration
  ...
All checks passed.
```

`lib/main.dart lists every resource class` is the check an authored project adds: it warns, naming the class and its file, for each `BeakResource` subclass your `main.dart` leaves out. Then `flutter test` boots the panel against an in-memory data source.

## Reference

| Step | Command |
| --- | --- |
| Scaffold, generated entrypoint, with the example | `beak create <name>` |
| Scaffold, authored entrypoint, empty | `beak create <name> --authored --no-example` |
| Add a resource | `beak make:resource <Name> --fields name:string!,price:decimal!` |
| Create the tables | `beak migrate` |
| Serve the API | `beak dev` |
| Switch to Postgres | `DATABASE_URL=postgres://user:pass@host:5432/db` in `.env`, then `beak migrate` |
| Take over the entrypoint | `beak eject main` |
| Check everything | `beak doctor` |

## Continue reading

- [Quickstart](../quickstart.md): the same start with the generated entrypoint, run end to end.
- [Tutorial](../../tutorial/index.md): the authored path, growing a shop chapter by chapter.
- [Databases](../../backend/databases.md): SQLite, Postgres and what Beak does with the connection.
- [Choose your path](index.md): the other starting points.
