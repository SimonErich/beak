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
  dashboard at `/` (KPIs, sales chart, source donut, world map, tables); plus
  **14 custom pages** — email, chat, file-manager, invoice-detail, profile,
  pricing, FAQ, and a **Showcase** section (charts gallery, media
  gallery/carousel, UI-elements, typography, icons, starter).
- **Structured detail screens** — every resource has a bespoke show-page
  layout (headline card + two-column attribute groups + tabbed/inline
  relations) via the new record-scoped `BeakFieldBlock`/`BeakFieldGroupBlock`/
  `BeakRelationBlock` + `BeakResource.detail`; simple resources get an upgraded
  responsive definition-grid default.
- **A stepped create wizard** — Calendar Events opts into `formSteps`, so its
  create/edit form is a four-step `OiWizard` (Details → Schedule → Place →
  Organize) spanning the widest input variety in the app, with per-step
  validation.
- **Validated on live Postgres** via an E2E suite (paged queries, aggregates,
  eager loads, a self-referential folder tree, revenue reconciliation, CRUD).
  Note: this suite runs `MigrationRunner.fresh()` against the dev Postgres, so
  running the app tests **replaces** the seeded demo data — re-run
  `dart run bin/worm.dart migrate && db:seed` afterward to restore it.

## Running it
```bash
melos run up                          # Postgres + MinIO
cd apps/beak_superdashboard
dart run bin/worm.dart migrate        # create the 46-table schema
dart run bin/worm.dart db:seed        # seed all 12 domains
dart run bin/server.dart              # backend on :8080
flutter run                           # the panel
```

## Remaining Tocly parity gaps (deliberately out of scope, documented here)
These need framework work that isn't Beak- or app-specific enough to justify
building now; each is recorded in the matching `*_MISSING_FEATURES.md`.
- **Chart families beyond the five** (line/area/bar/pie/donut are done):
  column/radialBar/radar/scatter/bubble/heatmap/candlestick etc. would extend
  `BeakChartType` + the obers_ui_charts render switch — a generic
  `beak_frontend`/`obers_ui_charts` change, not app work.
- **Google/tile maps** (the vector world map is done) — a second obers_ui
  widget (`OiTileMap`) behind `BeakMapBlock.tile`.
- **Session-timeout / idle-lock** capability — a small `beak_frontend`
  idle-timer wired to `OiAuthMode.lock` + `BeakConfirm`.
- **Rich-text / advanced form plugins gallery** — the resource create/edit
  forms already demonstrate every column type, validation, and the wizard;
  a standalone "form plugins" page adds no framework capability.

## Action required from you
The four **obers_ui** widgets are built and green in `~/Flutters/obers_ui`
but **uncommitted** — that repo has ~54 unrelated in-flight doc edits, so I
committed nothing there. Commit my code files to make `flutter run`/CI
reproducible on a clean checkout (`OBERS_MISSING_FEATURES.md` documents each).
The additions, cleanly separable from your doc churn:

```
# new files
lib/src/components/display/oi_carousel.dart
lib/src/components/inputs/oi_radial_slider.dart
packages/obers_ui_charts/lib/src/composites/oi_vector_map/
test/src/components/display/oi_carousel_test.dart
test/src/components/inputs/oi_radial_slider_test.dart
packages/obers_ui_charts/test/src/composites/oi_vector_map_test.dart
# modified (barrel exports + auth lock-mode)
lib/obers_ui.dart
lib/src/modules/oi_auth_page.dart
test/src/modules/oi_auth_page_test.dart
packages/obers_ui_charts/lib/obers_ui_charts.dart
```
