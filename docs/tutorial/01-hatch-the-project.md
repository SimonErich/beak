---
title: 1. Hatch the project
description: Set up the Beak workspace and bring Postgres and MinIO up healthy before writing any code.
---

# 1. Hatch the project

By the end of this chapter you have a resolved Beak workspace and Postgres plus
MinIO running and healthy. No roastery code yet: this is the nest. The next
chapter lays the first egg.

## The three-package layout

The reference admin is three small packages under `apps/`, plus the `beak_*`
packages and the vendored `worm` ORM they build on. You will spend the tutorial
editing files in the trio; everything under `packages/` is Beak itself.

```text
apps/
  reference_admin_models/   # pure Dart: the models, defined once
  reference_admin_server/   # Shelf backend over beak_backend, port 8080
  reference_admin/          # Flutter panel over beak_frontend
```

They depend inward. The models package knows nothing about HTTP or Flutter. The
server and the panel both depend on the models package, and neither depends on
the other: they meet only over the network, on port 8080.

```dart title="apps/reference_admin_server/pubspec.yaml"
dependencies:
  beak_backend:
    path: ../../packages/beak_backend
  beak_core:
    path: ../../packages/beak_core
  reference_admin_models:
    path: ../reference_admin_models
  worm:
    path: ../../packages/worm
```

## Install the toolchain

Install the Dart and Flutter SDKs the usual way, then install Melos as a global
at the exact pinned version:

```bash
dart pub global activate melos 6.3.3
```

!!! warning "Do not use Melos 7 or newer"
    The 7.x line moved its configuration out of `melos.yaml` and into
    `pubspec.yaml`. Beak is on the `melos.yaml`-based `6.3.3` line and will not
    bootstrap under 7. If `melos --version` prints anything but `6.3.3`, re-run
    the `activate` command above.

## The obers_ui dependency

Beak's UI is `obers_ui`, never Material. `beak_frontend` and both demo apps
depend on the obers_ui trio by pinned git commit:

```yaml title="packages/beak_frontend/pubspec.yaml"
  obers_ui:
    git:
      url: https://github.com/SimonErich/obers_ui.git
      ref: 9fad953d77e90d2aaf2399a7b1b2085c5dd504ca
  obers_ui_autoforms:
    git:
      url: https://github.com/SimonErich/obers_ui.git
      path: packages/obers_ui_autoforms
      ref: 9fad953d77e90d2aaf2399a7b1b2085c5dd504ca
  obers_ui_charts:
    git:
      url: https://github.com/SimonErich/obers_ui.git
      path: packages/obers_ui_charts
      ref: 9fad953d77e90d2aaf2399a7b1b2085c5dd504ca
```

obers_ui is not on pub.dev yet, so it is pinned to an exact commit. There is
nothing for you to do about it: `melos bootstrap` fetches it into your pub cache
along with everything else. [Working with obers_ui](../deployment/the-obers-ui-sibling-caveat.md)
covers bumping the pin and developing against a local checkout.

## Bootstrap the workspace

From the repo root, resolve every package at once:

```bash
melos bootstrap
```

Melos runs `pub get` across the `packages/**` and `apps/**` globs from
`melos.yaml`. The vendored worm ORM and its drivers are explicitly ignored, so
they are consumed as path dependencies but never gated here.

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

The backend reads its configuration from a dotenv file, and it reads that file
from the directory you launch it in. The reference server runs from its own
folder, so give it a `.env` next to its `bin/`. Copy the committed template
there:

```bash
cp .env.example apps/reference_admin_server/.env
```

The template ships with `PORT=8180`, which is the showcase app's port. The
roastery store serves on `8080`, the panel's default. Delete the `PORT` line so
the store uses that default. The file should read:

```bash title="apps/reference_admin_server/.env"
DATABASE_URL=postgres://beak:beak@localhost:25432/beak
BEAK_STORAGE_DRIVER=s3
BEAK_S3_ENDPOINT=http://localhost:29000
BEAK_S3_BUCKET=beak-uploads
BEAK_S3_ACCESS_KEY=beak
BEAK_S3_SECRET_KEY=beaksecret
BEAK_S3_REGION=us-east-1
BEAK_S3_USE_PATH_STYLE=true
```

!!! note "Why no `PORT` line"
    The backend defaults to `8080` when `PORT` is unset, and the panel's default
    `apiBaseUrl` is `http://localhost:8080`. Leaving `PORT` out is what keeps the
    two in agreement. `.env` is git-ignored (secrets never land in a commit);
    `.env.example` is the committed record of the keys.

Every other value here matches the Docker stack you start next: `DATABASE_URL`
points at the dockerized Postgres, and the `BEAK_S3_*` block points at MinIO and
the `beak-uploads` bucket.

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

You should see Docker bring both services up healthy, then the one-shot bucket
container run and exit:

```text
[+] Running 3/3
 ✔ Container beak-postgres-1  Healthy
 ✔ Container beak-minio-1     Healthy
 ✔ Container beak-pgweb-1     Started
Bucket created successfully `local/beak-uploads`.
```

Host ports are remapped (each prefixed with a `2`) so they do not collide with a
default Postgres or MinIO already on your machine.

| Service | Host port | Notes |
| --- | --- | --- |
| Postgres | `25432` | `postgres://beak:beak@localhost:25432/beak` |
| MinIO (S3 API) | `29000` | bucket `beak-uploads` |
| MinIO console | `29001` | `beak` / `beaksecret` |
| pgweb | `28081` | browse the database in a browser |

When you are done for the day, `melos run down` stops the services and drops
their volumes.

!!! note "What just happened"
    - You installed the pinned Melos.
    - `melos bootstrap` ran `pub get` across every Beak package and demo app,
      fetching the pinned obers_ui commit into your pub cache along the way.
    - You gave the reference server its own `.env`, tuned to port `8080`.
    - `melos run up` brought Postgres and MinIO up healthy and created the
      upload bucket, so the backend has somewhere to store rows and files.

The database is running but empty: no tables yet. Time to define the first model
and give it a table to live in.

## Continue reading

- [2. Your first model and migration](02-first-model-and-migration.md) define
  `CategoryModel` and migrate its table.
- [Installation](../start-here/installation.md) the same setup as a standalone
  reference, with the full port map and the melos gate.
- [Dev infrastructure](../deployment/dev-infrastructure.md) what the
  docker-compose stack provides and how the health checks work.
- [Working with obers_ui](../deployment/the-obers-ui-sibling-caveat.md) how the
  obers_ui pin works, and how to develop against a local checkout.
