---
title: An existing Flutter app
description: Add a Beak admin panel to a Flutter app you already have with beak init, keep your own main.dart, and choose how the panel meets your router and session.
type: guide
audience: [expert]
status: stable
---

# An existing Flutter app

You have a Flutter app with its own `lib/main.dart`, router and (probably) sign-in. After this page you have Beak in it: a second entrypoint that boots the panel, an API to talk to, and a clear view of the two deeper ways to fold the panel into your app.

The rule that shapes the path is that your files stay yours. `beak init` adds files next to your app and never rewrites one of yours.

## At a glance

| | |
| --- | --- |
| Command | `beak init` in the root of the Flutter app |
| Adds | The `beak` dependency, `beak.yaml` with `panel.entrypoint`, an authored `lib/admin_main.dart`, a `.gitignore` block |
| Leaves alone | `lib/main.dart`, your router, your theme, your `analysis_options.yaml` |
| Runs | `flutter pub get`, then `beak prepare` (skip both with `--no-pub`) |
| Refuses | A pubspec without `flutter: sdk: flutter`; a project inside a Serverpod workspace |
| Idempotent | Yes. A second run repairs what is missing and writes nothing else |

```bash
cd my_flutter_app
beak init --beak-path "$PWD/../beak" --example --dry-run   # report, write nothing
beak init --beak-path "$PWD/../beak" --example
```

