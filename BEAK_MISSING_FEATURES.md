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
- **Data-bound**: `BeakKpiBlock` (OiKpiCard + delta), `BeakChartBlock` +
  every `BeakChartType`, `BeakTableBlock` (reuses BeakDataTable),
  `BeakMetricBlock`, `BeakMapBlock` (OiVectorMap), `BeakCarouselBlock`
  (OiCarousel), `BeakRadialSliderBlock` (OiRadialSlider). All resolve the
  data source from DI and fetch via `BeakResourceRepository`.
- **Module blocks**: calendar, kanban, chat, inbox (composed), file-manager,
  invoice (composed), profile, pricing, faq.

## Pages, routing, shell — `lib/src/panel/`
- `BeakScreen` — a custom non-resource page (route + nav + `BeakBlock` body,
  framed or full-bleed) on `BeakPanelConfig.pages`. A screen at `/` replaces
  the built-in dashboard.
- Resources/screens gain a nav `section`; `BeakResource.viewModes`
  (`BeakResourceView`: table/calendar/kanban) with a segmented switcher.
- `BeakAuthConfig` (login/register/recover routes), `BeakMaintenanceConfig`
  (maintenance/coming-soon), typed error routes (403/500).
- `BeakThemeController` — live light/dark/system toggle in the shell.

## Overlays + forms
- `BeakOverlays` (on `BeakActionContext.overlays`): `confirm`, `modal`,
  value-returning `dialog`, side `sheet` (offcanvas), `toast`. The
  action-confirmation path routes through `confirm`.
- `BeakFormStep` + `BeakWizardBlock` (OiWizard) for multi-step flows.

## Not yet added (would live here)
- UI-kit leaf blocks for alerts/badges/progress/rating/gallery/lightbox/video
  (the obers widgets exist; thin Beak wrappers would complete the showcase).
- A `BeakCommandBar` (OiCommandBar) and `BeakNotificationSource`
  (OiNotificationCenter) — deferred from Phase 7.
- Chat sender-name binding (currently binds a single author field) and a
  file-manager block that spans a folder table + file table.
