# Dev infrastructure

> Start the local Postgres and MinIO stack, know which suites use it, and what to change when its ports clash with yours.

You do not need this to run a Beak app, or to get the four gate commands green. A project with no `DATABASE_URL` runs on a SQLite file that the first `beak migrate` creates, and uploads land on local disk until `BEAK_STORAGE_DRIVER` says otherwise. This page is for the parts SQLite and local disk cannot cover: a real Postgres and real object storage.

The repo-root `docker-compose.yml` starts both, plus a bucket and a database browser, with one command. It is for local development only: trivial credentials, remapped host ports, volumes you drop on the way out. For the production shape, read [Going to production](../shipping/going-to-production.md).

## At a glance

| Service | Image | Host port | Container port | Login |
| --- | --- | --- | --- | --- |
| `postgres` | `postgres:16-alpine` | `25432` | `5432` | `beak` / `beak`, database `beak` |
| `minio` | `minio/minio:latest` | `29000` (S3 API), `29001` (console) | `9000`, `9001` | `beak` / `beaksecret` |
| `createbuckets` | `minio/mc:latest` | none, one-shot | none | creates the bucket `beak-uploads` and allows anonymous downloads |
| `pgweb` | `sosedoff/pgweb:latest` | `28081` | `8081` | none, connects as `beak` |

```bash
melos run up          # start Postgres and MinIO, wait for health, make the bucket
melos run test-e2e    # the service-backed suites
melos run down        # stop everything and drop the volumes
```

The scripts are two lines of `melos.yaml`:

```yaml title="melos.yaml"
  up:
    run: docker compose up -d --wait && docker compose run --rm createbuckets
    description: Start Postgres + MinIO, wait for health, and init the upload bucket.
  down:
    run: docker compose down -v
    description: Stop Postgres + MinIO and drop their volumes.
```

> **Note: What just happened**
>
> - `docker compose up -d --wait` starts the three long-running services and blocks until `postgres` and `minio` report healthy, so nothing races the database. `pgweb` has no health check, so `--wait` only waits for it to be running.
> - `docker compose run --rm createbuckets` runs the one-shot bucket setup. It sits behind an `init` profile, which is why `up --wait` does not count its clean exit as a failed service.
> - `melos run down` passes `-v`, so both volumes go with the containers. Every `up` starts from an empty database. That suits tests, and it is worth remembering before you seed data you care about.

## Who needs it

Everything opt-in. Nothing in `melos run analyze`, `format-check`, `test` or `coverage` starts a container.

| Suite or use | Needs | Runs with |
| --- | --- | --- |
| The `postgres_*_test.dart` files in `packages/beak_backend/test/e2e/` | Postgres | `melos run test-e2e` |
| `packages/beak_backend/test/e2e/upload_s3_integration_test.dart`, `packages/beak_storage_s3/test/e2e/s3_minio_integration_test.dart` | MinIO | `melos run test-e2e` |
| `packages/beak_cli/test/e2e/round_trip_test.dart`, `postgres_introspection_test.dart` | Postgres | `melos run test-e2e` |
| The vendored `worm_postgres` contract suite | Postgres | `melos run test-worm`, or `melos run test-worm-postgres` alone |
| Your own project on Postgres | Postgres | `DATABASE_URL` in the project's `.env` |
| Reading the database in a browser | pgweb | open `http://localhost:28081` |

CI brings the stack up inside its test job, right after the gate, then runs `test-e2e` and `test-worm` against it. A failing service suite therefore turns that job red. You only skip Docker locally.

## Why the odd ports

Every host port carries a leading `2`: `25432`, `29000`, `29001`, `28081`. A development machine usually runs Postgres on `5432` and other stacks on `9000`, `9001` or `8081`, so the defaults would collide. Only the host side shifts. The container ports stay standard. Each mapping also starts with `127.0.0.1:`, so the stack answers on this machine only.

```yaml title="docker-compose.yml"
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: beak
      POSTGRES_PASSWORD: beak
      POSTGRES_DB: beak
    ports: ["127.0.0.1:${BEAK_PG_PORT:-25432}:5432"]
```

If the shifted ports clash too, override them without touching the file. The four variables are `BEAK_PG_PORT`, `BEAK_S3_PORT`, `BEAK_S3_CONSOLE_PORT` and `BEAK_PGWEB_PORT`:

```bash
BEAK_PG_PORT=35432 BEAK_S3_PORT=39000 BEAK_S3_CONSOLE_PORT=39001 BEAK_PGWEB_PORT=38081 \
  docker compose up -d --wait
```

The suites read `DATABASE_URL` and `BEAK_S3_ENDPOINT` from the environment and fall back to the default ports, so point them at the new ones when you move the stack:

```bash
DATABASE_URL=postgres://beak:beak@localhost:35432/beak \
BEAK_S3_ENDPOINT=http://localhost:39000 \
  melos run test-e2e
```

