---
title: Going to production
description: The deploy/ folder walked through: the two Dockerfiles, the production compose stack, the exact commands, and an honest checklist of what stays yours.
---

# Going to production

The `deploy/` folder is a real, buildable setup: a pure-Dart backend image, a Flutter-web panel image, and a compose stack that wires them to their own Postgres and MinIO. This page walks through each file and ends with a checklist of the parts you own.

Build everything from the repo root. Beak uses path dependencies here, so the whole `packages/` and `examples/` tree has to be in the build context. The repo-root `.dockerignore` trims the rest (build artifacts, `.dart_tool`, coverage, and the melos-managed `pubspec_overrides.yaml`) so resolution comes from each committed `pubspec.yaml`.

!!! note "Nothing is generated at build time"
    `lib/beak/*.g.dart` and `lib/models/*.beak.dart` are committed, so neither image runs `beak prepare`. `bin/serve.dart` and `bin/migrate.dart` are git-ignored by default, so a project that builds images from a clean checkout should either run `beak prepare` in the build or commit them with `beak eject main`. The examples in this repository commit them.

## What is in `deploy/`

| File | What it builds |
| --- | --- |
| `Dockerfile.server` | The backend as one AOT-compiled native executable, plus the `beak-migrate` CLI. No obers_ui, no Flutter. |
| `Dockerfile.web` | The Flutter web panel, served by nginx. obers_ui is pinned by git commit in the pubspecs, so no build-time override is needed. |
| `nginx.conf` | Static serving with a SPA fallback for go_router routes, and long-lived caching for hashed assets. |
| `docker-compose.prod.yml` | postgres + minio + createbuckets + migrate + server + web. |
| `.env.prod.example` | Copy to `.env.prod` and change the credentials. |

## The server image

`Dockerfile.server` is a two-stage build. The first stage resolves and AOT-compiles the backend on the full Dart SDK; the second copies the resulting binaries onto a slim Debian base. Because the backend never touches Flutter or obers_ui, this is all it takes.

```dockerfile title="deploy/Dockerfile.server"
FROM dart:stable AS build

WORKDIR /app
COPY . .

WORKDIR /app/examples/store
RUN dart pub get
RUN dart compile exe bin/serve.dart -o /app/beak-server
# The worm CLI (migrate / db:seed) as a second executable, so schema and seed
# steps run from the same image (see the migrate service in the compose file).
RUN dart compile exe bin/migrate.dart -o /app/beak-migrate

# --- Runtime image: just glibc + CA roots for HTTPS to Postgres/S3 ---
FROM debian:bookworm-slim AS runtime

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY --from=build /app/beak-server /usr/local/bin/beak-server
COPY --from=build /app/beak-migrate /usr/local/bin/beak-migrate

# BeakBackendConfig defaults to host 0.0.0.0; PORT is read from the environment.
ENV PORT=8080
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/beak-server"]
```

The second `dart compile exe` is the detail worth noticing. `bin/migrate.dart` compiles into a second binary, `beak-migrate`, in the same image. So one image carries both the server and the tool that migrates and seeds its schema, and both were generated from the same `BeakServeHost`. The compose stack uses that second binary as its migrate step, which means schema and server can never drift onto different code.

Every Beak project has these two entrypoints at these two paths, because `beak prepare` writes them there. To swap in your own project, change `examples/store` to your package directory. Everything else stays the same.

## The web image

`Dockerfile.web` builds the panel on the Flutter image and serves the output from nginx.

```dockerfile title="deploy/Dockerfile.web"
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app
COPY . .

# Flutter refuses to touch a repo it does not "own" (root user in CI images).
RUN git config --global --add safe.directory '*'

WORKDIR /app/examples/store
RUN flutter pub get
RUN flutter build web --release

# --- Runtime image: static files served by nginx ---
FROM nginx:alpine AS runtime

COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/examples/store/build/web /usr/share/nginx/html

EXPOSE 80
```

There is nothing non-obvious left in this file: because obers_ui is pinned by git commit in the pubspecs themselves, the image resolves exactly what your machine resolves, with no injected overrides. [Working with obers_ui](working-with-obers-ui.md) covers how that pin works and how to develop against a local checkout.

The one thing you will change is the API origin. It is compiled into the bundle, so it is a build argument, not a runtime one:

```dockerfile
RUN flutter build web --release \
  --dart-define=BEAK_API_BASE_URL=https://api.example.com
```

