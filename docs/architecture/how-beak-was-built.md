---
title: How Beak was built
description: The bottom-up, test-first, one-green-gate-per-phase build, and the superdashboard expansion that fed features back into the framework.
---

# How Beak was built

After this page you can describe how Beak went from an empty folder to a working framework: sixteen phases, each gated green and committed once, built bottom-up and test-first, then stretched by a second demo app that pushed reusable features back into the framework.

Beak was not written all at once. It was built as an ordered sequence of self-contained phases, each of which had to pass the same gate before it counted as done. The rule was strict: do the first phase that is not finished, drive its gate to green, record the commit, stop. Then start again on the next one. That discipline is why the architecture invariants documented across this section held all the way through.

The plan and ledger that drove the build live in `PLAN/PHASES.md` and `PLAN/STATE.md`; the second-app expansion is recorded in `SUPERDASHBOARD_STATE.md` and `BEAK_MISSING_FEATURES.md`.

## The method

Every phase followed one loop: load only that phase's spec, write tests, make them pass, run the full gate, commit once with a conventional message, and record the short SHA in the ledger. No phase was marked done until the gate was fully green, and no work spilled across phases.

The gate was the same for all sixteen phases:

```text title="PLAN/PHASES.md"
`melos run analyze` = 0 issues · `melos run test` = all green, no skips ·
`melos run coverage` ≥ 85% (100% target for `beak_core`) · `melos run format-check` =
clean · plus the phase's own proofs · `STATE.md` updated · one conventional commit.
```

The "phase's own proofs" were extra, phase-specific evidence: a golden serialization file pinned byte-exact, a server that binds a real socket at boot, a live end-to-end run. A phase that analyzed clean but had no proof did not pass.

## Bottom-up dependency order

The build went from the foundation up, never the reverse. Pure-Dart `beak_core` came first, because everything depends on it; the ORM-backed backend and the Flutter panel came later, because they depend on the shared contract; the store example came last, because it depends on all of it.

