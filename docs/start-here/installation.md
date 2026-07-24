---
title: Installation
description: Get the Beak toolchain, the sibling obers_ui checkout, and local Postgres and MinIO in place before you build.
---

# Installation

After this page you have a resolved Beak workspace: the right Dart and Flutter,
the pinned Melos, the obers_ui checkout Beak draws its widgets from, and Postgres
plus MinIO running locally. The [Quickstart](quickstart.md) picks up from here.

## Prerequisites

Beak is a Dart and Flutter monorepo orchestrated by Melos, with a Docker stack
for the services the backend talks to.

| Tool | Version | Why you need it |
| --- | --- | --- |
| Dart SDK | `^3.11` | Every package targets it (`sdk: ^3.11.0`). |
| Flutter | stable channel, `3.41` or newer | The panel and demo apps (`flutter: '>=3.41.0'`). |
| Docker + Compose | any recent release | Postgres and MinIO for the backend, uploads, and integration tests. |
| Melos | `6.3.3`, pinned | Bootstraps and gates the whole workspace. |

Install the Dart and Flutter SDKs the usual way, then install Melos as a global
at the exact pinned version:

```bash
dart pub global activate melos 6.3.3
```

!!! warning "Do not use Melos 7 or newer"
    The 7.x line moved its configuration out of `melos.yaml` and into
    `pubspec.yaml`. Beak is on the `melos.yaml`-based `6.3.3` line (pinned in the
    workspace root `pubspec.yaml`) and will not bootstrap under 7. If `melos
    --version` prints anything but `6.3.3`, re-run the `activate` command above.

## The obers_ui sibling checkout

Beak's UI is obers_ui, never Material. `beak_frontend` and both demo apps depend
on the obers_ui trio by a relative path that climbs one level above the repo
root:

```yaml title="packages/beak_frontend/pubspec.yaml"
  obers_ui:
    path: ../../../obers_ui
  obers_ui_autoforms:
    path: ../../../obers_ui/packages/obers_ui_autoforms
  obers_ui_charts:
    path: ../../../obers_ui/packages/obers_ui_charts
```

From `packages/beak_frontend/`, `../../../obers_ui` resolves to a folder named
`obers_ui` sitting next to the `beak` repo. So check obers_ui out as a **sibling
of this repo** before you bootstrap. The layout Beak expects:

```text
Flutters/
  beak/        # this repository
  obers_ui/    # the sibling checkout, cloned next to it
```

```bash
# from the folder that contains your beak/ clone
git clone https://github.com/SimonErich/obers_ui.git
```

If obers_ui is missing or lives somewhere else, `melos bootstrap` fails to
resolve the path dependencies. See
[The obers_ui sibling caveat](../deployment/the-obers-ui-sibling-caveat.md) for
the CI and deployment version of this rule.

## Bootstrap the workspace

From the repo root, resolve every package:

```bash
melos bootstrap
```

Melos runs `pub get` across everything it manages. Its scope is the `packages/**`
and `apps/**` globs from `melos.yaml`; the vendored worm ORM and its drivers are
explicitly ignored, so they are consumed as path dependencies but never gated
here.

```yaml title="melos.yaml"
packages:
  - packages/**
  - apps/**

ignore:
  - packages/worm
  - packages/worm/**
  - packages/worm_*
  - packages/worm_*/**
```

## The environment file

The backend reads its configuration from a dotenv file. Copy the committed
template to a real `.env`:

```bash
cp .env.example .env
```

```bash title=".env.example"
PORT=8180
DATABASE_URL=postgres://beak:beak@localhost:25432/beak
BEAK_STORAGE_DRIVER=s3
BEAK_S3_ENDPOINT=http://localhost:29000
BEAK_S3_BUCKET=beak-uploads
BEAK_S3_ACCESS_KEY=beak
BEAK_S3_SECRET_KEY=beaksecret
BEAK_S3_REGION=us-east-1
BEAK_S3_USE_PATH_STYLE=true
```

Every value here matches the Docker stack you start next:

- `DATABASE_URL` points at the dockerized Postgres on host port `25432`.
- `BEAK_STORAGE_DRIVER=s3` plus the `BEAK_S3_*` block point at MinIO on host port
  `29000`, using the `beak-uploads` bucket. Leave `BEAK_STORAGE_DRIVER` unset to
  run without uploads.
- `PORT` selects the HTTP port the backend binds. When it is unset the backend
  defaults to `8080`.

`.env` is git-ignored (secrets never land in a commit); `.env.example` is the
committed record of the keys. Each runnable app reads a `.env` from the directory
you launch it in, so the reference server keeps its own next to its `bin/`. The
[Quickstart](quickstart.md) writes that one.

## Start the local services

```bash
melos run up
```

That script starts Postgres and MinIO, waits for both to report healthy, and
creates the upload bucket:

```yaml title="melos.yaml"
  up:
    run: docker compose up -d --wait && docker compose run --rm createbuckets
    description: Start Postgres + MinIO, wait for health, and init the upload bucket.
```

Host ports are remapped (each prefixed with a `2`) so they do not collide with a
default Postgres or MinIO already running on your machine. Override any of them
with the matching `BEAK_*_PORT` variable from `docker-compose.yml`.

| Service | Host port | Notes |
| --- | --- | --- |
| Postgres | `25432` | `postgres://beak:beak@localhost:25432/beak` |
| MinIO (S3 API) | `29000` | bucket `beak-uploads` |
| MinIO console | `29001` | `beak` / `beaksecret` |
| pgweb | `28081` | browse the database in a browser |

When you are done, `melos run down` stops the services and drops their volumes.

!!! note "Docker is only needed for the backend and integration tests"
    Unit tests that touch Postgres or MinIO are health-check-guarded: they skip
    cleanly when the services are down, so `melos run test` passes without
    Docker. Run `melos run up` before you rely on the backend, uploads, or the
    end-to-end suite.

## You are set

You now have a bootstrapped workspace and running services. Two directions from
here:

- Boot the reference admin end to end in the [Quickstart](quickstart.md).
- Learn where every folder lives in [Project structure](project-structure.md).

## Continue reading

- [Quickstart](quickstart.md) migrate, seed, serve on port 8080, open the panel.
- [Project structure](project-structure.md) the monorepo layout and the two-app
  split.
- [The obers_ui sibling caveat](../deployment/the-obers-ui-sibling-caveat.md) why
  obers_ui lives outside the repo, and how CI checks it out.
- [Contributing](../contributing/index.md) the four-command gate a change must
  pass.
