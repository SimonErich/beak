---
title: Code guardrails
description: The hard rules every change to Beak must satisfy, the tool or lint that enforces each, and the command that checks it.
type: reference
audience: [contributor, agent]
status: stable
search: {boost: 2}
---

# Code guardrails

These are the rules a change to Beak has to satisfy before review starts. Some fail a tool, the rest fail a reviewer. The [Summary](#summary) says which is which and how to check each one yourself.

## Import

### What a package may depend on

The dependency direction is the first guardrail. `beak_core` is the shared vocabulary and depends on neither half.

| Package | Depends on | Never depends on |
| --- | --- | --- |
| `beak_core` | `intl`, `http`, `http_parser`, `meta` | Flutter, obers_ui, worm, Shelf |
| `beak_backend` | `beak_core`, `beak_image`, Shelf, worm, `worm_postgres`, `worm_sqlite` | Flutter, obers_ui |
| `beak_frontend` | `beak_core`, Flutter, obers_ui, `obers_ui_autoforms`, `obers_ui_charts`, `signals`, `get_it`, `go_router`, `flutter_hooks` | worm, Shelf, `beak_backend` |
| `beak_cli` | `analyzer`, `args`, `dart_style`, worm and its Postgres and SQLite drivers | `beak_backend`, Flutter |
| `beak_test` | `beak_core`, `test` | Flutter, worm |

The umbrella package `beak` depends on `beak_backend`, `beak_core`, `beak_frontend`, `beak_test`, the three obers_ui packages and worm. It has no logic of its own, only libraries that pick what an app imports.

### The umbrella libraries

| Library | Holds | Reaches Flutter | Reaches `dart:io` or a database | Walked by `guard-web` |
| --- | --- | --- | --- | --- |
| `package:beak/beak.dart` | columns, models, relationships, query spec, storage abstraction | no | no | yes |
| `package:beak/schema.dart` | the annotations a schema class is written with | no | no | yes |
| `package:beak/panel.dart` | the panel, tables, forms, blocks; re-exports `beak.dart` | yes | no | yes |
| `package:beak/ui.dart` | obers_ui and the autoforms | yes | no | yes |
| `package:beak/charts.dart` | obers_ui_charts | yes | no | yes |
| `package:beak/server.dart` | the Shelf host, auth, policy; re-exports `beak.dart` | no | yes | no |
| `package:beak/migrations.dart` | worm's `Migration` and `Schema`, plus `BeakBlueprint` | no | yes | no |
| `package:beak/testing.dart` | the `beak_test` toolkit; needs `package:test` | no | no | no |

A model file and the generated registry import `beak.dart` only. The server compiles ahead of time, and one transitive `dart:ui` import would stop it.

### Imports that fail the build

Two imports are banned in every gated Dart file. The list lives in the guard:

```dart title="tool/check_no_material.dart"
const List<String> forbiddenImportUris = [
  'package:flutter/material.dart',
  'package:flutter/cupertino.dart',
];
```

The guard scans each `.dart` file under `packages/` and `examples/`, skipping the vendored `worm*` packages, dot-directories and `build`. In a pub workspace root (`examples/serverpod`) it scans only the members that depend on a Beak package. `package:flutter/widgets.dart` and `foundation.dart` stay allowed for core types (`BuildContext`, `Widget`, `Key`, `Color`, `EdgeInsets`), never for Material or Cupertino components.

The second guard protects the panel from the server. `dart:io` compiles for web and throws only at runtime, so no compiler catches a stray import. The guard walks the import graph from the panel entrypoints and fails on any web-unsafe URI it reaches:

```dart title="tool/check_web_safe.dart"
const List<String> webUnsafeSdkLibraries = [
  'dart:io',
  'dart:ffi',
  'dart:mirrors',
];
```

```dart title="tool/check_web_safe.dart"
const List<String> webUnsafePackagePrefixes = [
  'package:beak_backend',
  'package:beak_image',
  'package:beak_serverpod_server',
  'package:beak_storage_',
  'package:postgres',
  'package:serverpod/',
  'package:shelf',
  'package:worm',
];
```

```dart title="tool/check_web_safe.dart"
const List<String> panelEntrypoints = [
  'packages/beak/lib/beak.dart',
  'packages/beak/lib/panel.dart',
  'packages/beak/lib/ui.dart',
  'packages/beak/lib/charts.dart',
  'packages/beak/lib/schema.dart',
  'packages/beak_core/lib/beak_core.dart',
  'packages/beak_core/lib/schema.dart',
  'packages/beak_frontend/lib/beak_frontend.dart',
  'packages/beak_serverpod/lib/beak_serverpod.dart',
  'packages/beak_serverpod/lib/wire.dart',
  'packages/beak_serverpod_flutter/lib/beak_serverpod_flutter.dart',
  'packages/beak_serverpod_flutter/lib/tunnel.dart',
];
```

The libraries that reach the server on purpose (`server.dart`, `migrations.dart`, `testing.dart` and `beak_core`'s `io.dart`) sit in `serverEntrypoints` and are not walked. A test fails on any public library under `lib/` that is in neither list, so a new library cannot go unguarded by omission.

Packages named `beak` and `beak_*` are walked into. Everything else is a boundary node: its URI is checked, its sources are not. Server-side code that a panel graph would otherwise pull in goes behind its own library, as `package:beak_core/io.dart` does for the local-disk storage driver.

The third guard keeps widget state out of `State` objects. `tool/check_hook_widgets.dart` reads the `lib/` of every gated package (the same set as the Material guard, tests excluded) and fails on a class that extends `StatefulWidget`, `State`, `StatefulHookWidget` or `HookState`, and prints the file and the class. It reads tokens, not lines, so a comment or a string that quotes the rule is not a violation and a declaration wrapped over two lines still is.

## Summary

| Rule | Enforced by | Check with |
| --- | --- | --- |
| No Material or Cupertino import | `guard-material`, part of `analyze` | `dart run tool/check_no_material.dart` |
| The panel graph reaches no `dart:io`, `dart:ffi`, `dart:mirrors` or server package | `guard-web`, part of `analyze`; a real web build in CI | `dart run tool/check_web_safe.dart` |
| Widgets are `HookWidget`, never `StatefulWidget` or `State` | `guard-hooks`, part of `analyze` | `dart run tool/check_hook_widgets.dart` |
| State is signals (`ReadonlySignal` out of view models), DI is GetIt, routing is go_router | review | none |
| No `dynamic`; the exception is a line marked `// interop:` | review, `avoid_dynamic_calls`, strict inference | `dart analyze --fatal-infos --fatal-warnings` |
| No `as` casts; narrow with pattern matching | review, `strict-casts` | `dart analyze --fatal-infos --fatal-warnings` |
| No `Map<String, dynamic>` as a domain, presentation or public API type | review | none |
| Enums and sealed classes for any known value set | review | none |
| Numeric names carry their unit: `maxSizeInBytes`, `timeoutInSeconds`, `...InPixels` | review | none |
| Public APIs are annotated and declare return types | `type_annotate_public_apis`, `always_declare_return_types` | `dart analyze --fatal-infos --fatal-warnings` |
| Every public member has a doc comment | `public_member_api_docs` | `dart analyze --fatal-infos --fatal-warnings` |
| No `print`, no `TODO`, no commented-out code | `avoid_print`; review for the other two | `dart analyze --fatal-infos --fatal-warnings` |
| `const` and `final` by default | `prefer_const_constructors`, `prefer_final_locals`, `prefer_final_fields` and siblings | `dart analyze --fatal-infos --fatal-warnings` |
| Backend: Handler, Service, DataSource. `beakErrorMappingMiddleware` is the single catch boundary | review; the exception switch in the middleware is compiler-checked | `dart test` in `packages/beak_backend` |
| Frontend: Widget, ViewModel, Repository, DataSource. View models expose `ReadonlySignal` and do not `try/catch`; the repository returns `BeakResult` | review | `flutter test` in `packages/beak_frontend` |
| There is no UseCase layer in either flow | review | none |
| Failures are the sealed `BeakException` family, never a bare `Exception` | review; sealed exhaustiveness | see [Conventions](conventions.md#typed-exceptions) |
| `BeakDataSource` is the seam. worm types stay in the backend, the CLI and the migrations library; obers_ui types stay in the frontend and the umbrella UI libraries | `guard-web` for the panel graph, review elsewhere | `dart run tool/check_web_safe.dart` |
| Generated files (`*.g.dart`, `*.beak.dart`) are regenerated, never edited | `*.g.dart` is excluded from analysis, both kinds from coverage; `check-examples` fails a stale one | `dart run tool/check_examples.dart` |
| Pre-1.0, a superseded API is removed rather than deprecated, and the break is recorded in the open section of `CHANGELOG.md` | review | [Releasing](releasing.md) |

Rules marked review have no tool behind them. A rule that only review holds is the one that slips: the widget rule did, until `guard-hooks` was added.

### Where the rules bend

- **`// interop:`** marks the one place a `dynamic` value is accepted today: `ProcessResult.stderr`, which `dart:io` types as `dynamic`, in `tool/check_coverage.dart`. A new one needs a reason on the same line.
- **worm is public API in one library.** `package:beak/migrations.dart` re-exports `package:worm/worm.dart`, because a migration is written against worm's `Migration` and `Schema`. `beak_cli` imports worm's adapters to introspect a live database. Neither reaches the panel graph.
- **The vendored worm packages** under `packages/worm*` sit outside the melos scope, so `analyze`, `test` and `coverage` skip them. They are still edited in this repository when Beak needs a change, so `melos run test-worm` runs their suites and CI calls it. A pull request that touches them says why Beak needed the change.

## Source

| What | Where |
| --- | --- |
| Material and Cupertino guard | `tool/check_no_material.dart`, tested in `test/check_no_material_test.dart` |
| Web-safety guard | `tool/check_web_safe.dart`, tested in `test/check_web_safe_test.dart` |
| Hook-widget guard | `tool/check_hook_widgets.dart`, tested in `test/check_hook_widgets_test.dart` |
| Generated-code and example health guard | `tool/check_examples.dart`, which runs `beak doctor --json` in every example |
| Lints and strict analysis | `analysis_options.yaml` at the repo root; packages without their own file inherit it, and `packages/beak` and `packages/beak_frontend` add Flutter rules on top |
| Guard wiring | the `analyze` script in `melos.yaml` |
| Error-to-HTTP mapping | `packages/beak_backend/lib/src/server/middleware/error_mapping_middleware.dart` |
| The sealed exception family | `packages/beak_core/lib/src/common/beak_exception.dart` |
| The data-source seam | `packages/beak_core/lib/src/data/beak_data_source.dart` |

The analysis options that do the mechanical work:

```yaml title="analysis_options.yaml"
analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
# ...
linter:
  rules:
    - always_declare_return_types
    - avoid_dynamic_calls
    - type_annotate_public_apis
    - public_member_api_docs
    - prefer_const_constructors
    - prefer_const_declarations
    - prefer_final_locals
    - prefer_final_in_for_each
    - prefer_final_fields
    - unnecessary_null_checks
    - avoid_print
    - require_trailing_commas
    - unawaited_futures
    - cancel_subscriptions
    - close_sinks
```

A package without its own `analysis_options.yaml` still gets these, because the analyzer takes the nearest file up the tree. An undocumented public class and a `print` fail like this, and `--fatal-infos` turns each info into a non-zero exit:

```text
   info - lib/a.dart:1:7 - Missing documentation for a public member. Try adding documentation for the member. - public_member_api_docs
   info - lib/a.dart:3:17 - Don't invoke 'print' in production code. Try using a logging framework. - avoid_print
```

A `dynamic` field passes both lints, which is why that rule sits with review. A violation of the Material guard prints the file and the URI, and exits non-zero:

```text
Forbidden Material/Cupertino imports found:
packages/demo/lib/panel.dart: package:flutter/material.dart
```

## Continue reading

- [Conventions](conventions.md) the softer rules: commits, exceptions, what to regenerate.
- [Writing tests](writing-tests.md) how each rule gets proven per package.
- [The four layers](../concepts/the-four-layers.md) both flows, end to end.
- [The data source seam](../architecture/data-source-seam.md) the interface both sides implement.
