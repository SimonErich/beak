# CLAUDE.md — Beak build guardrails (read this every invocation)

Beak is a **low-code, configuration-driven admin-panel framework** for Dart/Flutter.
Developers define **models once** (fields, validation, relationships, storage) and
then compose **obers_ui-style widgets** that auto-wire to a Shelf backend — no
hand-written endpoints, no client/server plumbing, fully type-safe.

You are building it **autonomously, test-first, one phase at a time**. This file is
law. When in doubt, prefer the stricter reading.

---

## 1. How the build runs

- Work is split into `PLAN/phase-00.md … phase-15.md`. `PLAN/STATE.md` is the ledger.
- Each invocation: do the **first phase not marked `✅ DONE`**, gate it green, mark it
  done, commit, stop. The harness relaunches you for the next phase.
- Load **only the current phase file** into context (plus files it names). Never read
  all phases at once.
- Never ask the user anything. Never stop for approval. Fix your own red gates.

## 2. Absolute rules (violations are blocking defects)

### 2.1 UI — obers_ui only, zero Material
- **Forbidden imports:** `package:flutter/material.dart`, `package:flutter/cupertino.dart`.
  Flutter's `widgets.dart`/`foundation.dart` are allowed only for core types
  (`BuildContext`, `Widget`, `Key`, `ValueChanged`, `EdgeInsets`, `Color`, etc.) —
  never for Material/Cupertino components.
- Use `obers_ui` (barrel: `package:obers_ui/obers_ui.dart`), `obers_ui_autoforms`
  (`OiAf*`, prefix), and `obers_ui_charts` for everything visual.
- Layout with `OiApp`, `OiAppShell`, `OiResourcePage`, `OiPage`, `OiColumn`, `OiRow`,
  `OiCard`, `OiTable`/`OiDataGrid`, `OiDetailView`, `OiForm`/`OiAfForm`, etc.
- **State = Signals** (`ReadonlySignal` out of view models). **DI = GetIt.**
  **Routing = go_router.** **Widgets = `HookWidget`; `StatefulWidget` is forbidden.**

### 2.2 Types — no escape hatches
- No `dynamic` (interop only, with a `// interop:` comment). No `as` casts — use
  pattern matching / typed APIs. No `Map<String, dynamic>` as a domain, presentation,
  or public API type — use typed DTOs / sealed classes / generics / enums.
- Prefer enums/sealed classes over strings for any known value set.
- Numeric fields carry units in the name (`maxSizeInBytes`, `timeoutInSeconds`).
- Public APIs: `type_annotate_public_apis`, `always_declare_return_types`. No null
  fallback sentinels (`"unknown"`); use `null` or empty.
- **Beak's promise:** users never write a string field reference and never touch
  `dynamic`. If an API you add would force a user to, redesign it.

### 2.3 Data — worm
- Every worm model: `final class X extends Model`, overrides `String get tableName`,
  overrides `Object get id` and `Map<String,Object?> toRow()`, declares
  `static QueryBuilder<X> query()`, and (if using codegen) `part 'x.g.dart';`.
- Migrations are explicit and registered in `bin/worm.dart`; never auto-applied.
- **No lazy loading** — eager-load relations with `withRelations([...])`; reading an
  unloaded relation throws. Design accordingly.
- Tests: one fresh `InMemoryAdapter` per test, schema up front, `tearDown(Worm.reset)`.
  Use `SqliteAdapter.memory()` only when raw SQL is needed.

### 2.4 Architecture — layered, source-agnostic
- **beak_backend flow:** `Handler (Shelf) → Service → DataSource`. The Handler is the
  catch boundary and maps typed exceptions to HTTP/JSON. Services hold logic and throw
  typed exceptions. DataSources do raw I/O only and let exceptions propagate.
- **beak_frontend flow:** `Widget → ViewModel → Repository → DataSource
  (HTTP client)`. Widgets render state + forward intent; ViewModels expose
  `ReadonlySignal` and never `try/catch`; Repository is the catch boundary.