```text title="PLAN/PHASES.md"
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

The query spec at phase 04 is the hinge of the diagram. Both the backend (phase 07) and the frontend (phase 11) depend on it, because it is the contract they speak across the wire. Building it before either side is what let the two halves stay decoupled.

## The sixteen phases

Each row landed as one gated commit. The ledger in `PLAN/STATE.md` records the SHA and a dense note for every one.

| # | Phase | Commit | What landed |
| --- | --- | --- | --- |
| 00 | Foundation & guardrails | `d2f4d96` | Melos monorepo, Docker (Postgres + MinIO), CI, strict analysis, gate scripts. |
| 01 | core: types, enums, errors | `4367f33` | `BeakContext`, `BeakOperator`, sealed `BeakException`, `BeakResult`. 100% tested. |
| 02 | core: columns + rules | `22f57af` | Sealed `BeakColumn` (13 kinds), `BeakRule` (11), per-context render intents. |
| 03 | core: model + relations | `097204c` | `BeakModel`, sealed `BeakRelationship`, the model registry. |
| 04 | core: serializable query spec | `22cb8cc` | `BeakQuerySpec`, `BeakValue`, `BeakFilter`; golden serialization pinned. |
| 05 | core: storage abstraction | `edab92e` | Driver interface, sealed config, file rules, transform spec, memory + local drivers. |
| 06 | storage drivers | `3244201` | `beak_storage_s3`, `beak_storage_ftp`, `beak_image` transform runner. |
| 07 | backend: Shelf + data source | `e222158` | Server, middleware, `WormDataSource`, `WormQueryTranslator`, env config. |
| 08 | backend: auto CRUD | `8137ec3` | Generated CRUD/query/batch/relations, validation, soft delete. |
| 09 | backend: uploads | `6e6e65c` | Upload endpoints: validate, transform, store, typed `BeakStoredFile`. |
| 10 | backend: auth + search + export | `1343946` | Token/session guard, policies, global search, CSV export. |
| 11 | frontend: panel + client | `f575374` | `BeakPanel`, `BeakClient`, `HttpBeakDataSource`, DI + routing + Signals. |
| 12 | frontend: BeakDataTable | `7872370` | Cell renderer, server-side sort/filter/paginate, row and bulk actions. |
| 13 | frontend: form + detail | `1dd901d` | `BeakDataForm`, `BeakFormController`, `BeakDetailView`, relation fields. |
| 14 | frontend: actions + dashboard | `2f80ed2` | Actions, filters, dashboard stats and charts; aggregates end-to-end. |
| 15 | reference app + CLI + E2E | `6367c47` | The store trio, `beak_cli`, a live Postgres + MinIO E2E run. |

Phase 15 ended at a `BUILD_COMPLETE` sentinel: the full gate green across every package, integration and end-to-end tags included, against live infrastructure.

## Test-first, and honest about it

Tests came before implementation, one behavior at a time, and the ledger notes are candid about where reality bent the plan. When a phase spec asked for something that would not compile or contradicted a guardrail, the build followed the stricter, provable path and wrote down why: a phase text calling for non-attachable relations to return `400` was implemented as `422`, because the sealed exception family fixes the status vocabulary and `422` is the more precise code; a phase asking for codegen `part` directives shipped the codegen-free canonical model shape instead, because the generated file would not compile without a codegen run, contradicting the phase's own Definition of Done.

`beak_core` carried a `100%` coverage target throughout and hit it at every addition (the ledger tracks the line counts: `925/925`, `1046/1046`, `1274/1274`). The other packages held to the `≥ 85%` floor. Coverage was a gate, not a report.

## The superdashboard expansion

The store example is a small, clean teaching store. To prove Beak scaled to a real admin panel, a second demo was built on the `feat/superdashboard` branch: `apps/superdashboard`, reproducing a full commercial admin theme entirely from seeded data using only declarative Beak widgets. It followed the same discipline, one gated commit per phase.

Its value to the framework is that most of what it needed was reusable, so it landed in the packages rather than the app. `BEAK_MISSING_FEATURES.md` is the map of what that expansion added to `beak_frontend`:

- **The declarative surface.** The sealed `BeakBlock` union and its single `BeakBlockHost` renderer, driving custom pages, resource view modes, and overlay bodies from one exhaustive switch.
- **Record-scoped detail and dual-mode forms.** `BeakRecordScope`, `BeakFieldBlock`/`BeakFieldGroupBlock`/`BeakRelationBlock`, and `BeakResource.detail`/`formLayout`, so one block tree renders a show page and a create/edit form.
- **Multi-step forms, view modes, and module blocks.** The wizard, table/calendar/kanban view modes, and nine composed module blocks (chat, inbox, file manager, invoice, and more).
- **Shell power-ups.** A command bar, a notification center, a live theme toggle, configurable auth and maintenance routes, and session idle-lock.
- **Charts and maps.** The full chart family plus bubble, candlestick, and heatmap, and both a vector choropleth and a raster tile map.

Some needs pushed further down the stack. `SUPERDASHBOARD_STATE.md` records generic work that landed in the sibling libraries: worm gained table-scoped relation resolution that fixed self-referential eager loading, and obers_ui gained five widgets (a vector map, a tile map, a carousel, a radial slider, and a lock auth mode), committed and pushed to its own repository. Each of the three `*_MISSING_FEATURES.md` files is a design record of what landed where and why.

The demo itself grew to 49 models across 12 domains, 55 tables, 11 seeders, 17 resources, and 14 custom pages, and was validated against live Postgres through an end-to-end suite covering paged queries, aggregates, eager loads, a self-referential tree, and revenue reconciliation. Both live-Postgres suites target dedicated derived databases so running the tests never touches seeded demo data.

## Hardening after the build

Finishing the build was not the end. Two rounds of adversarial multi-agent review ran over the completed code, and every confirmed finding was fixed and regression-tested.

The post-`BUILD_COMPLETE` cleanliness audit (recorded in `PLAN/STATE.md`) confirmed 28 findings: a behavioral bug where bulk actions delivered stringified row keys instead of raw primary keys, a form-eligibility duplication that could crash a build, and a batch of new shared primitives each replacing several copy-pasted sites. The superdashboard hardening rounds (in `SUPERDASHBOARD_STATE.md`) tightened data completeness (data-bound blocks now fetch explicitly-paged, deterministically-sorted data), wired interactions to actually persist, and routed every value through the shared cell formatter. After each round, the full gate ran green again.

## What the discipline bought

The invariants this section documents, the source-agnostic data seam, the ORM-neutral query contract, the exhaustive block union, the pluggable storage layer, are not aspirations bolted on afterward. They held because the gate held: analyze at zero, tests green with no skips, coverage enforced, format clean, on every single commit. A layered architecture is only as real as the check that keeps it layered, and Beak ran that check sixteen times before it called itself done, then twice more before it called itself clean.

## Continue reading

- [Principles](principles.md) the design rules the phases were built to honor.
- [Code guardrails](../contributing/code-guardrails.md) the checks that gate every change today.
- [Testing](../guides/testing.md) the test harness the phases used, from your side.
- [Writing tests](../contributing/writing-tests.md) how to add tests that hold the same line.
