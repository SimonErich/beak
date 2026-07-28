---
title: Contributing
description: Get from a fresh clone to a green gate, run the docs locally, and learn the four commands every change must pass.
---

# Contributing

After this page you can take a fresh clone to a green gate: bootstrap the
monorepo, bring up the local services, and run the four commands that decide
whether a change is mergeable. It also shows how to preview these docs.

The canonical, always-current version of this guide lives in the repo root at
[`CONTRIBUTING.md`](https://github.com/SimonErich/beak/blob/main/CONTRIBUTING.md).
This page mirrors it for readers already in the docs and links out to the
deeper pages for each rule. By taking part you agree to the
[Code of Conduct](https://github.com/SimonErich/beak/blob/main/CODE_OF_CONDUCT.md).

## Prerequisites

- **Dart** `^3.11` and **Flutter** (stable channel).
- **Docker** + Docker Compose, for the Postgres + MinIO integration and E2E tests.
- **Melos `6.3.3`**, pinned. Install exactly this version:

```bash
dart pub global activate melos 6.3.3
```

!!! warning "Do not use Melos 7+"
    The 7.x line moved its configuration out of `melos.yaml` and into
    `pubspec.yaml`. This repo is on the `melos.yaml`-based `6.3.3` line and will
    not bootstrap under 7.

## The obers_ui dependency

`beak_frontend` and `beak` reference **`obers_ui`** by pinned git commit, so
`melos bootstrap` fetches it for you and a plain clone of this repo is all
you need. If your change spans both repositories, clone obers_ui beside this one
and run `melos run link-obers-ui` to swap the pin for your working copy.
[Working with obers_ui](../deployment/working-with-obers-ui.md) has the
details.

## Setup

```bash
# 1. From the repo root. obers_ui resolves from its pinned commit, so a
#    plain clone is all you need:
melos bootstrap                      # resolve every package

# 2. Local services (Postgres + MinIO), waits for health, inits the bucket:
melos run up

# 3. Environment file for the reference server and integration tests:
cp .env.example .env
```

Local dev ports are remapped so they do not collide with default installs
(each is configurable via a `BEAK_*_PORT` env var, see `docker-compose.yml`):

| Service        | Host port | Notes                         |
| -------------- | --------- | ----------------------------- |
| Postgres       | `25432`   | `postgres://beak:beak@…/beak` |
| MinIO (S3 API) | `29000`   | bucket `beak-uploads`         |
| MinIO console  | `29001`   | `beak` / `beaksecret`         |
| pgweb          | `28081`   | database browser              |

`melos run down` stops the services and drops their volumes. The
[dev infrastructure](../deployment/dev-infrastructure.md) page explains the
compose stack in full.

## The gate (Definition of Done)

Every change must keep these four green, run from the repo root:

```bash
melos run analyze        # 0 issues, plus five guards
melos run format-check   # dart format --set-exit-if-changed, clean
melos run test           # all package tests, no skips
melos run coverage       # per-package line-coverage thresholds
```

These are Melos scripts. `analyze` chains the analyzers and the guards; `test`
chains the Dart, Flutter, and tooling suites. The definitions live in
`melos.yaml`:

```yaml title="melos.yaml"
  analyze:
    run: >-
      melos run analyze-dart &&
      melos run analyze-flutter &&
      melos run analyze-root &&
      melos run guard-material &&
      melos run guard-web &&
      melos run check-docs &&
      melos run check-examples
    description: Static analysis across all packages (0 issues required).
```

Two more run in CI and are worth running before you push anything that touches
a driver or a service path:

```bash
melos run up             # Postgres + MinIO
melos run test-e2e       # every test/e2e directory, --tags e2e
melos run test-worm      # the vendored worm packages, which melos ignores
```

The service-backed suites are health-check-guarded, so `melos run test` passes
without Docker: they skip rather than fail.

### The coverage gotcha

`melos run coverage` reads existing `lcov.info` files and does **not** regenerate
them. If you changed code, delete stale reports first so the gate sees fresh
numbers:

```bash
rm -rf packages/*/coverage examples/*/coverage
melos run test && melos run coverage
```

The floor is 85% line coverage per package, higher for the pure ones (`beak_core`
holds 100%). See [Writing tests](writing-tests.md) for the per-package thresholds
and the patterns that reach them.

## Running the docs locally

The site is MkDocs with the Material theme, the minify plugin, and the redirects
plugin that keeps moved pages' old addresses working. Install the three Python
packages, then serve with live reload:

```bash
pip install mkdocs-material mkdocs-minify-plugin mkdocs-redirects
mkdocs serve
```

`mkdocs serve` hosts the site at `http://127.0.0.1:8000` and rebuilds on save.
Before opening a docs PR, build with the strict flag so a broken cross-link fails
the build the way CI will:

```bash
mkdocs build --strict
```

Every cross-link in these pages is a relative path to a `.md` file; `--strict`
turns any dangling link into an error, which is why the whole site stays
connected.

## Commits and pull requests

- Use [Conventional Commits](https://www.conventionalcommits.org/), for example
  `feat(beak_core): add typed column system`.
- Keep PRs focused. New behavior needs tests; changed behavior needs updated
  tests; every bug fix ships a regression test.
- Get the full gate green locally before opening the PR. CI runs the same four
  commands.

The [Conventions](conventions.md) page has the full commit and review rules.

## Continue reading

- [Code guardrails](code-guardrails.md) the hard rules the analyzer and reviewers enforce.
- [Conventions](conventions.md) commits, reuse-first, typed exceptions, and test style.
- [Writing tests](writing-tests.md) where tests live and the patterns per package.
- [Writing a storage driver](writing-a-storage-driver.md) the worked example of extending Beak.