- **Source-agnostic data:** `BeakDataSource` is an interface. `WormDataSource` is the
  default implementation. A future `beak_serverpod` will add a `ServerpodDataSource`
  **without changing beak_core or beak_backend**. Keep that seam clean.

### 2.5 Reuse-first & cleanliness
- Search the repo before adding any widget/util/mapper/type; extend rather than fork.
- `const` and `final` by default. Small, single-responsibility units. No dead code,
  no TODOs left in committed code, no commented-out blocks.
- Every public symbol has a doc comment. No `print` — use the project logger.

## 3. Repository layout (target)

```
beak/                         # repo root (this folder)
  melos.yaml                  # Melos monorepo config
  pubspec.yaml                # workspace root
  analysis_options.yaml       # strict, shared
  docker-compose.yml          # postgres + minio + consoles
  CLAUDE.md  PROMPT.md  run_beak_build.sh
  .claude/skills/*            # worm-usage, obers-ui-usage, beak-conventions, tdd-loop
  PLAN/                       # phase files + STATE.md
  packages/
    worm/  worm_postgres/  worm_generator/  worm_lints/ ...   # VENDORED (given)
    beak_core/              # pure Dart: columns, relations, query spec, storage abstraction
    beak_storage_s3/        # S3/MinIO storage driver
    beak_storage_ftp/       # FTP storage driver
    beak_backend/           # Shelf server: auto CRUD, uploads, auth, search, export
    beak_frontend/          # Flutter: panel, table, form, detail, actions, dashboard
    beak_cli/               # scaffolding CLI (make:resource, etc.)
  apps/
    reference_admin/         # the demo admin app (Products/Users/Orders/Category/Tag)
    reference_admin_server/  # the demo Shelf server bin using beak_backend
```
- `obers_ui`, `obers_ui_autoforms`, `obers_ui_charts` are referenced by **path** from
  `~/Flutters/obers_ui` (see each pubspec). Their docs live at `~/Flutters/obers_ui/doc`.
- `worm` and its drivers live under `packages/worm/*` (vendored).

## 4. The gate (Definition of Done) — every phase must pass ALL

Run from repo root. Melos scripts are defined in `melos.yaml` (Phase 0 creates them):

```bash
melos run analyze     # dart/flutter analyze across all packages → MUST be 0 issues
melos run test        # all package tests → MUST be all-green, no skips
melos run coverage    # enforce per-package line-coverage threshold (default ≥ 85%)
melos run format-check # dart format --set-exit-if-changed → MUST be clean
```

Plus each phase's own proofs (golden serialization, boot check, E2E, etc.) listed in
its file. Do not mark a phase done until `analyze`, `test`, `coverage`, `format-check`,
and the phase proofs are all green.

## 5. Commits

- One commit per phase (squash intra-phase WIP before the final commit is fine).
- Conventional Commits: `feat(beak_core): add typed column system` etc. Use the exact
  message the phase file specifies.
- After committing, record the short SHA next to the phase in `PLAN/STATE.md`.

## 6. Skills available (`.claude/skills/`)

- **worm-usage** — the exact worm APIs, gotchas, and test harness. Consult before
  writing any model/query/migration/seeder/factory.
- **obers-ui-usage** — which obers_ui / obers_ui_autoforms / obers_ui_charts widgets to
  use and how; the no-Material rule; how to read `~/Flutters/obers_ui/doc`.
- **beak-conventions** — Beak's own API design rules (column types, source-agnostic
  data, storage drivers, the type-safety promise).
- **tdd-loop** — the red/green/refactor workflow and how to structure tests per package.

Read the relevant skill(s) at the start of a phase rather than guessing.

## 7. Environment notes

- Dart `^3.11`, Flutter stable. Melos for orchestration.
- Postgres + MinIO come from `docker-compose.yml`. Backend/integration tests that need
  them assume `docker compose up -d` has been run; Phase 0 provides a `melos run up`
  helper and phases that need services call it (and gate on health) themselves.
- Never commit secrets. Local dev credentials live in `.env` (git-ignored); an
  `.env.example` is committed.
