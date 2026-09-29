---
title: Contributing to Beak
description: Clone the Beak repository, bootstrap it with Melos 6.3.3, get the four-command gate green and find the pages that tell you what a change must satisfy.
type: guide
audience: [contributor]
status: stable
---

# Contributing to Beak

You want to change Beak itself, not use it. After this page you have a clone that bootstraps, a green gate and a place to start. The Contributing tab has the detail; this page is the shortest route into it.

By taking part you agree to the [Code of Conduct](https://github.com/SimonErich/beak/blob/main/CODE_OF_CONDUCT.md). `CONTRIBUTING.md` at the repository root is the short version of the Contributing tab, and `AGENTS.md` is the version for coding agents.

## At a glance

| | |
| --- | --- |
| Repository | A Melos monorepo: `packages/`, `examples/`, `docs/`, `tool/` |
| Needs | Dart `^3.11`, Flutter stable `3.41` or newer, Melos exactly `6.3.3` |
| Optional | Docker (Postgres and MinIO suites), Python 3 (docs preview) |
| The gate | `melos run analyze`, `format-check`, `test`, `coverage` |
| Layout of the work | Backend in `packages/beak_backend`, panel in `packages/beak_frontend`, schema and query contract in `packages/beak_core`, the CLI in `packages/beak_cli` |

```bash
git clone https://github.com/SimonErich/beak.git
cd beak
dart pub global activate melos 6.3.3
melos bootstrap
```

`melos bootstrap` resolves every package under `packages/` and `examples/`. Two trees sit outside Melos on purpose: the vendored `packages/worm*` packages and the Serverpod workspace in `examples/serverpod`.

## Get the gate green

Run these from the repository root before you push. They are the definition of done:

```bash
melos run analyze
melos run format-check
melos run test
melos run coverage
```

`analyze` is a chain: `dart analyze` and `flutter analyze` at `--fatal-infos --fatal-warnings`, the tooling in `tool/`, then the guards (no Material imports, no `StatefulWidget`, a web-safe panel import graph), the docs check, the agent docs bundle check and the examples check. `coverage` does not run tests; it reads the reports the tests wrote. After a code change, delete the old ones first:

```bash
rm -rf packages/*/coverage examples/*/coverage
melos run test && melos run coverage
```

While you iterate, run one check at a time, as the [Contributing tab](../../contributing/index.md#run-one-check-at-a-time) lists them. `dart run tool/check_docs.dart` takes seconds.

## The obers_ui pin

The panel builds on obers_ui, which the pubspecs pin by git commit. `melos bootstrap` fetches that commit, so the pin has to be fetchable from `github.com/SimonErich/obers_ui`, and today it is. It is also older than the code: `beak_frontend` uses obers_ui APIs the pinned commit does not have, so a fresh clone does not compile the panel packages until you link a local checkout.

```bash
# clone obers_ui next to this repository, then, in this one:
melos run link-obers-ui
```

To go back to the pinned commits, run the script made for it (`melos run link-obers-ui -- --unlink` does not work, because Melos 6.3.3 appends the flag to the end of the whole script):

```bash
melos run unlink-obers-ui
```

Unlink before you commit or tag a release: the tracked lockfiles of a few examples record the linked state while you are linked. [Working with obers_ui](../../contributing/working-with-obers-ui.md) has the rest.

## Where to pick up work

- **The known-issues list.** The 0.9.0 entry of `CHANGELOG.md` has a `Known issues` section. It is the honest backlog: each item is a bug or a gap somebody hit, written with the file it lives in.
- **Docs.** Every page under `docs/` carries a `status`. `dart run tool/check_docs.dart --release` fails while any page is still a `draft`, and lists them. [Writing docs](../../contributing/writing-docs.md) says how a page moves to `stable`.
- **Tests and examples.** The coverage floors and the example checks are in [Writing tests](../../contributing/writing-tests.md).
- **Issues.** Open one on GitHub before a large change. The bug template asks for the affected package and what happened.

## Rules and limits

- **Do not send changes to the vendored worm packages.** `packages/worm*` are consumed as path dependencies and are not in the Melos gate. Report those upstream. The repository still runs their suites with `melos run test-worm`.
- **Melos 7 does not bootstrap this repository.** It reads its configuration from `pubspec.yaml`, and this repo keeps it in `melos.yaml`.
- **No Material, no `dynamic`, no `as`, no `StatefulWidget`.** [Code guardrails](../../contributing/code-guardrails.md) lists each rule and the tool that enforces it.
- **Service-backed suites are separate from the gate.** `melos run up`, `melos run test-e2e` and `melos run test-worm` need Docker and run in CI after the four commands. A pull request should not need Docker to go green.
- **Generated files are committed.** After a change to the generators, run `beak prepare` in the examples (the `check-examples` guard tells you which). After a change to `docs/`, a file a page quotes or `CHANGELOG.md`, run `melos run agent-docs` and commit the bundle.

## Verify it

```console
$ melos run analyze
$ melos run format-check
$ melos run test
$ melos run coverage
```

All four exit `0`. If `analyze` stops in `check-docs` or `check-examples`, the message names the page or the example. If `coverage` fails after `test` passed, look for a stale `lcov.info` before you look at your change.

## Reference

| Command | What it does |
| --- | --- |
| `melos bootstrap` | Resolve every package |
| `melos run analyze` | Analyzers, tooling, guards, docs, agent docs and examples checks |
| `melos run format-check` | `dart format --set-exit-if-changed` |
| `melos run test` | `dart test` and `flutter test` per package, without the `e2e` tag |
| `melos run coverage` | Per-package line-coverage floors |
| `melos run up` / `down` | Start and stop the Postgres and MinIO stack |
| `melos run test-e2e`, `test-worm` | The service-backed suites |
| `melos run link-obers-ui`, `unlink-obers-ui` | Work against a local obers_ui, and go back to the pinned commits |
| `melos run agent-docs` | Rebuild the docs bundle coding agents read |

## Continue reading

- [Contributing](../../contributing/index.md): the whole tab, from setup to what CI runs.
- [Code guardrails](../../contributing/code-guardrails.md): the rules that fail review.
- [Architecture](../../architecture/index.md): how Beak is built inside.
- [Writing docs](../../contributing/writing-docs.md): add or fix a page.
