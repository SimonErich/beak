# Deploying Beak with Docker

This folder holds a real, buildable deployment setup: a pure-Dart backend image,
a Flutter-web panel image, and a compose stack that wires them to Postgres and
MinIO. The prose version, with the production checklist and the tradeoffs, lives
in the docs under [Deployment](../docs/deployment/index.md).

## What is here

| File | What it builds |
| --- | --- |
| `Dockerfile.server` | The backend as one AOT-compiled native executable on `debian:bookworm-slim`. Also carries the worm CLI (`beak-migrate`) for schema and seed steps. No obers_ui, no Flutter. |
| `Dockerfile.web` | The Flutter web panel, served by nginx. Resolves obers_ui from git via `web-overrides.yaml` so it builds without the sibling checkout. |
| `nginx.conf` | Static serving with a SPA fallback for go_router routes. |
| `web-overrides.yaml` | Redirects the three obers_ui packages to git during the web build. |
| `docker-compose.prod.yml` | postgres + minio + createbuckets + migrate + server + web. |
| `.env.prod.example` | Copy to `.env.prod` and change the credentials. |

## Quick start (from the repo root)

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

The API is published on host `:8080` and the panel on host `:8090`. The panel's
`apiBaseUrl` is baked at build time (default `http://localhost:8080`), so the
browser reaches the server at that host port. For a real remote deploy, set the
panel's `apiBaseUrl` to your API origin before building, put TLS in front, and
swap the dev credentials.

## Build one image on its own

```bash
docker build -f deploy/Dockerfile.server -t beak-server .
docker build -f deploy/Dockerfile.web    -t beak-web .
```

Always build from the repo root: Beak uses path dependencies, so the whole
`packages/` and `apps/` tree must be in the build context. The repo-root
`.dockerignore` trims the rest.
