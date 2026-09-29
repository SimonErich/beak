---
title: Dev infrastructure
description: Run the optional local Postgres and MinIO stack and know which suites need it.
type: guide
audience: [contributor]
status: draft
---

# Dev infrastructure

You do not need this to run a Beak app. A project with no `DATABASE_URL` runs on a SQLite file it creates on first `beak migrate`, and uploads land on local disk until `BEAK_STORAGE_DRIVER` says otherwise. This page is about the stack you start when you want the parts SQLite and local disk cannot cover: real Postgres, and real object storage.

The repo-root `docker-compose.yml` gives you both, plus a bucket and a database browser, from one command.

This stack is for local development only. It uses trivial credentials, remapped host ports, and volumes you drop on the way out. Nothing here is meant to face the internet. For the production shape, see [Going to production](../shipping/going-to-production.md).

## What actually needs it

Four things, all opt-in.

| Want | Needs | How it is run |
| --- | --- | --- |
| Run the same suite against a real Postgres driver (`uuid`, `ilike`, transactions) | Postgres | `melos run test-e2e`, or `dart test --tags e2e` in an example |
| Exercise the S3 upload driver end to end | MinIO | the `e2e`-tagged suites under `packages/beak_storage_s3/test/e2e/` and `packages/beak_backend/test/e2e/` |
| Point your own project at Postgres while you build it | Postgres | `DATABASE_URL=postgres://...` in your `.env` |
| Read the database in a browser | pgweb | `melos run up`, then open the console |

Everything else, including every test that runs on a pull request, works on SQLite with no services at all.

## What the stack runs

| Service | Image | Host port to container | Role |
| --- | --- | --- | --- |
| `postgres` | `postgres:16-alpine` | `25432` to `5432` | The Postgres side of the e2e suites. |
| `minio` | `minio/minio` | `29000` to `9000` (S3 API), `29001` to `9001` (console) | Object storage for the S3 driver's integration suite. |
| `createbuckets` | `minio/mc` | none (one-shot) | Creates the `beak-uploads` bucket and allows anonymous downloads. |
| `pgweb` | `sosedoff/pgweb` | `28081` to `8081` | A browser UI for the database. |

The credentials are `beak` / `beak` for Postgres and `beak` / `beaksecret` for the MinIO root user. They match the root `.env.example` and the defaults the suites fall back to, so a fresh checkout connects on the first try with nothing exported.

### Why the odd host ports

Every host port is prefixed with a `2`: `25432`, `29000`, `29001`, `28081`. A dev machine usually already runs Postgres on `5432` and other stacks on `9000` / `9001` / `8081`, so binding the defaults would collide. The container-side ports stay standard; only the host mapping shifts. If even the shifted ports clash, override them without touching the file:

```bash
BEAK_PG_PORT=35432 BEAK_S3_PORT=39000 docker compose up -d --wait
```

The available overrides are `BEAK_PG_PORT`, `BEAK_S3_PORT`, `BEAK_S3_CONSOLE_PORT`, and `BEAK_PGWEB_PORT`.

## Up and down

Melos wraps the whole lifecycle in two scripts, so you never type the raw compose commands.

```yaml title="melos.yaml"
up:
  run: docker compose up -d --wait && docker compose run --rm createbuckets
  description: Start Postgres + MinIO, wait for health, and init the upload bucket.
down:
  run: docker compose down -v
  description: Stop Postgres + MinIO and drop their volumes.
```

The full local setup is three commands:

```bash
melos run up              # start Postgres + MinIO, wait for health, make the bucket
melos run test-e2e        # the service-backed suites
melos run down            # stop everything and drop the volumes
```

!!! note "What just happened"
    - `docker compose up -d --wait` starts Postgres and MinIO and blocks until both report healthy, so nothing races the database.
    - `docker compose run --rm createbuckets` then runs the one-shot bucket init. It lives behind an `init` profile, which is why `up --wait` did not treat its clean exit as a failed service.
    - `melos run down` passes `-v`, so the `pgdata` and `miniodata` volumes go with it. Every `up` starts from an empty database. That is what you want for tests, and a thing to remember before you seed data you care about.

## Pointing a process at it

Copy the committed root `.env.example` to wherever a process should read it. It records the connection strings the compose file exposes, which are these:

```bash
DATABASE_URL=postgres://beak:beak@localhost:25432/beak
BEAK_STORAGE_DRIVER=s3
BEAK_S3_ENDPOINT=http://localhost:29000
BEAK_S3_BUCKET=beak-uploads
BEAK_S3_ACCESS_KEY=beak
BEAK_S3_SECRET_KEY=beaksecret
BEAK_S3_REGION=us-east-1
BEAK_S3_USE_PATH_STYLE=true
```

`.env` is git-ignored; only the example is committed, and it holds no secret worth keeping. See [Environment and config](../shipping/environment-and-config.md) for what each variable does and how a real environment variable overrides a file value.

!!! warning "The e2e suites use their own database"
    They never migrate into the database `DATABASE_URL` names. Each derives a suffixed name from it (`beak_store_e2e`, `beak_e2e`) and runs a fresh migrate there, so an exported `DATABASE_URL` pointing at data you care about cannot be wiped by running the tests.

## What CI does

The pipeline brings the stack up around its test job and tears it down afterward, so the service-backed suites have somewhere to run. The gate that every pull request must pass, though, is the SQLite one. A driver difference is worth catching; needing Docker to see a green build is not.

## Continue reading

- [Environment and config](../shipping/environment-and-config.md) the variables your `.env` sets and how they resolve.
- [Installation](../start-here/installation.md) getting the toolchain and the repo in place.
- [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md) how the bucket becomes a working file column.
- [Going to production](../shipping/going-to-production.md) the durable version of this stack.
