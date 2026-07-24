---
title: Going to production
description: The deploy/ folder walked through: the two Dockerfiles, the production compose stack, the exact commands, and an honest checklist of what stays yours.
---

# Going to production

The `deploy/` folder is a real, buildable setup: a pure-Dart backend image, a Flutter-web panel image, and a compose stack that wires them to their own Postgres and MinIO. This page walks through each file and ends with a checklist of the parts you own.

Build everything from the repo root. Beak uses path dependencies, so the whole `packages/` and `apps/` tree has to be in the build context. The repo-root `.dockerignore` trims the rest (build artifacts, `.dart_tool`, coverage, and the melos-managed `pubspec_overrides.yaml`) so resolution comes from each committed `pubspec.yaml`.

## What is in `deploy/`

| File | What it builds |
| --- | --- |
| `Dockerfile.server` | The backend as one AOT-compiled native executable, plus the `beak-migrate` CLI. No obers_ui, no Flutter. |
| `Dockerfile.web` | The Flutter web panel, served by nginx, with obers_ui resolved from git. |
| `nginx.conf` | Static serving with a SPA fallback for go_router routes. |
| `web-overrides.yaml` | Redirects the three obers_ui packages to git during the web build. |
| `docker-compose.prod.yml` | postgres + minio + createbuckets + migrate + server + web. |
| `.env.prod.example` | Copy to `.env.prod` and change the credentials. |

## The server image

`Dockerfile.server` is a two-stage build. The first stage resolves and AOT-compiles the backend on the full Dart SDK; the second copies the resulting binaries onto a slim Debian base. Because the backend never touches Flutter or obers_ui, this is all it takes.

```dockerfile title="deploy/Dockerfile.server"
FROM dart:stable AS build

WORKDIR /app
COPY . .

WORKDIR /app/apps/reference_admin_server
RUN dart pub get
RUN dart compile exe bin/reference_admin_server.dart -o /app/beak-server
# The worm CLI (migrate / db:seed) as a second executable.
RUN dart compile exe bin/worm.dart -o /app/beak-migrate

# --- Runtime image: just glibc + CA roots for HTTPS to Postgres/S3 ---
FROM debian:bookworm-slim AS runtime

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY --from=build /app/beak-server /usr/local/bin/beak-server
COPY --from=build /app/beak-migrate /usr/local/bin/beak-migrate

ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/beak-server"]
```

The second `dart compile exe` is the detail worth noticing. It compiles the app's `bin/worm.dart` into a second binary, `beak-migrate`, and copies it into the same image. So one image carries both the server and the tool that migrates and seeds its schema. The compose stack uses that second binary as its migrate step, which means schema and server can never drift onto different code.

To swap in your own project, change the app path from `apps/reference_admin_server` to your server package. Everything else stays the same.

## The web image

`Dockerfile.web` builds the panel on the Flutter image and serves the output from nginx.

```dockerfile title="deploy/Dockerfile.web"
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app
COPY . .

# Redirect obers_ui to its git source.
COPY deploy/web-overrides.yaml apps/reference_admin/pubspec_overrides.yaml

# Flutter refuses to touch a repo it does not "own" (root user in CI images).
RUN git config --global --add safe.directory '*'

WORKDIR /app/apps/reference_admin
RUN flutter pub get
RUN flutter build web --release

# --- Runtime image: static files served by nginx ---
FROM nginx:alpine AS runtime

COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/apps/reference_admin/build/web /usr/share/nginx/html
EXPOSE 80
```

The one non-obvious line copies `deploy/web-overrides.yaml` into the app as `pubspec_overrides.yaml`. Locally the panel resolves obers_ui by a sibling path, but there is no sibling checkout inside a container, so the override points the three obers_ui packages at their public git source and the image builds on its own. The [obers_ui sibling caveat](the-obers-ui-sibling-caveat.md) covers that trade in full.

nginx serves the static bundle with a single fallback so a hard refresh on a client-side route still lands on the app:

```nginx title="deploy/nginx.conf"
location / {
  try_files $uri $uri/ /index.html;
}
```

Without that fallback, refreshing on a go_router path like `/products/42` would 404, because that path only exists inside the loaded app, not as a file on disk.

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

The API comes up on host `:8080` and the panel on host `:8090`. The panel's `apiBaseUrl` is baked at build time (default `http://localhost:8080`), so in this local demo the browser reaches the server at that host port.

To build either image on its own:

```bash
docker build -f deploy/Dockerfile.server -t beak-server .
docker build -f deploy/Dockerfile.web    -t beak-web .
```

## What was verified

This is not a sketch. It was built and exercised.

!!! example "Verified in this repo"
    - The server image built at **~103 MB**, the web image at **~106 MB**.
    - The `beak-migrate` binary ran all **7 reference migrations** against Postgres.
    - The server booted on `0.0.0.0:8080`, and `POST /api/{table}/query` came back with the correct Beak error envelope.

## Production checklist

The stack builds and runs, but a demo compose file is not a hardened deployment. These parts stay yours, and none of them is optional for a real host.

- **Change every credential.** `deploy/.env.prod.example` ships throwaway values (`beak` / `beak`, `beaksecret`, `BEAK_AUTH_SECRET=change-me-in-prod`). Replace all of them, and match the Postgres and MinIO service credentials in the compose file to whatever `.env.prod` now says.
- **Put TLS in front.** Nothing in this stack terminates HTTPS. Run a reverse proxy (nginx, Caddy, Traefik) that holds your certificate and forwards to the `server` and `web` containers.
- **Run migrations on every deploy.** Schema changes are explicit and never auto-applied. Before or during each rollout, run `docker compose -f deploy/docker-compose.prod.yml --profile setup run --rm migrate`.
- **Set the panel's `apiBaseUrl` before building the web image.** It is compiled into the bundle. The default `http://localhost:8080` only works for a local demo; a remote deploy needs your real API origin, set before `flutter build web`.
- **Use durable storage and back it up.** The `pgdata` and `miniodata` volumes are local Docker volumes. For anything you care about, back them up or point `DATABASE_URL` and the `BEAK_S3_*` variables at managed Postgres and S3.
- **Swap in your own server package.** `Dockerfile.server` compiles `apps/reference_admin_server`. Change that path to your project's server before you ship your own app.

## Continue reading

- [Environment and config](environment-and-config.md) the variables `.env.prod` sets.
- [The obers_ui sibling caveat](the-obers-ui-sibling-caveat.md) why the web image redirects obers_ui to git.
- [Migrations](../backend/migrations.md) what `beak-migrate` runs, and how migrations are registered.
- [Seeding](../backend/seeding.md) what `migrate db:seed` puts in the database.
