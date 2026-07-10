# beak_frontend — declarative surface added for the superdashboard

Design record for the Beak-specific-but-reusable frontend APIs the demo
needed. These are reusable across **all** Beak apps (not app-specific), so
they belong in `packages/beak_frontend`. All are **built and committed** on
`feat/superdashboard`; this file is the map of what landed and where.

## The DRY core — `lib/src/blocks/`
- `BeakBlock` (sealed) + `BeakBlockHost` (one exhaustive renderer). One union
  drives custom pages, resource view-modes, and overlay bodies.
- **Layout**: column, row, grid (per-child `BeakSpan` via `OiSpan`), card,
  section, tabs, accordion, breadcrumbs (router-aware), masonry, three-pane.
- **Display leaves**: text (9 variants), image, markdown, divider, spacer,
  and `BeakWidgetBlock` (the raw-widget escape hatch).
- **UI-kit leaves**: `BeakAlertBlock` (OiBanner, four levels), `BeakBadgeBlock`
  (OiBadge), `BeakProgressBlock` (OiProgress), `BeakRatingBlock` (OiStarRating),
  and `BeakIconGalleryBlock` (a design-system icon cheat-sheet over OiIcon).
- **Data-bound**: `BeakKpiBlock` (OiKpiCard + delta), `BeakChartBlock` +
  every `BeakChartType`, `BeakTableBlock` (reuses BeakDataTable),
  `BeakMetricBlock`, `BeakMapBlock` (OiVectorMap), `BeakCarouselBlock`
  (OiCarousel), `BeakRadialSliderBlock` (OiRadialSlider), `BeakGalleryBlock`
  (OiGallery), `BeakTimelineBlock` (OiTimeline). All resolve the data source
  from DI and fetch via `BeakResourceRepository`.
- **Module blocks**: calendar, kanban, chat, inbox (composed), file-manager,
  invoice (composed), profile, pricing, faq.

## Record-scoped detail layouts — `lib/src/detail/`, `lib/src/blocks/`
- `BeakRecordScope` (InheritedWidget) carries the loaded record down to
  record-bound blocks, so a resource's `detail` layout is a `const` block tree.
- `BeakFieldBlock` (one labelled, formatted field — reuses the cell renderer),
  `BeakFieldGroupBlock` (a responsive definition grid), `BeakRelationBlock`
  (a to-many relation inline via the relation manager).
- `BeakResource.detail` — a bespoke show-page layout (cards/sections/tabs/
  grids of field + relation blocks); `null` falls back to an upgraded default
  definition grid. Replaces the old flat label→value dump.

## Structured forms via dual-mode blocks — `lib/src/form/`, `lib/src/blocks/`
- `BeakFieldBlock`/`BeakFieldGroupBlock`/`BeakRelationBlock` are dual-mode:
  inside a `BeakFormScope` they render **editable inputs** (belongs-to picker,
  upload, type-mapped field, bounded relation manager); inside a
  `BeakRecordScope` they render read-only values. So one block tree drives both
  the show page and the create/edit form.
- `BeakDataForm.layout` + `BeakResource.formLayout` render the form through a
  layout; `beakFormColumnsOf` walks it so the form registers exactly the
  columns it addresses. `BeakRelationManager` caps its list height, fixing the
  form overflow.

## Multi-step forms (wizard) — `lib/src/form/`
- `BeakFormStep {title, subtitle?, icon?, description?, columns}` +
  `BeakDataForm.steps` render the create/edit form as an `OiWizard`, reusing
  the form controller and validation; per-step gating blocks Next on an
  incomplete required step; the final step submits. `BeakResource.formSteps`
  threads it into the generated pages.

## Pages, routing, shell — `lib/src/panel/`
- `BeakScreen` — a custom non-resource page (route + nav + `BeakBlock` body,
  framed or full-bleed) on `BeakPanelConfig.pages`. A screen at `/` replaces
  the built-in dashboard.
- Resources/screens gain a nav `section`; `BeakResource.viewModes`
  (`BeakResourceView`: table/calendar/kanban) with a segmented switcher.
- `BeakAuthConfig` (login/register/recover routes), `BeakMaintenanceConfig`
  (maintenance/coming-soon), typed error routes (403/500).
- `BeakThemeController` — live light/dark/system toggle in the shell.
- Command bar (`openBeakCommandBar` / `beakNavigationCommands`, Ctrl/⌘-K) — a
  fuzzy palette over every resource/page, in the shell's Search action.
- Notifications (`BeakNotificationSource` + `BeakNotificationBell`) — a shell
  bell with an unread badge over `OiNotificationCenter`, mark-as-read writing
  back through the data source.
- Session idle-lock: `BeakAuthConfig.idleLockTimeout` locks the shell to a
  `/lock` screen (`OiAuthPage.lock`) after inactivity.

## Overlays + forms
- `BeakOverlays` (on `BeakActionContext.overlays`): `confirm`, `modal`,
  value-returning `dialog`, side `sheet` (offcanvas), `toast`. The
  action-confirmation path routes through `confirm`.
- `BeakFormStep` + `BeakWizardBlock` (OiWizard) for multi-step flows.

## Charts + media
- `BeakChartType` now covers line/area/bar/pie/donut/radar/funnel, each fed by
  the `BeakChartPoint` mapper.
- `BeakVideoBlock` (OiVideoPlayer); the gallery block already opens a lightbox
  on tap.

## Not yet added (genuinely larger — need new obers widgets or data shapes)
- **Google/tile maps**: `OiTileMap` does not exist in obers_ui; the vector
  choropleth (`OiVectorMap`/`BeakMapBlock`) is done, a slippy tile map is a
  new generic widget.
- **Multi-dimensional chart families** (bubble/candlestick/heatmap): these
  need a typed `BeakChartData` beyond the single-value `BeakChartPoint` (x/y/z,
  OHLC, matrix) — and demo data that has those shapes, which the seeded
  analytics does not.

Design note: the chat block binds a single author field by design; this demo
denormalizes `sender_name` onto `chat_messages` in the seeder rather than
teaching the generic block to join — keeping the block source-agnostic.
