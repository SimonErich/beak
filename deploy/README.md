# Deploying Beak with Docker

This folder builds `examples/clean_beak_config`: a pure-Dart backend image,
a Flutter-web panel image, and a compose stack that wires them to Postgres. The
prose version, with the production checklist and the tradeoffs, lives in the docs
under [Deployment](../docs/shipping/index.md).

## What is here

| File | What it builds |
| --- | --- |
| `Dockerfile.server` | The backend as a `dart build cli` bundle on `debian:bookworm-slim` (`/opt/beak/server/bin/serve`, with its SQLite library beside it). Also carries the worm CLI as a second bundle (`/opt/beak/migrate/bin/migrate`) for schema and seed steps. The build stage resolves the shared Flutter package; the runtime contains only native binaries. |
| `Dockerfile.web` | The Flutter web panel, served by nginx. Needs no dependency overrides — obers_ui is pinned by git commit in the pubspecs, so it resolves the same way in a container as on your machine. |
| `nginx.conf` | Static serving with a SPA fallback for go_router routes. |
| `docker-compose.prod.yml` | postgres + migrate + server + web, with uploads on a named volume. |
| `.env.prod.example` | Copy to `.env.prod` and change the credentials. |

## Quick start (from the repo root)

```bash
cp deploy/.env.prod.example deploy/.env.prod   # then edit the secrets

# the database
docker compose -f deploy/docker-compose.prod.yml up -d postgres

# one-time setup (schema, seed)
docker compose -f deploy/docker-compose.prod.yml --profile setup run --rm migrate
docker compose -f deploy/docker-compose.prod.yml --profile setup run --rm migrate db:seed

# the app
docker compose -f deploy/docker-compose.prod.yml up -d --build server web
```

The API is published on `127.0.0.1:8080` and the panel on `127.0.0.1:8090`: the
shop's server has no policy and no login, so the stack keeps both on the loopback
interface. The panel's `apiBaseUrl` is baked at build time (default
`http://localhost:8080`), so the browser reaches the server at that host port.
For a real remote deploy, set the panel's `apiBaseUrl` to your API origin before
building, put TLS in front, and swap the dev credentials.

## Build one image on its own

```bash
docker build -f deploy/Dockerfile.server -t beak-server .
docker build -f deploy/Dockerfile.web -t beak-web \
  --build-arg BEAK_API_BASE_URL=https://api.example.com .
```

Always build from the repo root: Beak uses path dependencies, so the whole
`packages/` and `examples/` tree must be in the build context. The repo-root
`.dockerignore` trims the rest.