To run a second, separate stack next to the first, give it a project name with `docker compose -p other` and a different set of ports. Volumes and containers are named after the project, so the two do not share a database.

## Pointing a process at it

The committed `.env.example` records the connection settings the stack exposes:

```bash
# The demo backend's HTTP port (8180 — 8080-8082 are commonly taken by Serverpod-style stacks).
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

A Beak process reads `.env` from its working directory and lets the real environment win, through `BeakEnv.resolve`:

```dart title="packages/beak_backend/lib/src/config/env_loader.dart"
static Map<String, String> resolve({
  String filePath = '.env',
  Map<String, String>? processEnvironment,
}) => {...loadFile(filePath), ...processEnvironment ?? Platform.environment};
```

So copy `.env.example` into the directory you run the server from, and edit the copy. `.env` is git-ignored, and the example holds nothing worth keeping secret. [Environment and config](../shipping/environment-and-config.md) explains each variable and the precedence.

## What the suites do to the database

None of them migrate your data, and none touch a table they did not create.

- `postgres_integration_test.dart` connects and runs `SELECT 1`.
- `postgres_commit_test.dart` and `postgres_outbox_test.dart` create a scratch database named `beak_commit_e2e_<microseconds>` or `beak_outbox_e2e_<microseconds>` and drop it afterwards.
- `postgres_write_errors_test.dart` creates and drops tables prefixed `wr_`, and `postgres_legacy_schema_test.dart` a table and an enum type prefixed `e2e_`, in the database `DATABASE_URL` names.
- The CLI round trip works in two databases of its own, `beak_round_trip_origin` and `beak_round_trip_rebuilt`, created next to `beak` on first use. It drops the `public` schema in those two at the start of each run and leaves the databases behind. It derives their names from `DATABASE_URL`, so a stray value cannot make it drop a database you care about.
- The MinIO suites write to the bucket `beak-uploads`. The upload test deletes what it stored.

## Rules and limits

- Ports listen on the loopback interface only. Compose publishes each on `127.0.0.1`, because the passwords are `beak` and `beaksecret`. Nothing on your network can reach the stack, and neither can a container on another machine or a phone testing the panel over Wi-Fi. To reach it from elsewhere, drop the `127.0.0.1:` prefix from that mapping and change the passwords first.
- `up` alone leaves no bucket. Only `createbuckets` makes `beak-uploads`. Use the `melos run up` script, not a bare `docker compose up`.
- Three images are unpinned. MinIO, `mc` and pgweb are `latest`, so a fresh pull can change behavior under you. Postgres is pinned to major version 16.
- `e2e` also means slow. Three CLI suites run on SQLite and need no container. They carry the tag because a real `flutter pub get` is too slow for the main gate.
- Run `dart run packages/beak_cli/bin/beak.dart` one at a time. From a checkout, two of them started together can both build the native-assets hook and one fails with `PathNotFoundException ... .dart_tool/lib/libsqlite3.so`. It comes from `dart run` building in the shared checkout: six parallel runs of a `dart pub global activate --source path` executable all succeeded, so an installed `beak` is not affected.
- Project name follows the directory. The compose project is named `beak` because the checkout folder is. A checkout in another folder gets other container and volume names.

## Verify it

Bring the stack up and check what it answers:

```bash
melos run up
docker compose ps
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:29000/minio/health/live
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:28081/
```

`docker compose ps` lists `postgres` and `minio` as `healthy` and `pgweb` as `Up`, and both `curl` calls print `200`. Then run the suites that were skipping:

```bash
melos run test-e2e
```

With the stack up, each suite ends in a pass. Without it, each one skips itself with an `is unreachable` message and ends in `All tests skipped.`.

```text
All tests passed!
```

The count differs per suite. `round_trip_test.dart` takes about 40 seconds on its own, because it introspects a schema, generates code and runs the migrations.

## Reference

| Thing | Where |
| --- | --- |
| The stack | `docker-compose.yml` |
| Start and stop | `up` and `down` in `melos.yaml` |
| Service suites | `test-e2e`, `test-e2e-dart`, `test-e2e-flutter`, `test-worm-postgres` in `melos.yaml` |
| The `e2e` tag | `packages/beak_backend/dart_test.yaml`, `packages/beak_storage_s3/dart_test.yaml` |
| Default connection settings | `.env.example` |
| Port overrides | `BEAK_PG_PORT`, `BEAK_S3_PORT`, `BEAK_S3_CONSOLE_PORT`, `BEAK_PGWEB_PORT` |
| Worm's Postgres URL | `PG_DB`, defaulting to `postgres://beak:beak@localhost:25432/beak?sslmode=disable` |

## Continue reading

- [Environment and config](../shipping/environment-and-config.md) the variables a `.env` sets and how they resolve.
- [Databases](../backend/databases.md) SQLite and Postgres from the app's side.
- [Uploads and storage wiring](../backend/uploads-and-storage-wiring.md) how the bucket becomes a working file column.
- [Going to production](../shipping/going-to-production.md) the durable version of this stack.
