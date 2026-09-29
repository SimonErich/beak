# beak

The one dependency a Beak app adds. It puts the panel, the Shelf server, the
schema annotations, the migration DSL, the testing toolkit and obers_ui behind
eight libraries, so a project keeps one Beak version constraint instead of five.

Part of [Beak](https://github.com/SimonErich/beak), a configuration-driven
admin-panel framework for Dart and Flutter. You declare a model once, and that
class feeds the table cell, the form input, the detail row, the filter, the
REST validation, the migration and the CSV column.

## Install

`beak create` writes this for you. By hand:

```yaml
dependencies:
  beak:
    git:
      url: https://github.com/SimonErich/beak.git
      ref: v0.9.0
      path: packages/beak
```

The `v0.9.0` tag does not exist yet. Until the release is cut, scaffold with
`beak create my_admin --beak-path <repo root of a checkout>` (absolute) or
`--beak-ref <branch>`, and in a hand-written pubspec use `path:` or another
`ref:`. The panel also builds on the obers_ui commit that `beak` and
`beak_frontend` pin. That commit is fetchable from GitHub but predates
components `beak_frontend` uses (`OiFilterChip`, `OiPageLayout`,
`OiFieldLabel` and more), and the obers_ui state that has them is not
published, so a project resolved from the pin does not build. Until the pin
moves, point the three obers_ui packages at a local checkout with
`dependency_overrides` (the
[root README](https://github.com/SimonErich/beak#getting-it-running-today) shows
how), or work from a checkout of this repo and run `melos run link-obers-ui`.

`beak` depends on the Flutter SDK, because `panel.dart` draws widgets. A pure
Dart package that only declares schema classes, such as the shared models
package of a Serverpod workspace, depends on
[`beak_core`](https://github.com/SimonErich/beak/tree/main/packages/beak_core)
instead.

## Libraries

Import the one library a file needs. The split keeps Flutter out of the server
and `dart:io` out of the panel, and `beak doctor` complains when a panel file
reaches the server.

| Library | Holds | Import it from |
| --- | --- | --- |
| `package:beak/beak.dart` | The shared core: columns, models, relationships, the query spec, storage. No Flutter, no `dart:io`. | Model files, the generated registry |
| `package:beak/schema.dart` | The annotations: `@Resource`, `@Column`, `@Display`, `@BelongsTo`, `@HasMany` and the rest, plus `BeakSchema`. | Model files |
| `package:beak/panel.dart` | The Flutter panel: `BeakPanel`, resources, screens, forms, blocks. Re-exports `beak.dart`. | `lib/main.dart`, resource and screen files |
| `package:beak/server.dart` | The Shelf host, `WormDataSource`, policies, storage wiring and the local disk driver. Re-exports `beak.dart`. | `lib/server.dart`, the generated `lib/beak/server.g.dart` |
| `package:beak/migrations.dart` | worm's `Migration` and `Schema`, plus `BeakBlueprint`. Re-exports `server.dart`, so it is server-side too. | `lib/migrations/`, seeders |
| `package:beak/testing.dart` | The `beak_test` toolkit: `InMemoryBeakDataSource`, the data-source contract, record factories. | Tests |
| `package:beak/ui.dart` | obers_ui and obers_ui_autoforms, for screens you compose yourself. | Custom screens and widgets |
| `package:beak/charts.dart` | obers_ui_charts. Apart from `ui.dart` because both declare `OiAnnotationType`. | Custom chart screens |

A model file, as `beak create` writes it, imports the first two and nothing else:

```dart title="examples/quickstart/lib/resources/notes/models/note.dart"
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'note.beak.dart';
```

## Workflow skills

No code lives in this package beyond the library split. The implementations are
in `beak_core`, `beak_backend`, `beak_frontend` and `beak_test`, and the
umbrella pins their versions together. What it does add is
`packages/beak/skills`, six workflows a coding agent can follow end to end:
`beak-add-resource`, `beak-add-business-rule`, `beak-evolve-schema`,
`beak-adopt-database`, `beak-secure-api` and `beak-upgrade`. `beak agents`
installs them into a project together with the docs of the Beak version the
project resolved, so an agent reads the right pages instead of its training
data.

## Limits

- Not on pub.dev. It resolves from git or from a path, and needs network access
  to GitHub for `pub get`.
- The panel is obers_ui only. A file that imports `package:flutter/material.dart`
  is outside what Beak supports.

## Continue reading

- [Libraries](https://simonerich.github.io/beak/reference/libraries/): all eight in full, and why `beak.dart` must never reach Flutter.
- [Packages](https://simonerich.github.io/beak/reference/packages/): what every `beak_*` package owns.
- [Quickstart](https://simonerich.github.io/beak/start-here/quickstart/): a resource, a migration and a running panel.

## Status

Pre-1.0 and versioned in lockstep with the other `beak_*` packages (0.9.0). Not on pub.dev yet: depend on it from git with `ref: v0.9.0` once that tag exists, or from a checkout with `path:`. What changed: the [root changelog](https://github.com/SimonErich/beak/blob/main/CHANGELOG.md). Contributing: [CONTRIBUTING.md](https://github.com/SimonErich/beak/blob/main/CONTRIBUTING.md).

## License

Apache-2.0 © Marqably GmbH. See [LICENSE](https://github.com/SimonErich/beak/blob/main/LICENSE).
