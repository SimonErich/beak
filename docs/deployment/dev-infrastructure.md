---
title: Dev infrastructure
description: The local docker-compose stack that backs the demo apps and integration tests: Postgres, MinIO, a bucket, and a database console.
---

# Dev infrastructure

Before you run either demo app or the integration tests, you need a database and object storage. The repo-root `docker-compose.yml` gives you both, plus a bucket and a database browser, from one command.

This stack is for local development only. It uses trivial credentials, remapped host ports, and volumes you drop on the way out. Nothing here is meant to face the internet. For the production shape, see [Going to production](going-to-production.md).

## What the stack runs

| Service | Image | Host port to container | Role |
| --- | --- | --- | --- |
| `postgres` | `postgres:16-alpine` | `25432` to `5432` | The app and test database. |
| `minio` | `minio/minio` | `29000` to `9000` (S3 API), `29001` to `9001` (console) | Object storage for uploaded files. |
| `createbuckets` | `minio/mc` | none (one-shot) | Creates the `beak-uploads` bucket and allows anonymous downloads. |
| `pgweb` | `sosedoff/pgweb` | `28081` to `8081` | A browser UI for the database. |

The credentials are `beak` / `beak` for Postgres and `beak` / `beaksecret` for the MinIO root user. They match the root `.env.example`, so a fresh `cp` connects on the first try.

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
cp .env.example .env      # local defaults: ports, DB URL, S3 creds
melos run up              # start Postgres + MinIO, wait for health, make the bucket
# ... run your app or tests ...
melos run down            # stop everything and drop the volumes
```

!!! note "What just happened"
    - `docker compose up -d --wait` starts Postgres and MinIO and blocks until both report healthy, so nothing races the database.
    - `docker compose run --rm createbuckets` then runs the one-shot bucket init. It lives behind an `init` profile, which is why `up --wait` did not treat its clean exit as a failed service.
    - `melos run down` passes `-v`, so the `pgdata` and `miniodata` volumes go with it. Every `up` starts from an empty database. That is what you want for tests, and a thing to remember before you seed data you care about.

## What uses it

The demo backends read `DATABASE_URL` and the `BEAK_S3_*` variables from your `.env` and connect to exactly these services. The integration tests in CI do the same: the pipeline runs `melos run up` before `melos run test`, then tears the stack down afterward. So the compose file is not a convenience on the side; it is the contract the backend and its tests are written against.

## Continue reading

- [Environment and config](environment-and-config.md) the variables your `.env` sets and how they resolve.
- [Installation](../start-here/installation.md) getting the toolchain and the repo in place.
- [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md) how the bucket becomes a working file column.
- [Going to production](going-to-production.md) the durable version of this stack.
