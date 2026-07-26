# Contributing to Beak

Thanks for your interest in Beak! This guide gets you from a fresh clone to a
green gate, and explains the rules a change must satisfy to be merged.

By participating you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## Prerequisites

- **Dart** `^3.11` and **Flutter** (stable channel).
- **Docker** + Docker Compose (for the Postgres + MinIO integration/E2E tests).
- **Melos `6.3.3`** — pinned. Install exactly this version:
  ```bash
  dart pub global activate melos 6.3.3
  ```
  > ⚠️ Do **not** use Melos `7+`. The 7.x line moved its configuration out of
  > `melos.yaml` and into `pubspec.yaml`; this repo is on the `melos.yaml`-based
  > `6.3.3` line and will not bootstrap under 7.

## Repository layout

Beak is a Melos monorepo:

- `packages/beak_*` — the framework (core, backend, frontend, storage drivers,
  image, CLI).
- `apps/reference_admin*` — the reference admin (models, server, Flutter panel)
  and the E2E acceptance suite. This is the worked example.
- `packages/worm*` — the **vendored** worm ORM and its drivers. These are
  consumed as path dependencies but are *not* in the Melos scope and are not
  gated here. **Do not send Beak PRs that change vendored worm code** — report
  those upstream.

`beak_frontend` and the apps reference **`obers_ui`** by pinned git commit, so
`melos bootstrap` fetches it and a plain clone of this repo is all you need. If
your change spans both repositories, clone obers_ui beside this one and run
`melos run link-obers-ui` to swap the pin for your working copy (and
`melos run link-obers-ui -- --unlink` to switch back).

## Setup

```bash
# 1. From the repo root — nothing else needs checking out first:
melos bootstrap                      # resolve every package

# 2. Local services (Postgres + MinIO) — waits for health, inits the bucket:
melos run up

# 3. Environment file for the reference server / integration tests:
cp .env.example .env
```

Local dev ports are remapped so they don't collide with default installs
(configurable via `BEAK_*_PORT` env vars, see `docker-compose.yml`):

| Service            | Host port | Notes                          |
| ------------------ | --------- | ------------------------------ |
| Postgres           | `25432`   | `postgres://beak:beak@…/beak`  |
| MinIO (S3 API)     | `29000`   | bucket `beak-uploads`          |
| MinIO console      | `29001`   | `beak` / `beaksecret`          |
| pgweb              | `28081`   | database browser               |

`melos run down` stops the services and drops their volumes.

## The gate (Definition of Done)

Every change must keep all four green, run from the repo root:

```bash
melos run analyze        # 0 issues (incl. the no-Material import guard)
melos run format-check   # dart format --set-exit-if-changed — clean
melos run test           # all package tests, no skips
melos run coverage       # per-package line-coverage thresholds
```

> **Coverage gotcha:** `melos run coverage` reads existing `lcov.info` files and
> does not regenerate them. If you changed code, delete stale reports first so
> the gate sees fresh numbers:
> ```bash
> rm -rf packages/*/coverage apps/*/coverage
> melos run test && melos run coverage
> ```

Integration/E2E tests that need Postgres or MinIO are health-check-guarded: they
skip cleanly when the services aren't up, so `melos run test` passes without
Docker — but run `melos run up` before relying on them.

## Code guardrails

These are enforced by review (and partly by lints/`melos run analyze`):

- **UI is `obers_ui` only.** No `package:flutter/material.dart` or
  `.../cupertino.dart` imports (the `guard-material` check fails the build).
  Widgets are `HookWidget`; `StatefulWidget` is forbidden. State = Signals,
  DI = GetIt, routing = go_router.
- **No type escape hatches.** No `dynamic` (except documented `// interop:`),
  no `as` casts (pattern-match instead), no `Map<String, dynamic>` as a domain
  or public API type. Prefer enums/sealed classes over stringly-typed values.
  Every public member has a doc comment (`public_member_api_docs` is on).
- **Layering.** Backend: `Handler → Service → DataSource` (the handler is the
  catch boundary that maps typed exceptions to HTTP). Frontend:
  `Widget → ViewModel → Repository → DataSource` (ViewModels expose
  `ReadonlySignal` and never `try/catch`; the Repository is the catch boundary).
- **Source-agnostic data.** `BeakDataSource` is the seam; keep worm and obers
  types from leaking across package boundaries.
- **Tests verify behavior**, prefer fakes over mocks, and every bug fix ships a
  regression test.

See [`docs/architecture.md`](docs/architecture.md) and `CLAUDE.md` for the full
rationale.

## Commits & pull requests

- Use [Conventional Commits](https://www.conventionalcommits.org/): e.g.
  `feat(beak_core): add typed column system`,
  `fix(beak_backend): map malformed spec bodies to 422`.
- Keep PRs focused; describe the change and how you verified it. New behavior
  needs tests; changed behavior needs updated tests.
- Ensure the full gate is green locally before opening the PR — CI runs the same
  four commands.

We recommend protecting `main` with required status checks (analyze, format,
test, coverage) and a linear history.
