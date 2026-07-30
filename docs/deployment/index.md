---
title: Deployment
description: How Beak ships. The zero-service default, the two production images, and where you adapt them.
---

# Deployment

This section covers how you run Beak past `beak dev`: what a Beak project needs to boot (less than you expect), and the two Docker images that put a Beak backend and panel on a real host. The local stack for the parts that need real services is a contributor topic, and lives under Contributing.

## The default is no infrastructure

A fresh Beak project has no `docker-compose.yml`, no `.env`, and no credentials. `DATABASE_URL` is optional and defaults to `sqlite:beak.db`, a file created beside the process on first run. Uploads land on local disk under `storage/uploads`, served by the Beak server itself, until `BEAK_STORAGE_DRIVER` points somewhere else. So the whole loop is:

```bash
beak migrate
beak dev
```

That is deliberate. Requiring a database before a reader sees anything at all loses more first-time users than any other step. Everything below is what you reach for **after** that, and each piece is opt-in.

- **Dev infrastructure** is the local stack *this repository* uses for the parts SQLite cannot cover: Postgres, MinIO, and a database console in one `docker-compose.yml`. It is something you start to work on Beak, not something you deploy, so its page is filed under Contributing: [Dev infrastructure](dev-infrastructure.md). You need it for the `e2e`-tagged suites and for S3 uploads, not to run an app.
- **Going to production** is the `deploy/` folder: two images and a compose file that build the backend and panel from scratch and wire them to their own Postgres and MinIO. See [Going to production](going-to-production.md).

## Two images, because Beak is two programs

A Beak project is one package, but it compiles to two artifacts, and the deployment follows that line.

| Image | What it is | Depends on | Base |
| --- | --- | --- | --- |
| `beak-server` | `bin/serve.dart` as one AOT-compiled native executable, plus `bin/migrate.dart` as the `beak-migrate` CLI for schema and seed. | `beak_backend`, `beak_core`, `worm`. No Flutter, no obers_ui. | `debian:bookworm-slim` |
| `beak-web` | `lib/main.dart` built for web: static files served by nginx with a SPA fallback. | Flutter, obers_ui. | `nginx:alpine` |

The backend half is pure Dart. It never imports Flutter or obers_ui, so it compiles to a single binary and boots on a slim Debian base with nothing but glibc and CA roots. Only the panel needs obers_ui, and only the panel needs a Flutter toolchain to build.

That the split holds is not a hope. `melos run guard-web` walks the import graph from every panel-side entrypoint and fails the build if server code appears on it, and CI builds a panel for web on every run as the empirical half of the same check. [Working with obers_ui](working-with-obers-ui.md) explains how the panel resolves obers_ui without any build-time override.

## A starting point, not a platform

The deployment files live in the repo under [`deploy/`](https://github.com/SimonErich/beak/tree/main/deploy), with a [README](https://github.com/SimonErich/beak/blob/main/deploy/README.md) that mirrors the commands you will find here. They build, and they were exercised end to end: the migrations ran, the server booted, and the API answered with the correct Beak error envelope.

They are a reference you copy and adapt, not a managed platform. Beak does not run your servers, terminate your TLS, or rotate your secrets. What it hands you is a correct, minimal shape to start from: the multi-stage builds, the migrate-on-deploy step, the storage wiring, and the two health probes a container platform will ask for. The [production checklist](going-to-production.md#production-checklist) is honest about the parts that stay yours.

!!! note "What lives where"
    The dev `docker-compose.yml` and root `.env.example` sit at the repo root and serve this repository's own examples and test suites. The production `Dockerfile.server`, `Dockerfile.web`, `docker-compose.prod.yml`, and `.env.prod.example` all live under `deploy/`. They do not share a compose file, and they use different ports and credentials on purpose.

## Continue reading

- [Environment and config](environment-and-config.md) every variable a Beak backend reads, and how it resolves at boot.
- [Going to production](going-to-production.md) the real `deploy/` setup, walked through file by file.
- [Dev infrastructure](dev-infrastructure.md) the optional local Postgres and MinIO stack, under Contributing.
- [Working with obers_ui](working-with-obers-ui.md) how obers_ui is pinned by commit, and how to develop against a local checkout.