`--beak-path` is the pre-release workaround from [Installation](../installation.md#the-release-is-not-tagged-yet); the panel needs its `pubspec_overrides.yaml` too until the obers_ui pin moves. Drop both once `v0.9.0` is tagged.

## Add Beak

The dry run lists exactly what would change:

```console
$ beak init --example --dry-run
  would add the beak dependency to pubspec.yaml
  would create beak.yaml
  would create lib/admin_main.dart
  would create lib/resources/notes/models/note.dart
  would create lib/resources/notes/note_resource.dart
  would update .gitignore
  analysis_options.yaml is yours, so Beak leaves it alone. Its files are written for these flags:
    analyzer:
      language:
        strict-casts: true
        strict-inference: true
        strict-raw-types: true
```

The entrypoint is `lib/main.dart` only when the app has none. An app that has one gets `lib/admin_main.dart`, and `--entrypoint <path>` picks another file directly under `lib/`. What lands, apart from the `Note` example:

| File | What it holds |
| --- | --- |
| `pubspec.yaml` | One added dependency on `beak`. Comments and layout survive, because the edit is in place. |
| `beak.yaml` | Your app's name, the API origin, and `panel.entrypoint: lib/admin_main.dart`. |
| `lib/admin_main.dart` | An authored `BeakPanel(resources: [...])`. Yours, never rewritten. |
| `.gitignore` | A `# BEGIN beak` … `# END beak` block for `bin/serve.dart`, `bin/migrate.dart`, `*.db*`, `storage/` and `.env`. |

`panel.entrypoint` is the setting that keeps your `lib/main.dart` safe: while it is set, `beak prepare` writes everything except `lib/main.dart` and does not compare it. `beak dev` then prints the matching run line. [Two ways to boot a panel](../generated-or-authored.md) explains the mechanism.

The strictness note in that output is informational. Beak writes its files to pass `strict-casts`, `strict-inference` and `strict-raw-types`, and leaves your `analysis_options.yaml` as it is. On a stock `flutter create` app, `flutter analyze` after `beak init` reports no issues; if your app runs stricter rules than that, run it once and read what it says.

## Run the API and the panel

The panel needs the API, and the API needs a database. Same three commands as any Beak project:

```bash
beak migrate      # creates the notes table, in a SQLite file beside pubspec.yaml
beak dev          # serves the API on :8080 and prints the flutter run line
flutter run -d chrome -t lib/admin_main.dart
```

Your own app still runs with a plain `flutter run`. The two entrypoints share the package and nothing else: Beak's panel calls the API at `api.baseUrl` from `beak.yaml` (`--dart-define=BEAK_API_BASE_URL=...` overrides it per build), and your app keeps talking to whatever it talked to before.

## Choose how the panel meets your app

`beak init` gives you the first level. The other two exist for an app that wants the panel inside its own navigation.

| Level | You get | You provide |
| --- | --- | --- |
| A second entrypoint | The whole panel, booted from `lib/admin_main.dart`, deployed as its own web build | Nothing beyond `beak init` |
| Panel routes in your router | The panel's pages under your `GoRouter`, with your app root and your sign-in | `registerBeakDependencies`, `beakPanelRoutes(config)`, an `OiApp.router` |
| One widget | A `BeakConfiguredForm`, table or block on a screen of yours | An `OiApp` above it, a model and a data source |

Take the second entrypoint when the panel is for staff and your app is for customers. It ships separately, needs no changes to your router, and cannot break your app's startup. Take the router mount when one signed-in user moves between your screens and the admin screens without a second login. Take a single widget when you need one Beak form inside a screen you wrote. [Using Beak widgets standalone](../../extending/using-beak-widgets-standalone.md) has the code for all three, tested.

Two facts decide most of the design:

- **Beak widgets are obers_ui widgets.** A host on `MaterialApp` needs an `OiApp` at or above any Beak widget, because they read the obers_ui theme, overlay and density scopes. Beak never asks you to give up Material for the rest of your app.
- **Panel routes are absolute** (`/notes`, `/notes/create`, `/notes/:id`, `/notes/:id/edit`) and take the top level of your router. There is no path prefix option, so a resource named like one of your routes collides with it.

## Share the session

The panel signs in against Beak's own `/api/auth/login` by default. An app that already has users usually wants the opposite: the panel trusts the session the app has.

- Give the panel a `BeakAuthConfig(adapter: ...)`. Beak then creates no HTTP client and no session store, and every model needs a `dataSource` bound to it or passed to the panel.
- On the router mount, pass `externalAuthentication: true` to `registerBeakDependencies` and guard the shell with your own `redirect`. The panel's routes contain no sign-in page.
- On the server side, your API decides who may do what, with `BeakPolicies` and a guard. The panel only hides controls.

[Auth and idle-lock](../../panel/auth-and-idle-lock.md) covers the panel half and [Auth and policies](../../backend/auth-and-policies.md) the server half.

## Where the API runs

`beak dev` serves the generated API on its own port, and `bin/serve.dart` does the same for production. Your existing backend can stay exactly where it is. If your backend is a Shelf app, you can mount Beak's handler in it instead of running a second process: `host.buildServer(adapter:, storage:)` returns a `BeakServer` whose `handler` is the whole pipeline. [Running the server](../../backend/running-the-server.md#embed-the-handler-in-a-shelf-app) has the code, and says which two things `buildServer` leaves to you (the outbox loop and the in-memory SQLite migrations).

If your backend is not Shelf, and not something Beak can own, the panel can talk to it directly: [An existing backend](existing-backend.md).

## Rules and limits

- **`beak init` needs a Flutter app.** A pubspec without `flutter: sdk: flutter` exits `1` with `Flutter projects only`, and an empty directory exits `1` with `There is no pubspec.yaml here`.
- **A project inside a Serverpod workspace is refused**, and the message only mentions the admin app. If you want the client bridge instead, wire it by hand; see [An existing Serverpod project](existing-serverpod-project.md).
- **`beak dev` does not launch Flutter.** It prints the `flutter run -t` line for your second terminal.
- **Run `beak prepare`, `dev` and `migrate` from the app root.** They do not check that they are in a Beak project, so a wrong directory gets files written there. `beak doctor` does check.
- **Two `main` files, one package.** Beak's `bin/serve.dart` and `bin/migrate.dart` land in your `bin/` and are git-ignored. If you already have files with those names, `beak prepare` treats a file without the `// GENERATED BY` header as yours and leaves it alone, so the generated server is then not written there.
- **The panel is its own web build.** Building it separately keeps the obers_ui and Beak code out of your customer-facing app, which is usually the reason to prefer a second entrypoint.
- **CORS is open by default.** The API answers `*`. When the panel and the API live on different origins, set `corsOrigin:` before you ship ([Security](../../shipping/security.md)).

## Verify it

```console
$ beak doctor
  OK   beak.yaml parses
  OK   discovered 1 model · 1 resource class · 0 screens · 0 overrides
  OK   lib/admin_main.dart lists every resource class
  OK   generated files up to date
  OK   every model has a migration
  ...
All checks passed.
$ flutter analyze
No issues found!
```

Then `flutter test`: the scaffold's `test/widget_test.dart` is not written for an existing app, so add one that pumps `buildPanel(dataSource: InMemoryBeakDataSource(registry: buildBeakRegistry()))` from `lib/admin_main.dart`. [Testing](../../shipping/testing.md) has the harness.

## Reference

| Flag | Default | Effect |
| --- | --- | --- |
| `--entrypoint <path>` | `lib/main.dart` if the app has none, else `lib/admin_main.dart` | The file, directly under `lib/`, that boots the panel. |
| `--beak-ref <ref>` | `v0.9.0` | Git ref of the dependency. Alternative to `--beak-path`. |
| `--beak-path <dir>` | none | Depend on a local checkout (the repo root; `packages/beak` is appended). |
| `--example` | off | Also write a first `Note` schema class and resource. |
| `--[no-]pub` | on | Run `flutter pub get` and `beak prepare` afterwards. |
| `--dry-run` | off | Report what would be written and write nothing. |

## Continue reading

- [Using Beak widgets standalone](../../extending/using-beak-widgets-standalone.md): the router mount and single widgets, with tested code.
- [Auth and idle-lock](../../panel/auth-and-idle-lock.md): share or replace the session.
- [Running the server](../../backend/running-the-server.md): serve the API, or embed its handler in a Shelf app.
- [An existing backend](existing-backend.md): let the panel talk to an API Beak does not own.
