---
title: Contributing
description: Take a fresh clone to a green gate and find the rules, tools and pages that every change to Beak passes through.
type: index
audience: [contributor]
status: stable
---

# Contributing

You have a clone of Beak and a change in mind. This tab covers what sits between the two: the rules a change has to satisfy, the four commands that check it, and the tools behind those commands. By taking part you agree to the [Code of Conduct](https://github.com/SimonErich/beak/blob/main/CODE_OF_CONDUCT.md).

`CONTRIBUTING.md` at the repo root is the short version of this tab, and `AGENTS.md` next to it is the version for coding agents. Where they disagree with the code, the code wins.

## Set up

| You need | Version | Why |
| --- | --- | --- |
| Dart | `^3.11` | the SDK constraint of every package |
| Flutter | stable, `>=3.41.0` | the panel, the umbrella package and the examples |
| Melos | exactly `6.3.3` | runs the gate scripts in `melos.yaml` |
| Docker with Compose | any recent | optional, for the Postgres and MinIO suites only |
| Python 3 | 3.14 in CI | optional, only to preview the docs |

```bash
git clone https://github.com/SimonErich/beak.git
cd beak
dart pub global activate melos 6.3.3
melos bootstrap
```

`melos bootstrap` resolves every package under `packages/` and `examples/`. obers_ui comes from the commit the pubspecs pin, so nothing else has to sit next to the clone. Two trees are outside melos on purpose: the vendored `packages/worm*` packages and the Serverpod workspace in `examples/serverpod`.

!!! warning "Melos 7 does not bootstrap this repo"
    Melos 7 reads its configuration from `pubspec.yaml`. This repo keeps it in `melos.yaml`, so 7.x finds no scripts. Install `6.3.3` and stay there.

## The gate

Four commands decide whether a change can merge. Run them from the repo root.

```bash
melos run analyze
melos run format-check
melos run test
melos run coverage
```

`analyze` is a chain, not one analyzer. The script is the definition:

```yaml title="melos.yaml"
  analyze:
    run: >-
      melos run analyze-dart &&
      melos run analyze-flutter &&
      melos run analyze-root &&
      melos run guard-material &&
      melos run guard-hooks &&
      melos run guard-web &&
      melos run check-docs &&
      melos run check-agent-docs &&
      melos run check-examples
    description: >-
      Static analysis across all packages (0 issues required), the repo guards,
      the docs checks and the agent docs bundle check.
```

| Command | What it runs | Fails on |
| --- | --- | --- |
| `melos run analyze` | `dart analyze` and `flutter analyze` with `--fatal-infos --fatal-warnings`, the tooling in `tool/` and `test/`, then the guards and checks | any info, a Material import, a `StatefulWidget`, `dart:io` in the panel graph, a broken docs page, a stale agent docs bundle, a stale example |
| `melos run format-check` | `dart format --output=none --set-exit-if-changed .` | any file `dart format` would change |
| `melos run test` | `dart test` and `flutter test` per package with `--exclude-tags e2e`, then `dart test` at the root | any failing test |
| `melos run coverage` | `dart run tool/check_coverage.dart` | a package below its line-coverage floor |

Two more checks run in CI after the gate. They need the Docker stack from [Dev infrastructure](dev-infrastructure.md), which `melos run up` starts.

```bash
melos run up
melos run test-e2e
melos run test-worm
```

`test-e2e` runs the suites tagged `e2e`, and `test-worm` runs the vendored worm packages, including their Postgres suite. Neither is part of the four, because a pull request should not need Docker to go green.

### Coverage reads what is on disk

`melos run coverage` does not run any tests. Flutter packages rewrite `coverage/lcov.info` on every `melos run test`. Pure Dart packages write raw coverage files and get an `lcov.info` only when none exists, so an old one is reused as if it were current. After a code change, delete the reports first:

```bash
rm -rf packages/*/coverage examples/*/coverage
melos run test && melos run coverage
```

[Writing tests](writing-tests.md) lists the floors.

### Run one check at a time

While you iterate, run the check you are working against instead of the whole chain. Each one is a script.

| Check | Command | Time |
| --- | --- | --- |
| No Material or Cupertino imports | `dart run tool/check_no_material.dart` | seconds |
| No `StatefulWidget` or `State` | `dart run tool/check_hook_widgets.dart` | seconds |
| Web-safe panel import graph | `dart run tool/check_web_safe.dart` | seconds |
| Docs structure and style | `dart run tool/check_docs.dart` | seconds |
| Examples still match their generator | `dart run tool/check_examples.dart` | about a minute |
| Coverage floors | `dart run tool/check_coverage.dart` | seconds |
| Published agent skills | `dart run tool/published_skills.dart` | seconds |
| Agent docs bundle is current | `dart run tool/build_agent_docs.dart --check` | seconds |
| The tooling's own tests | `dart test` | seconds |

The skills check also runs inside `melos run test`, through `test/published_skills_test.dart`. The bundle check runs inside `melos run analyze` and in the docs workflow, so a change to `docs/`, `mkdocs.yml`, `CHANGELOG.md` or the version fails until `melos run agent-docs` has regenerated the bundle. [Releasing](releasing.md) covers when to run it.

## What CI runs

| Workflow | Job | Runs |
| --- | --- | --- |
| `ci.yaml` | Analyze and format | `melos run analyze`, `melos run format-check` |
| `ci.yaml` | Web build | `flutter build web --release` for `examples/quickstart` and `examples/clean_beak_config` |
| `ci.yaml` | Web build (showcase), Web build (foodio) | `flutter build web --release` for `examples/showcase` and `examples/foodio-adminpanel`, one job each |
| `ci.yaml` | Install smoke | `dart pub global activate --source path packages/beak_cli`, `beak --version`, `beak create --beak-path` in a temporary directory, then `beak prepare` |
| `ci.yaml` | Serverpod example | `flutter pub get` in `examples/serverpod`, then the bookshop server's tests without the `integration` tag |
| `ci.yaml` | Test and coverage | `melos run test`, `melos run coverage`, then `melos run up`, `melos run test-e2e`, `melos run test-worm` |
| `docs.yml` | Build documentation | the docs checker and its tests, the agent docs bundle check, `mkdocs build --strict`, and on `release/**` branches and `v*` tags `check_docs.dart --release` |
| `docs.yml` | Deploy to Pages | publishes the built site, on `main` only |

## Which page to read

| You want to... | Read | For that |
| --- | --- | --- |
| Know which imports, escape hatches and layer boundaries a change may never cross | [Code guardrails](code-guardrails.md) | the hard rules and the tool that enforces each |
| Shape a commit, an exception or a test the way a reviewer expects | [Conventions](conventions.md) | the softer rules, and what to regenerate after a change |
| Add a test to a package with the harness it expects | [Writing tests](writing-tests.md) | runners, fakes, the e2e tag and the coverage floors |
| Write a docs page that passes the docs gate | [Writing docs](writing-docs.md) | page types, snippets, the draft to stable ratchet and the local preview |
| Cut a release | [Releasing](releasing.md) | the version bump, the tag, the bundle and the obers_ui pin |
| Run real Postgres and MinIO next to your code | [Dev infrastructure](dev-infrastructure.md) | the compose stack, its ports and the suites that use it |
| Change obers_ui and Beak together | [Working with obers_ui](working-with-obers-ui.md) | the git pin and `melos run link-obers-ui` |
| See how Beak is built inside | [Architecture](../architecture/index.md) | the principles, the package graph and the two flows |

## Continue reading

- [Code guardrails](code-guardrails.md) the rules that fail review.
- [Writing tests](writing-tests.md) where tests live and which fake to reach for.
- [Dev infrastructure](dev-infrastructure.md) the optional Docker stack.
