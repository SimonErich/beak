---
title: Composed lists and query state
description: Share one typed query across preset tabs, staged filters, columns, an overview, saved views and CSV export with a BeakListDefinition.
type: guide
audience: [expert]
status: stable
---

# Composed lists and query state

A plain table is enough for a lookup list. An order desk needs more: tabs like Today and Needs attention with live counts, filters people stage before they apply them, saved combinations, an overview above the rows and a CSV of exactly what is on screen. `BeakTableScreen(definition: BeakListDefinition(...))` gives one list all of that on one shared query, and you write no fetching code and no table state.

## At a glance

| | |
| --- | --- |
| Declared on | `BeakTableScreen.definition`, a `BeakListDefinition` |
| One query | A `BeakQueryController` per list holds a serializable `BeakQueryState`. Table, tabs, drawer, overview, export and saved views all read it |
| Permanent scope | `BeakTableScreen.query`. Never serialized, never editable by the user |
| Views | `BeakQueryPreset` objects, each with an authoritative count |
| State in the address | `?list=`, base64url JSON, `version: 1` |
| Stored views | `BeakSavedViewStore.model`, backed by a model of your own |
| Export | `BeakListExport`, a server-side CSV of the whole query |
| Complete example | The Foodio order list in `examples/foodio-adminpanel/lib/resources/orders/list/` |

## Attach a definition

The screen keeps `query` as the permanent scope and adds the definition. This is the shape of Foodio's order list, in two pieces:

```dart title="examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart:composedListQuery"
```

```dart title="examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart:composedListShape"
```

