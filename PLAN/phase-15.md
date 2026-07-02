# Phase 15 — reference app + beak_cli + end-to-end acceptance

## Objective
Prove the whole framework works together: build a real reference admin app (models +
panel), add the `beak_cli` scaffolding tool, and run a full end-to-end test against live
Postgres + MinIO. On success, create `BUILD_COMPLETE`.

## Prerequisites
- Phases 10 (backend complete) and 14 (frontend complete) `✅ DONE`. Docker up.

## Part A — `beak_cli`
Files in `packages/beak_cli/`:
- `bin/beak.dart`, `lib/src/commands/*.dart` (built on `args`/`command_runner`).
Commands (each scaffolds clean, gate-passing code):
- `beak make:resource <Name> [--fields ...]` — generates: a worm model
  (`packages/.../models/<name>.dart` with `tableName`, `static query()`, `part 'x.g.dart'`),
  a matching worm migration + registration snippet, a Beak `XxxColumns` class + `XxxModel
  extends BeakModel`, and a `BeakResource` registration stub. Follows every convention in
  CLAUDE.md.
- `beak make:model`, `beak make:columns`, `beak make:migration` — narrower generators.
- `beak doctor` — checks worm/obers_ui paths, docker services, env.
Tests: golden-file tests that generated output matches expected templates AND that a
generated resource, once registered, compiles + passes analyze (spin a temp package or
assert against a fixture).

## Part B — reference app
- `apps/reference_admin_server/` (Dart, uses `beak_backend`):
  - worm models: `Product`, `Category`, `Tag`, `User`, `Order` (+ `OrderItem` pivot as
    needed). Relations: Product belongsTo Category; Product belongsToMany Tag; Order
    belongsTo User; Order hasMany OrderItem; etc. Full canonical worm model shape.
  - migrations for all tables (registered in `bin/worm.dart`), seeders (realistic sample
    data via factories + `Worm.seedRandom`), and Beak `*Columns` + `*Model` definitions.
  - `bin/server.dart`: load env, init worm/Postgres, register models in a
    `BeakModelRegistry`, resolve storage (S3/MinIO from env), start `BeakServer`.
  - Product has a `BeakImageColumn` (`storagePath: 'products'`, max 5 MB, jpg/png/webp,
    a `thumbnail` transform + a `webp` transform) to exercise the full upload+transform path.
- `apps/reference_admin/` (Flutter, uses `beak_frontend`):
  - `main.dart`: `runApp(BeakPanel(BeakPanelConfig(title: 'Beak Admin', apiBaseUrl: ...,
    resources: [BeakResource(model: ProductModel(), icon: ...), ...])))`.
  - A dashboard (a couple of `BeakStat`s + one `BeakChart`), a couple of custom actions
    and filters, to demonstrate the escape hatches.
  - Zero Material. Boots to a login (`OiAuthPage`) then the panel.

## Part C — end-to-end acceptance (tagged `e2e`)
`apps/reference_admin_server/test/e2e/full_flow_test.dart` (and/or a top-level
`test/e2e/`):
1. `melos run up` (Postgres + MinIO healthy).
2. Run migrations + seeders against Postgres via the server's `bin/worm.dart`.
3. Start `BeakServer` on a test port.
4. Using `BeakClient` (the real frontend client) against the running server, exercise:
   - `query` Products (paged, sorted, searched, with Category + Tags eager-loaded → assert
     reference dedup: bounded query count server-side);
   - `create` a Product (valid) → 201; invalid → 422 with field errors;
   - `upload` a real PNG to the Product image column → stored in MinIO, thumbnail variant
     retrievable via the returned url;
   - `update`, soft-`delete`, then `query` hides it; `force` delete removes it;
   - attach/detach Tags; global `search`; CSV `export`.
5. Tear down (`melos run down`).
This is the definitive proof the framework works out of the box.

## Part D — docs
- Root `README.md` for the built project: quickstart (docker up, migrate, run server, run
  app), how to define a resource, how to configure storage drivers + file rules, how the
  `beak_serverpod` seam will work. `apps/reference_admin/README.md` with run steps.

## Tests to write FIRST
- CLI golden/compile tests (Part A) before implementing generators.
- Reference worm models: unit tests (canonical shape, relations eager-load, migrations
  apply on `InMemoryAdapter`).
- The E2E flow (Part C) authored as the acceptance spec, then made green.

## Definition of Done (gate) — the final gate
- [ ] `melos run analyze` (+flutter) 0 issues across the ENTIRE repo.
- [ ] `melos run test` (+flutter) all green, no skips, including integration + e2e tags.
- [ ] `melos run coverage` meets every package threshold.
- [ ] `melos run format-check` clean.
- [ ] `beak make:resource Widget` generates code that compiles and passes analyze.
- [ ] The E2E flow passes against live Postgres + MinIO (CRUD + upload + transform +
      relations + search + export all proven).
- [ ] Reference Flutter app builds (`flutter build` for one target) and contains no
      Material import.
- [ ] `PLAN/STATE.md` all rows `✅ DONE`.
- [ ] **Create the `BUILD_COMPLETE` sentinel file at the repo root** and stop.

## Commit
`feat(reference): add reference admin app, beak_cli scaffolding and full E2E acceptance`
