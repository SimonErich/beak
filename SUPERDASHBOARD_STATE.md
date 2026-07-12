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
- **obers_ui** (committed + pushed to `SimonErich/obers_ui`) — five generic
  widgets: `OiVectorMap` (+ bundled world data), `OiTileMap` (raster slippy
  map), `OiCarousel`, `OiRadialSlider`, and `OiAuthMode.lock`. Design record:
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
- **Maps & advanced charts** — a `/maps` page pairs the vector choropleth
  with a real OSM **tile map** (`OiTileMap`, offices pinned by lat/lng); the
  charts gallery adds **bubble** (catalog price × stock), **candlestick** (a
  seeded 30-day OHLC series), and a **heatmap** (orders by weekday × month).
- **Shell power-ups** — a Ctrl/⌘-K command bar (jump to any resource/page), a
  notification bell (unread badge + mark-as-read over the seeded notifications),
  radar & funnel added to the charts gallery, a data-bound video player, and
  session idle-lock (auto-locks to `/lock` after 10 min; reachable anytime).
- **Structured forms = structured detail** — Product and Order share one
  block layout for the show page *and* the create/edit form (dual-mode blocks:
  values on one, inputs on the other), so the form has the same cards/tabs
  structure as the detail. Both are enriched with real sub-entities — Product
  gains variants, a gallery, reviews, and price rules; Order gains a lifecycle
  history and internal comments — each a tab of an inline, bounded relation
  manager (46 models total).
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
  The suite targets a dedicated `beak_e2e` database (created on demand), so
  running the app tests never touches the seeded demo data in `beak`.

## Running it
```bash
melos run up                          # Postgres + MinIO
cd apps/beak_superdashboard
dart run bin/worm.dart migrate        # create the 46-table schema
dart run bin/worm.dart db:seed        # seed all 12 domains
dart run bin/server.dart              # backend on :8180 (PORT in .env)
flutter run                           # the panel
```

## Remaining Tocly parity gaps
None. Every earlier deferral has since landed: radar/funnel + bubble/
candlestick/heatmap chart families, the raster tile map (`OiTileMap` +
`BeakTileMapBlock` + `/maps`), session idle-lock, the command bar, and the
notification center. The `*_MISSING_FEATURES.md` records track what lives
where.

## Publication state
- **obers_ui** — the five widgets (`OiVectorMap`, `OiTileMap`, `OiCarousel`,
  `OiRadialSlider`, `OiAuthMode.lock`) are committed and pushed to
  `SimonErich/obers_ui` `main`, together with a fix dropping the broken
  `win32: 6.0.0` override (file_picker 11 targets the win32 5.x API).
- **beak** — pushed to `SimonErich/beak` (private); PR #1 tracks
  `feat/superdashboard` → `main`.
- **Known caveat** — beak references obers_ui by local path
  (`~/Flutters/obers_ui`), so a fresh clone needs the two repos checked out
  side by side; GitHub CI would need a two-repo checkout or a git dependency.
