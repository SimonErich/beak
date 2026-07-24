---
title: Deployment
description: How Beak ships. The local dev stack, the two production images, and where you adapt them for your own project.
---

# Deployment

This section covers how you run Beak past `flutter run`: the local infrastructure the demo apps talk to, and the two Docker images that put a Beak backend and panel on a real host.

Deploying Beak has two halves, and it helps to keep them apart in your head.

- **Dev infrastructure** is the local stack the apps and integration tests need: Postgres, MinIO, and a database console, all in one `docker-compose.yml`. You start it once and forget it. See [Dev infrastructure](dev-infrastructure.md).
- **Going to production** is the `deploy/` folder: two images and a compose file that build the backend and panel from scratch and wire them to their own Postgres and MinIO. See [Going to production](going-to-production.md).

## Two images, because Beak is two programs

Beak splits cleanly along a dependency line, and the deployment follows that line.

| Image | What it is | Depends on | Base | Built size |
| --- | --- | --- | --- | --- |
| `beak-server` | The backend as one AOT-compiled native executable, plus the `beak-migrate` CLI for schema and seed. | `beak_backend`, `beak_core`, `worm`. No Flutter, no obers_ui. | `debian:bookworm-slim` | ~103 MB |
| `beak-web` | The Flutter web panel: static files served by nginx with a SPA fallback. | Flutter, obers_ui. | `nginx:alpine` | ~106 MB |

The backend is pure Dart. It never imports Flutter or obers_ui, so it compiles to a single binary and boots on a slim Debian base with nothing but glibc and CA roots. Only the panel needs obers_ui, and only the panel needs a Flutter toolchain to build. Keeping the two apart is what lets the server image stay small and the web image build on its own. The [obers_ui sibling caveat](the-obers-ui-sibling-caveat.md) explains the one wrinkle that split introduces.

## A starting point, not a platform

The deployment files live in the repo under [`deploy/`](https://github.com/SimonErich/beak/tree/main/deploy), with a [README](https://github.com/SimonErich/beak/blob/main/deploy/README.md) that mirrors the commands you will find here. They build, and they passed an end-to-end smoke test: the migrations ran, the server booted, and the API answered with the correct Beak error envelope.

They are a reference you copy and adapt, not a managed platform. Beak does not run your servers, terminate your TLS, or rotate your secrets. What it hands you is a correct, minimal shape to start from: the multi-stage builds, the migrate-on-deploy step, the storage wiring. The [production checklist](going-to-production.md#production-checklist) is honest about the parts that stay yours.

!!! note "What lives where"
    The dev `docker-compose.yml` and root `.env.example` sit at the repo root and serve the local apps. The production `Dockerfile.server`, `Dockerfile.web`, `docker-compose.prod.yml`, and `.env.prod.example` all live under `deploy/`. They do not share a compose file, and they use different ports and credentials on purpose.

## Continue reading

- [Environment and config](environment-and-config.md) the `.env` surface and how it resolves at boot.
- [Dev infrastructure](dev-infrastructure.md) the local Postgres and MinIO stack for running the apps and tests.
- [Going to production](going-to-production.md) the real `deploy/` setup, walked through file by file.
- [The obers_ui sibling caveat](the-obers-ui-sibling-caveat.md) why a fresh clone needs a sibling checkout, and the two ways to fix it.
