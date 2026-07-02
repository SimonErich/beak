# Phase 00 — Foundation & guardrails

## Objective
Turn the empty repo into a clean Melos monorepo that already passes the full gate:
vendored worm path deps, obers_ui path deps, strict lints, Docker services, Melos
scripts, CI, and empty-but-valid package skeletons. No feature code yet.

## Prerequisites
- `packages/worm/*` present (worm + worm_postgres + worm_generator + worm_lints).
  If absent → write `NEEDS_HUMAN.md` (external blocker) and stop.
- `~/Flutters/obers_ui` present (obers_ui + obers_ui_autoforms + obers_ui_charts).
  If absent, still complete everything that doesn't need it; frontend phases will gate
  on it later. Note the absence in STATE.md but do NOT block Phase 0.
- `dart`, `flutter`, `docker`, `docker compose` available. `melos` activated
  (`dart pub global activate melos`); if not, do it.

## Files created
- `melos.yaml`, root `pubspec.yaml` (Dart workspace), `analysis_options.yaml`
- `docker-compose.yml`, `.env.example`, `.gitignore`, `.editorconfig`
- `.github/workflows/ci.yaml`
- `tool/check_coverage.dart` (coverage-threshold enforcer used by `melos run coverage`)
- Empty package skeletons with passing smoke tests:
  `packages/beak_core`, `packages/beak_storage_s3`, `packages/beak_storage_ftp`,
  `packages/beak_backend`, `packages/beak_frontend`, `packages/beak_cli`
- App skeletons: `apps/reference_admin` (Flutter), `apps/reference_admin_server` (Dart)

## Exact content for key files

### `melos.yaml`
```yaml
name: beak
packages:
  - packages/**
  - apps/**
command:
  bootstrap:
    runPubGetInParallel: true
scripts:
  analyze:
    run: melos exec -- "dart analyze --fatal-infos --fatal-warnings ."
    description: Static analysis across all packages (0 issues required).
    packageFilters: { flutter: false }
  analyze-flutter:
    run: melos exec -- "flutter analyze --fatal-infos --fatal-warnings"
    packageFilters: { flutter: true }
  format-check:
    run: dart format --output=none --set-exit-if-changed .
    description: Formatting must be clean.
  test:
    run: melos exec --fail-fast -- "dart test --coverage=coverage"
    description: Run pure-Dart package tests with coverage.
    packageFilters: { flutter: false, dirExists: test }
  test-flutter:
    run: melos exec --fail-fast -- "flutter test --coverage"
    packageFilters: { flutter: true, dirExists: test }
  coverage:
    run: dart run tool/check_coverage.dart
    description: Enforce per-package line-coverage thresholds.
  up:
    run: docker compose up -d --wait
    description: Start Postgres + MinIO and wait for health.
  down:
    run: docker compose down -v
```
> `melos run test` must invoke BOTH `test` and `test-flutter` scopes across the build —
> wire an umbrella script if needed so the single gate command covers every package.

### `analysis_options.yaml` (root, shared)
```yaml
include: package:lints/recommended.yaml
analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    invalid_annotation_target: ignore
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
linter:
  rules:
    - always_declare_return_types
    - avoid_dynamic_calls
    - type_annotate_public_apis
    - prefer_const_constructors
    - prefer_const_declarations
    - prefer_final_locals
    - prefer_final_in_for_each
    - prefer_final_fields
    - unnecessary_null_checks
    - avoid_print
    - require_trailing_commas
    - unawaited_futures
    - cancel_subscriptions
    - close_sinks
```
> `beak_frontend` and the Flutter app add a local `analysis_options.yaml` that
> `include:`s the root and layers Flutter lints, plus a custom rule/CI grep that FAILS
> on any `package:flutter/material.dart` or `package:flutter/cupertino.dart` import.

### `docker-compose.yml`
```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: beak
      POSTGRES_PASSWORD: beak
      POSTGRES_DB: beak
    ports: ["5432:5432"]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U beak"]
      interval: 3s
      timeout: 3s
      retries: 20
    volumes: ["pgdata:/var/lib/postgresql/data"]
  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: beak
      MINIO_ROOT_PASSWORD: beaksecret
    ports: ["9000:9000", "9001:9001"]
    healthcheck:
      test: ["CMD", "mc", "ready", "local"]
      interval: 3s
      timeout: 3s
      retries: 20
    volumes: ["miniodata:/data"]
  createbuckets:
    image: minio/mc:latest
    depends_on: { minio: { condition: service_healthy } }
    entrypoint: >
      /bin/sh -c "
      mc alias set local http://minio:9000 beak beaksecret &&
      mc mb -p local/beak-uploads &&
      mc anonymous set download local/beak-uploads || true"
  pgweb:
    image: sosedoff/pgweb:latest
    depends_on: { postgres: { condition: service_healthy } }
    environment:
      PGWEB_DATABASE_URL: postgres://beak:beak@postgres:5432/beak?sslmode=disable
    ports: ["8081:8081"]
volumes: { pgdata: {}, miniodata: {} }
```

### `.env.example`
```
DATABASE_URL=postgres://beak:beak@localhost:5432/beak
BEAK_STORAGE_DRIVER=s3
BEAK_S3_ENDPOINT=http://localhost:9000
BEAK_S3_BUCKET=beak-uploads
BEAK_S3_ACCESS_KEY=beak
BEAK_S3_SECRET_KEY=beaksecret
BEAK_S3_REGION=us-east-1
BEAK_S3_USE_PATH_STYLE=true
BEAK_AUTH_SECRET=change-me-in-prod
```
`.gitignore` must ignore `.env`, `coverage/`, `.dart_tool/`, `build/`, `BUILD_COMPLETE`,
`NEEDS_HUMAN.md`, `build.log`.

### Package skeletons
Each package: a `pubspec.yaml` (path deps as per CLAUDE.md repo map), a `lib/<name>.dart`
barrel exporting a `const String beak<Name>Version = '0.0.1';`, and a
`test/smoke_test.dart` asserting the version constant. This guarantees the gate is green
from Phase 0 so later phases only ever see regressions they caused.

`tool/check_coverage.dart`: parse each package's `coverage/lcov.info`, compute line %,
fail (exit 1) if any package with a `test/` dir is below its threshold (map of
package→threshold; default 85, `beak_core` 100 once it has code — start at 0 so empty
skeletons pass, raise per phase).

## Tests to write FIRST
- `smoke_test.dart` in every package (version constant).
- `tool/` self-check: a tiny test that `check_coverage.dart` fails a synthetic
  below-threshold lcov and passes an above-threshold one.

## Definition of Done (gate)
- [ ] `melos bootstrap` succeeds; all path deps resolve.
- [ ] `melos run analyze` (and flutter analyze) → 0 issues across all packages.
- [ ] `melos run format-check` → clean.
- [ ] `melos run test` (+ flutter) → all smoke tests green.
- [ ] `melos run coverage` → passes (thresholds set so empty skeletons pass).
- [ ] `docker compose up -d --wait` brings Postgres + MinIO healthy; `melos run down` works.
- [ ] Material-import guard is wired and green.
- [ ] `PLAN/STATE.md` row 00 → `✅ DONE` with SHA.

## Commit
`chore(repo): scaffold Beak monorepo, tooling, docker services and guardrails`
