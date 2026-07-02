# Phase 12 — beak_frontend: BeakDataTable (columns → OiTable)

## Objective
Render a model's list view automatically: map its `BeakColumn`s (table context) to an
`OiTable`, with server-side sort/filter/pagination driven by `BeakQuerySpec`, bulk +
per-row actions, and inline edit — no hand-written table code per resource.

## Prerequisites
- Phase 11 `✅ DONE`.

## Files created (in `packages/beak_frontend/lib/src/table/`)
- `beak_data_table.dart`
- `column_cell_renderer.dart` (BeakRenderIntent → obers_ui cell widget)
- `table_view_model.dart` (Signals; owns query spec + page state)
- barrel updates

## Public API to implement (contract)
```dart
class BeakDataTable extends HookWidget {
  const BeakDataTable({super.key, required this.model, required this.dataSource,
      this.actions = const [], this.bulkActions = const [], this.onRowTap,
      this.initialSpec});
  final BeakModel model; final BeakDataSource dataSource; ...
}
```
Behavior:
- Columns: for each `model.columns` visible in `BeakContext.table`, build an
  `OiTableColumn` whose `cellBuilder` uses `column_cell_renderer.dart` to render by
  `column.intentFor(BeakContext.table)`:
  text→`OiLabel`, number/currency→formatted `OiLabel`, badge(enum)→`OiBadge` colored via
  `BeakColor`, boolean→check/`OiBadge`, date/relativeDate→formatted, thumbnail(image)→
  small `OiImage`/avatar, relationLink→tappable `OiLabel` navigating to the related show
  route, relationBadges→wrap of `OiBadge`, color→swatch, custom→delegate to the column's
  registered builder. Exhaustive `switch` over `BeakRenderIntent` (compile-guarded).
- Server-side ops: set `serverSideSort/Filter: true`; `onSort`/`onFilter`/pagination
  callbacks update the `TableViewModel`'s `BeakQuerySpec` and refetch via
  `dataSource.query(spec)`. `paginationMode: pages`, `totalRows` from `BeakPage.total`.
- Loading/empty: `loading` bound to the view model's signal; `emptyState` an `OiEmptyState`.
- Row/bulk actions: render as `OiButton`/menu; bulk actions operate on selected `rowKey`s;
  destructive actions go through `BeakOptimistic` (optimistic + undo).
- Inline edit: for columns that allow it, wire `onCellChanged` → `dataSource.update`
  (optimistic), reverting on failure.

### View model
```dart
final class TableViewModel {
  TableViewModel(this.model, this.dataSource, {BeakQuerySpec? initial});
  ReadonlySignal<BeakPage<BeakRecord>?> get page;
  ReadonlySignal<bool> get loading;
  ReadonlySignal<BeakException?> get error;
  void sortBy(BeakColumn c, {bool descending});
  void setFilter(BeakFilter? f);
  void setSearch(String term);
  void goToPage(int page);
  Future<void> refresh();
}
```
Repository is the catch boundary; the view model exposes error state, never `try/catch`.

## Tests to write FIRST
- `column_cell_renderer_test.dart` (widget) — each `BeakRenderIntent` renders the expected
  obers_ui widget with correctly formatted content; enum badges use the right `BeakColor`;
  relationLink is tappable; **no Material** widget appears.
- `beak_data_table_test.dart` (widget) — with a fake data source returning a `BeakPage`:
  - correct columns/rows render;
  - tapping a sortable header updates the emitted `BeakQuerySpec` (assert the spec sent to
    the fake source has the expected `BeakSort`) and refetches;
  - pagination controls change `page` and refetch with the right `BeakPagination`;
  - a bulk action runs against selected rows;
  - a destructive row action triggers optimistic removal + undo;
  - loading and empty states render.
- `table_view_model_test.dart` — sort/filter/search/paginate produce the right specs;
  error surfaces as state.

## Implementation notes / constraints
- All state via Signals; `HookWidget`; zero Material.
- The renderer is the single place intents become widgets — reused by detail view later.
- Formatting (currency prefix, date format) comes from the column config, not hard-coded.

## Definition of Done (gate)
- [ ] `flutter analyze` 0 · `flutter test` green · coverage ≥ 85% · format clean · Material ban green.
- [ ] Exhaustive intent→widget switch tested.
- [ ] Server-side sort/filter/paginate proven by asserting emitted `BeakQuerySpec`s.
- [ ] STATE.md row 12 → `✅ DONE` + SHA.

## Commit
`feat(beak_frontend): add BeakDataTable with server-side ops, actions and inline edit`