Or set `api.baseUrl: auto` in `beak.yaml` and the panel calls whatever origin served it, which is what a deployment putting both halves behind one hostname wants. See [Environment and config](environment-and-config.md#the-panels-api-origin).

nginx serves the static bundle with a single fallback so a hard refresh on a client-side route still lands on the app:

```nginx title="deploy/nginx.conf"
location / {
  try_files $uri $uri/ /index.html;
}
```

Without that fallback, refreshing on a go_router path like `/products/42` would 404, because that path only exists inside the loaded app, not as a file on disk. The file also long-caches `/assets/`, which is safe because those filenames are content-hashed, while never caching the entry document.

## The compose stack

`docker-compose.prod.yml` wires six services. Two of them, `createbuckets` and `migrate`, sit behind a `setup` profile so an ordinary `up` never runs them; you invoke those by hand, once, when you provision.

| Service | Image | Profile | Role |
| --- | --- | --- | --- |
| `postgres` | `postgres:16-alpine` | always | Database, backed by the `pgdata` volume. |
| `minio` | `minio/minio` | always | Object storage, backed by the `miniodata` volume. |
| `createbuckets` | `minio/mc` | `setup` | One-shot bucket init. |
| `migrate` | `beak-server` (built from `Dockerfile.server`) | `setup` | Runs `beak-migrate` for schema and seed. |
| `server` | `beak-server` | always | The API, published on host `:8080`. |
| `web` | `beak-web` (built from `Dockerfile.web`) | always | The panel, published on host `:8090`. |

Every service that talks to Postgres or MinIO waits on a health check first, so the migrate step never races an unready database. Unlike the dev stack, these services reach each other over the internal compose network on their standard container ports (`postgres:5432`, `minio:9000`), which is exactly what `.env.prod` encodes.

Note what the presence of Postgres here means: it is `.env.prod`'s `DATABASE_URL` that opts into it. The same image, given no `DATABASE_URL`, would run on a SQLite file inside the container, which is fine for a demo and wrong for anything with a second replica or a container that gets replaced.

## Health probes

The server answers two probes, mounted outside `/api` so the auth middleware never guards them.

| Route | Meaning | Use it as |
| --- | --- | --- |
| `GET /healthz` | The process is serving. Never touches the database. | Liveness probe |
| `GET /readyz` | The data source answers; 503 with the real error when it does not. | Readiness probe |

Conflating them is how a rolling deploy takes a service down. A database blip must move traffic away from a replica, never restart it. Point Kubernetes, Cloud Run, Fly or ECS at the right one of each.

## Bringing it up

Copy the env file, edit the secrets, then run the four phases from the repo root. These are the exact commands from `deploy/README.md`.

```bash
cp deploy/.env.prod.example deploy/.env.prod   # then edit the secrets

# data services
docker compose -f deploy/docker-compose.prod.yml up -d --build postgres minio

# one-time setup (bucket, schema, seed)
docker compose -f deploy/docker-compose.prod.yml --profile setup run --rm createbuckets
docker compose -f deploy/docker-compose.prod.yml --profile setup run --rm migrate
docker compose -f deploy/docker-compose.prod.yml --profile setup run --rm migrate db:seed

# the app
docker compose -f deploy/docker-compose.prod.yml up -d --build server web
```

The API comes up on host `:8080` and the panel on host `:8090`. The panel's API origin is baked at build time (the store's `beak.yaml` says `http://localhost:8080`), so in this local demo the browser reaches the server at that host port.

To build either image on its own:

```bash
docker build -f deploy/Dockerfile.server -t beak-server .
docker build -f deploy/Dockerfile.web    -t beak-web .
```

## What was verified

This is not a sketch. It was built and exercised.

!!! example "Verified in this repo"
    - Both images built: the server as a single native executable on `debian:bookworm-slim`, the panel as static files on `nginx:alpine`.
    - The `beak-migrate` binary ran the store's migrations against Postgres.
    - The server booted on `0.0.0.0:8080`, and `POST /api/{table}/query` came back with the correct Beak error envelope.

The store's own suites cover the rest of the claim from the other side: `dart test test/api_sqlite_test.dart` runs the whole API on `sqlite::memory:`, and `melos run up && dart test --tags e2e` runs the same assertions against Postgres.

## Production checklist

The stack builds and runs, but a demo compose file is not a hardened deployment. These parts stay yours, and none of them is optional for a real host.

- **Change every credential.** `deploy/.env.prod.example` ships throwaway values (`beak` / `beak`, `beaksecret`, and a placeholder auth secret). Replace all of them, and match the Postgres and MinIO service credentials in the compose file to whatever `.env.prod` now says.
- **Point `DATABASE_URL` at a real database.** The default is a SQLite file, which is right for development and wrong for a container that can be replaced or scaled. The compose file sets a `postgres://` URL; a managed Postgres is the same line with a different host.
- **Put TLS in front.** Nothing in this stack terminates HTTPS. Run a reverse proxy (nginx, Caddy, Traefik) that holds your certificate and forwards to the `server` and `web` containers.
- **Run migrations on every deploy.** Schema changes are explicit and never auto-applied. Before or during each rollout, run `docker compose -f deploy/docker-compose.prod.yml --profile setup run --rm migrate`.
- **Set the panel's API origin before building the web image.** It is compiled into the bundle. Pass `--dart-define=BEAK_API_BASE_URL=https://api.example.com`, or set `api.baseUrl: auto` if the panel and the API share a hostname. The `http://localhost:8080` default only works for a local demo.
- **Wire the probes.** Liveness on `/healthz`, readiness on `/readyz`. Getting them the wrong way round turns a slow query into a restart loop.
- **Use durable storage and back it up.** The `pgdata` and `miniodata` volumes are local Docker volumes. For anything you care about, back them up or point `DATABASE_URL` and the storage variables at managed Postgres and S3.
- **Swap in your own project.** Both Dockerfiles build `examples/store`. Change that path to your package before you ship your own app; the two entrypoint files are at the same paths in every Beak project.

## Continue reading

- [Environment and config](environment-and-config.md) the variables `.env.prod` sets, and where the panel's origin comes from instead.
- [Working with obers_ui](working-with-obers-ui.md) how the pinned commit makes the web image build with no overrides.
- [Migrations](../backend/migrations.md) what `beak-migrate` runs, and how migrations are discovered.
- [Seeding](../backend/seeding.md) what `migrate db:seed` puts in the database.
