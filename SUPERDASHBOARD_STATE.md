# beak_superdashboard — build ledger

A single-package Beak demo (`apps/beak_superdashboard`) that reproduces the
Tocly admin theme **featurewise, entirely from seeded data**, using only
declarative Beak widgets. Built on the `feat/superdashboard` branch, one
gated commit per phase.

## What was built (all gated: analyze 0 issues · tests green · coverage ≥ 85% · format clean)

### Generic framework work (reusable beyond this demo)
- **worm** — richer seedable `FakerService` (+ `uuid()` minter, exposed
  `Random`, unique emails); **table-scoped relation resolution** fixing
  self-referential eager loading (folders/replies) at both worm and
  `beak_backend` layers. Design record: `WORM_MISSING_FEATURES.md`.
- **obers_ui** (built directly, **uncommitted** in `~/Flutters/obers_ui`) —
  four generic widgets: `OiVectorMap` (+ bundled world data), `OiCarousel`,
  `OiRadialSlider`, and `OiAuthMode.lock`. Design record:
  `OBERS_MISSING_FEATURES.md`.
- **beak_frontend** — the declarative surface: sealed `BeakBlock` union +
  `BeakBlockHost` (layout + display + data-bound + module blocks), custom
  `BeakScreen` pages, nav sections, config-driven auth/error/maintenance
  routes, live theme toggle, rich dashboard blocks (KPI/chart/table/metric/
  **map**/carousel/radial), full chart family, overlays (`BeakOverlays`:
  confirm/modal/dialog/sheet/toast), multi-step wizard, resource view-modes
  (table/calendar/kanban), and nine module blocks (calendar/kanban/chat/
  inbox/file-manager/invoice/profile/pricing/faq). Design record:
  `BEAK_MISSING_FEATURES.md`.

### The app
- **Models** — 40 `BeakModel`s across 12 domains over a DRY shared spine.
- **Migrations** — 46 tables via a parity-guaranteeing `defineModelColumns`
  helper; FK constraints, self-referential FKs, indexes, pivots.
- **Seeders** — 10 coherent domain seeders (analytics rolled up from the
  exact seeded orders; folder-unread and last-message counts derived);
  byte-identical reproducibility.
- **Server** — `bin/server.dart` (auto CRUD/relations/aggregate/search/
  upload/export for all models), `bin/worm.dart` (migrate/seed CLI).
- **Panel** — 17 resources grouped into Store/People/Projects/Content
  sections with filters + kanban/calendar view-modes; a custom analytics
  dashboard at `/` (KPIs, sales chart, source donut, world map, tables); and
  email / profile / pricing / FAQ app pages.
- **Validated on live Postgres** via an E2E suite (paged queries, aggregates,
  eager loads, a self-referential folder tree, revenue reconciliation, CRUD).

## Running it
```bash
melos run up                          # Postgres + MinIO
cd apps/beak_superdashboard
dart run bin/worm.dart migrate        # create the 46-table schema
dart run bin/worm.dart db:seed        # seed all 12 domains
dart run bin/server.dart              # backend on :8080
flutter run                           # the panel
```

## Not yet built (candidates for a follow-up session)
- Dedicated **chat** and **file-manager** pages (the module blocks exist;
  chat needs a sender-name binding, file-manager assumes a single
  folder/file table vs. this schema's split).
- A **UI-kit showcase** section (alerts/buttons/badges/progress/rating/
  gallery/lightbox/video/carousel/radial-slider demos), **icon galleries**,
  a **forms/charts gallery**, and a **layout/theme variant switcher**.
- Dedicated **starter / terms / coming-soon / lock-screen** content pages
  (auth + maintenance routes already exist via config).

## Action required from you
The four **obers_ui** widgets are built and green in `~/Flutters/obers_ui`
but **uncommitted** (that repo has unrelated in-flight doc edits, so nothing
there was committed). Commit them there to make `flutter run`/CI reproducible
on a clean checkout. `OBERS_MISSING_FEATURES.md` documents each.
