# PLAN/PHASES.md — Beak build overview

Bottom-up build: an empty folder becomes the Beak framework (four packages + two driver
packages + CLI) plus a working reference admin app, fully test-driven, running against
Postgres + MinIO. Each phase is self-contained in `phase-NN.md` and ends at a green gate.

## Dependency graph

```
00 foundation
 └─ 01 core:types
     └─ 02 core:columns+rules
         └─ 03 core:model+relations
             └─ 04 core:query-spec ─────────────┐
             └─ 05 core:storage-abstraction     │
                 └─ 06 storage drivers (s3/ftp)  │
                                                 │
07 backend:shelf+datasource  ← 04, 05            │
 └─ 08 backend:CRUD          ← 07                │
     └─ 09 backend:uploads   ← 08, 06            │
         └─ 10 backend:auth+search+export ← 09   │
                                                 │
11 frontend:panel+client     ← 04 (shared spec) ─┘
 └─ 12 frontend:table        ← 11
     └─ 13 frontend:form+detail ← 12
         └─ 14 frontend:actions+filters+dashboard ← 13
             └─ 15 reference app + cli + E2E ← 10 + 14
```

## Global Definition of Done (applies to every phase)

`melos run analyze` = 0 issues · `melos run test` = all green, no skips ·
`melos run coverage` ≥ 85% (100% target for `beak_core`) · `melos run format-check` =
clean · plus the phase's own proofs · `STATE.md` updated · one conventional commit.

## Phase summaries

- **00 Foundation** — Melos monorepo, folder tree, vendored worm path deps, obers_ui
  path deps, strict `analysis_options.yaml`, `docker-compose.yml` (Postgres+MinIO+
  consoles), `.env.example`, Melos scripts (`analyze/test/coverage/format-check/up/down`),
  GitHub Actions CI, empty package skeletons that already pass the gate.
- **01 core:types** — `BeakContext`, `BeakRenderIntent`, `BeakColor`, `BeakOperator`,
  the `BeakException` hierarchy, and a `BeakResult`/failure model. Pure, 100% tested.
- **02 core:columns** — sealed `BeakColumn` + all concrete column types, the `BeakRule`
  validation classes, and per-context render-intent resolution.
- **03 core:model+relations** — `BeakModel` metadata, `BeakRelationship` types, the model
  registry, and ORM-agnostic metadata (so `beak_serverpod` can supply it later).
- **04 core:query-spec** — `BeakQuerySpec` (with/where/orderBy/search/paginate) that is
  JSON-serializable and lossless; golden serialization tests.
- **05 core:storage** — `BeakStorageDriver` interface, `BeakStorageConfig`/credentials,
  file rules (size/type/image dimensions), `BeakImageTransform` pipeline spec, plus
  in-memory + local-disk drivers.
- **06 storage drivers** — `beak_storage_s3` (MinIO-compatible) and `beak_storage_ftp`,
  with real image-transform execution; integration-tested against MinIO.
- **07 backend:foundation** — Shelf server, middleware (JSON, errors, CORS, auth hook),
  the `BeakDataSource` interface + `WormDataSource`, worm/Postgres wiring, env config.
- **08 backend:CRUD** — auto list/get/create/update/delete + query + batchGet
  (reference dedup) + relation attach/detach, server-side validation, soft delete.
- **09 backend:uploads** — upload endpoints that validate file rules, run transforms,
  store via the configured driver, and return typed `BeakStoredFile`.
- **10 backend:auth+search+export** — token/session guard + policies, global search over
  searchable columns, CSV export from a `BeakQuerySpec`.
- **11 frontend:panel** — `BeakPanel` (OiApp/OiAppShell + go_router + GetIt + Signals),
  the typed data-provider client (dedup, optimistic + undo via `OiOptimisticAction`).
- **12 frontend:table** — `BeakDataTable` mapping `BeakColumn`s → `OiTable`, server-side
  sort/filter/paginate, bulk + record actions, inline edit.
- **13 frontend:form+detail** — `BeakDataForm` generating an `OiAf` enum controller from
  columns, relationship + image/file fields, conditional visibility; `BeakDetailView`;
  relation manager.
- **14 frontend:actions+dashboard** — actions/filters system, dashboard stats + charts
  (`obers_ui_charts`), `BeakResource` → auto-generated CRUD pages in `OiResourcePage`.
- **15 reference app + cli + E2E** — Products/Users/Orders/Category/Tag models + screens,
  `beak_cli` scaffolding, and a full end-to-end run against Postgres + MinIO. Final
  acceptance gate → `BUILD_COMPLETE`.