Every key is in the [Reference](#reference). Two things about the start values. The list opens on `initialPreset`, sorted and paged like `query` says. When `query` is given, its page size wins over `definition.pageSize` (15), and `BeakPagination` defaults to 25, so a `query` without `.paginate(perPage: ...)` lists 25 rows.

## The shared query

`BeakQueryState` is everything a person can change on the list. It is what goes into the address bar and into a saved view.

| Field | Type | Default | Holds |
| --- | --- | --- | --- |
| `preset` | `String?` | `null` | The `key` of the selected preset. `null` is the unfiltered base view |
| `filters` | `Map<String, BeakFilter>` | `{}` | One predicate per filter, keyed by `BeakFilterDef.key` |
| `search` | `String` | `''` | The search term |
| `sorts` | `List<BeakSort>` | `[]` | Current ordering. A header click replaces it with one sort |
| `page` | `int` | `1` | One-based page |
| `perPage` | `int` | `15` | Page length, 1 to 200 (`BeakPagination.maxPerPage`), the most rows the server serves in a page |
| `visibleColumns` | `List<String>?` | `null` | Chosen column keys in order. `null` means the preset's or the list's columns |
| `showHeader` | `bool?` | `null` | Whether the overview is shown. `null` follows `headerInitiallyVisible` |

The controller derives one `BeakQuerySpec` from it: the permanent `query.filter`, the selected preset's `filter` and every effective user filter, all ANDed, then the search over the search fields, then the state's sorts and pagination. The construction is spelled out in [Queries](../reference/queries.md#how-a-list-builds-its-spec). The search fields are `BeakResource.globalSearchSources`, or the model's `searchable` columns when that list is empty.

A change of search, filter, sort, page or preset rewrites the state, the controller derives a new spec and the table fetches. Custom widgets get the controller with `BeakQueryScope.of(context)`, which throws `This surface requires a BeakQueryScope.` outside a composed list.

## Presets

A preset is a named view over the same resource. Foodio's list opens on Today and has a Needs attention tab:

```dart title="examples/foodio-adminpanel/lib/resources/orders/list/order_list_presets.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/list/order_list_presets.dart:composedListPresetToday"
```

```dart title="examples/foodio-adminpanel/lib/resources/orders/list/order_list_presets.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/list/order_list_presets.dart:composedListPresetAttention"
```

Needs attention adds a mandatory `filter`, its own quick filters, defaults, taller rows, a red count and, further down the file, its own columns.

| Field | Meaning |
| --- | --- |
| `key` | Address of the preset in URLs and saved views. Non-empty and unique within the list |
| `label` | Tab label |
| `filter` | Mandatory constraint while the preset is selected. Users cannot clear it |
| `defaults` | Suggested predicates per filter definition. A value the user sets for that filter replaces the default |
| `columns` | Alternative columns while the preset is active |
| `quickFilters` | Quick-filter chips for this preset, replacing the list's |
| `rowHeightInPixels` | Row height for this preset. `null` follows the table theme |
| `countColor` | Tone of the count label, `BeakColor.muted` by default |

Presets are objects, not strings. `initialPreset`, `BeakNavigationItem.resource(model, preset: ...)` and `BeakPresetCounts[preset]` all take the `BeakQueryPreset` itself, so a key is written once and nobody misspells it later. An `initialPreset` that is not in `presets` throws `Unknown list preset "today".` when the list is built.

`defaults` and `filter` differ on purpose. Today suggests a delivery date, and if someone picks another range, the range wins and the tab stays Today. Clearing a filter that came from `defaults` is remembered: the state stores an empty `BeakAndFilter` under that key, which survives a reload and is left out of the visible controls and of the server predicate. A `filter`, like the permanent `query`, cannot be cleared.

Selecting another preset keeps the user's explicit filters, goes back to page 1 and resets the column choice. Clear all removes filters, defaults and search, and keeps the permanent scope and the preset's `filter`.

### Counts

Each tab carries a count. A preset's count query is the permanent scope plus the preset's `filter` plus its `defaults`. It ignores the filters a person applied, the page and the search, so a tab's number is a property of the view and does not move as someone narrows the table.

`showPresetCounts` (default `true`) shows the badges. `subtitleBuilder` receives the same `BeakPresetCounts`, and `counts[preset]` answers an `int?`: `null` while a count loads and after a failed one. Show a dash for `null` and the reader never mistakes "not yet" for "zero", which is what the Foodio subtitle does with a `??` fallback. Counts load whenever `showPresetCounts` is on or a `subtitleBuilder` exists, and reload after every confirmed write to the table.

That is one count query (`perPage: 1`) per preset per refresh. Six presets, six small requests. A response that a newer refresh overtook is discarded.

## Address and bookmarks

With `persistQueryInUrl` (default `true`) the list writes its state into the address as `?list=`, using `router.replace`, so it adds no history entries and leaves other parameters such as `returnTo` alone. Opening that address restores the view, so copying the address bar shares it.

```dart title="packages/beak_frontend/lib/src/query/beak_query_controller.dart"
--8<-- "packages/beak_frontend/lib/src/query/beak_query_controller.dart:BeakQueryStateJson"
```

The value is that map as JSON, base64url encoded. The permanent `query` is not in it, so a bookmark cannot widen a list beyond its permanent scope.

Malformed state is rejected as a whole:

| Input | Result |
| --- | --- |
| More than 16384 characters | `Saved list state is too large.` |
| Not base64url JSON | `Invalid saved list state.` |
| `version` other than `1`, or no `filters` map | `Unsupported saved list state.` |
| Page or page size below 1 | `BeakPagination requires page >= 1 and perPage >= 1, got page 0, perPage 15.` |
| Page size above 200 | `Invalid list pagination.` |
| A column key the current preset does not offer | `The saved columns are no longer available.` |
| A preset key that does not exist | `Unknown list preset "x".` |

The page then shows the error with a Reset view button that removes `list` from the address. A bookmark saved before you renamed a column or removed a preset lands there once, and a reset fixes it.

## Columns

Without `columns` the list shows `BeakTableScreen.fields`, and without those the model's table columns. A `BeakTableColumn` is a composite cell: a record template with typed values, sortable by a field of the model.

```dart title="packages/beak_frontend/lib/src/presentation/beak_record_template.dart"
--8<-- "packages/beak_frontend/lib/src/presentation/beak_record_template.dart:BeakTableColumn"
```

`BeakTableColumn.field(field, {widthInPixels, minWidthInPixels, textAlign, cellPadding})` is the shorthand for one scalar field, and it is what `fields` turns into. Foodio's first column shows a reference with a placement line under it. Its Total column right-aligns money that is stored in cents:

```dart title="examples/foodio-adminpanel/lib/resources/orders/list/order_table_columns.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/list/order_table_columns.dart:composedListColumnOrder"
```

```dart title="examples/foodio-adminpanel/lib/resources/orders/list/order_table_columns.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/list/order_table_columns.dart:composedListColumnTotal"
```

`key` is the identity of the column, not a database name. It is what `visibleColumns` stores. `sortBy` must be a field of the listed model whose column says `@Column(sortable: true)`. A column without it, or with a related field, has an inert header. `BeakRecordTemplate` and `BeakValueBinding` (a field, or a pure computation over fields) carry the values, and every field a template reads is loaded with the page in the same query, so a cell never triggers a second request.

When the current preset or the list has columns, a Columns button opens a sheet where people tick the ones they want. The choice lands in `visibleColumns`, so it travels in the address and in saved views.

### Action columns

`BeakTableColumn.action` shows one existing action per row, chosen by a value of the record. Unavailable actions disappear from the row, and the column never grants permission by itself.

```dart title="examples/foodio-adminpanel/lib/resources/orders/list/order_list_presets.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/list/order_list_presets.dart:composedListActionColumn"
```

`OrderModel.nextAction` is a text column that Foodio's server-side order preparer fills with the name of the action that suits the order. The `choices` map turns each name into an existing action or model command, `fallback` covers the rest, and the button renders as the row's primary action.

## Filters and the staged drawer

`definition.filters` are the controls in the All filters drawer. Leave it empty and the list inherits `BeakResource.effectiveFilters`. Filters are staged: nothing applies until Apply, and the Apply button shows the size of the result it would produce (`Show 42 orders`, from `recordNoun`), counted by the server against the candidate state. Cancelling leaves the list untouched.

`advanced: true` on a filter moves it under More filters, laid out in `advancedFilterColumns` columns, with `advancedFilterDescription` as the hint. Quick filters are the ones people use daily, shown as chips beside the search field:

```dart title="examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart:composedListQuickFilters"
```

A chip shows its filter's value and a remove button while it is active. `quickFilterLabels` shortens the chip label and leaves the label in the drawer alone. A preset's `quickFilters` replace the list's. The search field searches the search fields listed above and can be hidden with `showSearch: false`. Every filter definition, choice presentation and range preset is in [Filter builders](../reference/filter-builders.md).

## Actions on rows and selections

`rowActions` and `bulkActions` are lists of `BeakActionPresentation`. They do not define actions. They pick existing ones (built-in, from the resource, or model commands with `BeakActionPresentation.model(...)`) and say where and how they appear.

```dart title="examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart:composedListActions"
```

An action that `rowActions` does not mention is not lost: it becomes a `column` action, available to action columns and absent from the row menu. Adjacent menu entries with different `group` values get a separator. `labelValue` computes a label from the row, and the loaded fields it depends on ride along in the page query. `selectionLabel` puts the selected count into a bulk button, `Cancel 3 orders`.

A model command in `bulkActions` (or in `bulkModelActions`) asks once, then runs record by record, each record saved on its own receipt. Failures are collected and shown together. With `export` configured, the selection bar also offers an `export` action that exports only the selected rows, and listing it in `bulkActions` places it. `floatingBulkActions: true` moves the selection bar to the bottom of the page so the rows stay where they are.

Actions themselves, and what they check, are on the [Actions](actions.md) page.

## Overview blocks

`header` and `collapsedHeader` are blocks placed between the tabs and the table. `showHeaderToggle` adds a Show charts switch to the row of tabs, so it needs at least one preset, and `headerInitiallyVisible` sets the start value. The switch changes `showHeader` in the state, so it is part of the address, and it does not touch the query.

```dart title="examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart:composedListOverview"
```

A `BeakSummaryBlock` inside them reads the list's controller. Its `scope` decides how much of it:

| `BeakSummaryScope` | Population |
| --- | --- |
| `active` (default) | Permanent scope, selected preset, user filters and search. Never the table page |
| `base` | The permanent scope only. Foodio's compact strip counts today's orders whatever tab is open |
| `standalone` | The summary's own query |

Only the summary block reads the scope. A metric, chart or table block in a header does not follow the list's filters. A widget you write can, with `BeakQueryScope.of(context)`. A failed summary shows an error with a Retry button. See [Summaries](../blocks/summaries.md).

## Saved views

A saved view is a name plus a `BeakQueryState`, stored as a row of a model you own. The store maps three string columns of that model.

```dart title="examples/foodio-adminpanel/lib/models/saved_view.dart"
--8<-- "examples/foodio-adminpanel/lib/models/saved_view.dart:foodioSavedViewSchema"
```

```dart title="examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart:composedListSavedViews"
```

`resource` holds the table of the list, so one model serves every list, and `state` holds the versioned JSON. The panel registers the store's model itself, so it does not have to be a `BeakResource`; make it one only if people should get pages for it. Its policies decide who can read and write views, and `BeakSavedViewStore.model(filter: ...)` narrows which rows a list offers on top of that. Foodio's schema has `owner` and `shared` columns, and the store does not use them, so every view there is visible to everyone who can read the model. Narrow the list with the store's `filter`, or scope the model itself with a row rule.

Saving works from the drawer. Next to Apply sits Save as view, which stores the staged state even if it was not applied. It opens a dialog with one field, the name, and saves through the normal form path, so it is a graph commit with a receipt like any other save. Decoding a stored state rejects any version other than `1`. The store reads at most 200 views per list.

Loading works from the same footer. A `Saved views` select sits beside Save as view once the list has stored views. Choosing one restores its search, filters, sort, columns and page size, and closes the drawer. To offer the picker somewhere else too, mount the exported `BeakSavedViews` widget, for example in the overview. It takes the store, the list's controller and the panel's data source; see [A saved list view](../recipes/a-saved-list-view.md).

## Export

`BeakListExport` puts an Export button in the page header. The click freezes the current query and asks the server for a CSV.

```dart title="examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart:composedListExport"
```

The file has one column per field in `fields`, in that order. The server ignores the page the list is on and streams every row that matches filters, search and sorts. It authorizes the export as a query, so row scopes and field policies apply, fields the account may not read are dropped, and password values are masked. Headings are the model's column labels, not the list's headings.

`.currency(minorUnits: true)` on `grossCents` is how Foodio exports cents as money. A formatted field sends its format with the request, and the panel's `BeakFormatting` (locale, currency, date patterns) goes along, so the file reads like the screen. `raw: true` skips both and exports stored values. The route itself is in [REST API](../reference/rest-api.md#export).

Everything can fail at the click, and the reason shows under the button. A source that does not implement `BeakExportDataSource` answers `This data source does not support CSV exports.` An export field that is empty, duplicated, reached through a relationship or missing from the model throws when the button is pressed, not when the panel starts. Delivery goes through a save dialog, or a browser download on the web.

## Refresh

A confirmed write to a table reloads every mounted list, count and summary that depends on it, including tables that reach it through a relationship. Changes by other people arrive only when the panel has a `BeakRefreshPolicy`:

```dart title="packages/beak_frontend/lib/src/data/beak_data_changes.dart"
--8<-- "packages/beak_frontend/lib/src/data/beak_data_changes.dart:BeakRefreshPolicy"
```

`interval` polls while the panel is in the foreground and something is listening. `onResume` (default `true`) refreshes when the app returns from the background. Without a policy nothing refreshes on resume. A tick invalidates every registered table, so each open list refetches its page and its preset counts, and each summary block refetches. Foodio polls every 30 seconds and on resume. A zero or negative interval throws `A refresh interval must be positive.` when the panel starts. Set the policy on `BeakPanel(refreshPolicy: ...)` or `BeakPanelConfig`.

## Scrolling and density

`scrollMode` says who scrolls. `BeakListScrollMode.table` (default) gives the rows a bounded viewport with pagination below. `page` lets rows take their natural height and the page scroll through rows and pagination, which Foodio uses together with `fitTableToRows`. Below 700 logical pixels the list becomes one scrolling column and the table keeps a viewport between 360 and 560 pixels, unless `scrollMode` is `page`. `pageSizeOptions` are the page lengths offered, and the current length is always among them. `showTableStatusBar` adds a row count above the pagination.

## Rules and limits

| Rule | What happens |
| --- | --- |
| Preset keys are non-empty and unique | `Invalid list definition.` when the list is built |
| `initialPreset` and any navigation preset come from `presets` | Otherwise `Unknown list preset "x".` |
| `query` targets the resource's own table | `Table screen query must target "orders".` at startup |
| `definition.filters` empty means the resource's filters | Declared filters replace those completely |
| Counts cost one request per preset | After every write and every refresh tick |
| Only `BeakSummaryBlock` follows the list's query | Other blocks in a header do not |
| Export fields are direct scalar fields of the list model | Checked at the click |
| The saved-view model needs no resource of its own | The panel registers the store's model. Its policies decide who reads and writes views |
| Two filters may not share a field | The panel throws at startup: they would share one state. Use one choice filter with several options |
| A restored choice is matched by the JSON of its predicate | Changing a choice's predicate makes bookmarks and saved views stop selecting it |
| The state in the address is capped at 16384 characters | Larger values fail to restore |
| `sortBy` is a `sortable` field of the listed model | Related sorting is not inferred |
| Panel permissions hide UI | The server authorizes every query, count, export and saved view |

## Verify it

The composed list, its query controller, saved views and export have tests that run against a fake source. From `packages/beak_frontend`:

```console
$ flutter test test/src/panel/beak_composed_list_test.dart test/src/table/beak_query_controller_test.dart test/src/table/beak_saved_views_test.dart test/src/table/beak_list_export_test.dart --reporter expanded
00:00 +2: test/src/table/beak_query_controller_test.dart: preset counts are read by the preset object, never by its key
00:05 +19: test/src/panel/beak_composed_list_test.dart: counted presets share query, columns, URL and summary population
00:07 +22: test/src/panel/beak_composed_list_test.dart: filter sheet previews without changing active rows until Apply
00:09 +25: All tests passed!
```

## Reference

The list definition, verbatim:

```dart title="packages/beak_frontend/lib/src/query/beak_list_definition.dart"
--8<-- "packages/beak_frontend/lib/src/query/beak_list_definition.dart:BeakListDefinition"
```

| Parameter | Type | Meaning |
| --- | --- | --- |
| `presets` | `List<BeakQueryPreset>` | Named, counted views. Tab order |
| `columns` | `List<BeakTableColumn>` | Composite columns. Empty falls back to `fields`, then to the model |
| `filters` | `List<BeakFilterDef>` | Controls in the drawer. Empty inherits the resource's |
| `quickFilters` | `List<BeakFilterDef>` | Chips beside the search field |
| `quickFilterLabels` | `Map<BeakFilterDef, String>` | Shorter chip labels |
| `filterSheetWidthInPixels` | `double` | Drawer width, clamped to the viewport. Default `440` |
| `filterDescription` | `String?` | Hint below the drawer title |
| `advancedFilterDescription` | `String?` | Hint beside More filters |
| `advancedFilterColumns` | `int` | Columns of the advanced group. Default `1` |
| `recordNoun` | `String` | Plural noun for result counts. Default `records` |
| `header`, `collapsedHeader` | `BeakBlock?` | Overview blocks, full and compact |
| `initialPreset` | `BeakQueryPreset?` | Selected before a bookmark or saved view applies |
| `persistQueryInUrl` | `bool` | Write state to `?list=`. Default `true` |
| `showPresetCounts` | `bool` | Show count badges. Default `true` |
| `showSearch` | `bool` | Show the search field. Default `true` |
| `searchPlaceholder` | `String?` | Text naming the searched fields |
| `title`, `subtitle` | `String?` | Page title override and text below it |
| `subtitleBuilder` | `String Function(BeakPresetCounts)?` | Subtitle from the preset counts. Wins over `subtitle` |
| `pageSize` | `int` | Initial page length when `query` sets none. Default `15` |
| `showHeaderToggle` | `bool` | Show charts switch. Default `false` |
| `headerInitiallyVisible` | `bool` | Overview shown at first. Default `true` |
| `savedViews` | `BeakSavedViewStore?` | Model-backed shared views |
| `rowActions` | `List<BeakActionPresentation>?` | Row action placement. `null` keeps every action in the overflow menu |
| `bulkActions` | `List<BeakActionPresentation>?` | Selection actions, in order. Model commands named here are included automatically |
| `bulkModelActions` | `List<BeakModelAction>` | Model commands offered for a selection without presentation |
| `createLabel` | `String?` | Label of the create button |
| `export` | `BeakListExport?` | CSV export |
| `showTableStatusBar` | `bool` | Row count above the pagination. Default `false` |
| `fitTableToRows` | `bool` | Shrink short pages to their rows. Default `false` |
| `scrollMode` | `BeakListScrollMode` | `table` (default) or `page` |
| `floatingBulkActions` | `bool` | Selection bar at the page bottom. Default `false` |
| `pageSizeOptions` | `List<int>` | Page lengths offered. Default `[15, 25, 50, 100]` |

```dart title="packages/beak_frontend/lib/src/query/beak_query_controller.dart"
--8<-- "packages/beak_frontend/lib/src/query/beak_query_controller.dart:BeakQueryPreset"
```

```dart title="packages/beak_frontend/lib/src/presentation/beak_record_template.dart"
--8<-- "packages/beak_frontend/lib/src/presentation/beak_record_template.dart:BeakTableColumnField"
```

| `BeakTableColumn` parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `key` | `String` | required | Column identity in state and addresses |
| `label` | `String` | required | Heading |
| `template` | `BeakRecordTemplate` | required (`.action` has none) | The cell |
| `sortBy` | `BeakScalarField<Object>?` | `null` | Field of the listed model that the header sorts by |
| `widthInPixels` | `double?` | `null` | Initial width |
| `minWidthInPixels` | `double` | `160` | Width below which a narrow viewport scrolls |
| `textAlign` | `TextAlign` | `start` | Heading and cell alignment |
| `cellPadding` | `EdgeInsetsGeometry?` | `null` | Insets. `null` follows the table theme |
| `selector`, `choices`, `fallback` | `.action` only | | Value binding, value-to-action map, default action |

```dart title="packages/beak_frontend/lib/src/query/beak_list_export.dart"
--8<-- "packages/beak_frontend/lib/src/query/beak_list_export.dart:BeakListExport"
```

| `BeakListExport` parameter | Meaning |
| --- | --- |
| `fields` | Direct scalar fields of the list model, non-empty and unique, in file order |
| `label` | Button label. Default `Export` |
| `fileName` | Saved name. Default `<table>.csv` |
| `raw` | Stored values instead of the display policy. Default `false` |

```dart title="packages/beak_frontend/lib/src/query/beak_saved_views.dart"
--8<-- "packages/beak_frontend/lib/src/query/beak_saved_views.dart:BeakSavedViewStore"
```

| `BeakSavedViewStore.model` parameter | Meaning |
| --- | --- |
| `model` | The model that stores views |
| `name`, `resource`, `state` | `BeakScalarField<String>` columns for the name, the list's table and the JSON state |
| `filter` | Optional scope of the rows offered, in addition to server policies |

`BeakQueryController` (`package:beak/panel.dart`) is the object behind `BeakQueryScope.of(context)`.

| Member | Meaning |
| --- | --- |
| `state`, `presets`, `presetCounts` | Signals and lists a widget can watch |
| `query`, `queryFor(state, {excludingFilter})` | The spec for the state, or for a candidate state |
| `effectiveFilters(state)` | Preset defaults plus explicit filters, without cleared ones |
| `countQuery(preset)` | The query behind a tab count |
| `selectPreset`, `setSearch`, `sortBy`, `goToPage`, `setPageSize` | Change one thing. Each goes back to page 1 except `goToPage` |
| `applyFilters`, `previewFilters`, `removeFilter`, `clearFilters` | Filter changes. `previewFilters` builds a candidate without applying |
| `availableColumns`, `currentColumns`, `chooseColumns` | Column choice |
| `setHeaderVisible` | Overview visibility |
| `restore(state)` | Replace all choices at once, for history and saved views |
| `writeUri(uri)`, `BeakQueryController.readUri(uri)` | Address round trip. Parameter name `list` |

## Continue reading

- [Actions](actions.md): the row, bulk and page actions that `rowActions` and `bulkActions` place.
- [Filter builders](../reference/filter-builders.md): the controls that go into `filters` and `quickFilters`.
- [Summaries](../blocks/summaries.md): the blocks that follow a list's query from its overview.
- [Navigation](navigation.md): bookmark a preset with `BeakNavigationItem.resource(model, preset: ...)` and show its count.
