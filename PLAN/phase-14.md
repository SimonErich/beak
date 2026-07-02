# Phase 14 — beak_frontend: actions, filters, dashboard, resource pages

## Objective
Complete the frontend framework: a typed actions/filters system, a dashboard with stats +
charts (`obers_ui_charts`), and the `BeakResource` → auto-generated CRUD pages wired into
`OiResourcePage` and the router, so registering a resource yields full list/create/show/
edit pages with zero page code.

## Prerequisites
- Phase 13 `✅ DONE`.

## Files created (in `packages/beak_frontend/lib/src/`)
- `actions/beak_action.dart` (sealed) + `actions/*.dart`, `filters/beak_filter_widget.dart`
- `dashboard/beak_dashboard.dart`, `dashboard/beak_stat.dart`, `dashboard/beak_chart.dart`
- `pages/beak_resource_pages.dart` (list/show/create/edit page builders)
- `pages/beak_page_scaffold.dart`
- barrel updates + `beak_frontend` public API surface finalized

## Public API to implement (contract)

### Actions (typed)
```dart
sealed class BeakAction {
  const BeakAction({required this.key, required this.label, this.icon, this.color,
      this.requiresConfirmation = false});
}
// BeakRecordAction   — operates on one record: onExecute(BeakRecord, BeakActionContext)
// BeakBulkAction     — operates on selected records
// BeakGlobalAction   — page-level (e.g. "Create"), navigates or opens a form
// Built-ins: BeakEditAction, BeakDeleteAction (optimistic+undo), BeakViewAction, BeakCreateAction
final class BeakActionContext { final BeakDataSource dataSource; final GoRouter router; ... }
```
Actions render as `OiButton`s / overflow menus; confirmations use `OiDialog.confirm`;
destructive ones route through `BeakOptimistic`.

### Filters (typed, drive the query spec)
```dart
sealed class BeakFilterDef {
  const BeakFilterDef({required this.column, required this.label});
  final BeakColumn column;
}
// BeakSelectFilter (enum column -> OiSelect), BeakDateRangeFilter (-> OiDateRangePickerField),
// BeakBoolFilter (-> OiSwitch), BeakTextFilter (searchable text)
```
A `BeakFilterBar` renders the resource's filters and emits a combined `BeakFilter` into the
table's `BeakQuerySpec`. All typed; no `Map<String,dynamic>`.

### Dashboard
```dart
class BeakDashboard extends HookWidget {
  const BeakDashboard({super.key, required this.stats, required this.charts, required this.dataSource});
}
final class BeakStat {          // a metric card
  const BeakStat({required this.label, required this.aggregate, this.icon, this.color});
  final BeakAggregateSpec aggregate;   // count/sum/avg over a table (+optional filter)
}
final class BeakChart {         // wraps obers_ui_charts
  const BeakChart({required this.title, required this.type, required this.query, required this.map});
  // type: line|bar|pie|area; query: a BeakQuerySpec/aggregate producing series; map:
  // typed mapping from records/aggregates to chart series (no dynamic).
}
```
Stats call `dataSource.aggregate`; charts fetch data and render via `obers_ui_charts`
widgets. Provide `BeakStatCard` (built on `OiCard`) and chart wrappers.

### Auto CRUD pages from a resource
```dart
// beak_resource_pages.dart — given a BeakResource, build the four pages:
//   listPage  -> OiResourcePage(variant: list, filters: BeakFilterBar, child: BeakDataTable,
//                actions: [BeakCreateAction, ...resource.globalActions])
//   showPage  -> OiResourcePage(variant: show, child: BeakDetailView + relation managers,
//                actions: [BeakEditAction, BeakDeleteAction])
//   createPage-> OiResourcePage(variant: create, child: BeakDataForm(create))
//   editPage  -> OiResourcePage(variant: edit, child: BeakDataForm(edit))
// beak_router.dart (Phase 11) is updated to mount these real pages per resource.
```
After this phase, `BeakPanel(config)` with a `BeakResource` list renders a complete,
navigable admin panel end-to-end (against a data source).

## Tests to write FIRST
- `actions_test.dart` (widget) — record/bulk/global actions render and execute; delete is
  optimistic + undoable; confirmation-required actions show a dialog first.
- `filters_test.dart` (widget) — each filter type renders the right obers_ui input and
  contributes the correct `BeakFilter` to the emitted query spec; combining filters ANDs.
- `dashboard_test.dart` (widget) — stats call `aggregate` and show values; a chart renders
  from mapped data via `obers_ui_charts`; no Material.
- `beak_resource_pages_test.dart` (widget) — a `BeakResource` produces working list/show/
  create/edit pages inside `OiResourcePage`; navigation between them works; the full flow
  (list → create → save → back in list) works against a fake data source.

## Implementation notes / constraints
- `HookWidget`, Signals, GetIt, go_router, zero Material.
- Everything typed end-to-end. Reuse table (12) and form/detail (13) rather than
  re-implementing.
- Keep `beak_frontend`'s public API tidy: a user should get a full panel from
  `BeakPanel(BeakPanelConfig(resources: [BeakResource(model: ..., ...)]))`.

## Definition of Done (gate)
- [ ] `flutter analyze` 0 · `flutter test` green · coverage ≥ 85% · format clean · Material ban green.
- [ ] A `BeakResource` yields complete CRUD pages with no per-page code (proven).
- [ ] Dashboard stats + charts render from the data source.
- [ ] STATE.md row 14 → `✅ DONE` + SHA. Frontend framework feature-complete.

## Commit
`feat(beak_frontend): add actions, filters, dashboard and auto-generated resource pages`
