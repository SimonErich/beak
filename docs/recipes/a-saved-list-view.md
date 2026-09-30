---
title: A saved list view
description: Let people save a list's filters, sort and columns as a named view stored in a model, and load it again from the filter drawer.
type: recipe
audience: [beginner, expert, agent]
status: stable
---

# A saved list view

You want "Open orders in the kitchen" to be one click instead of five filters. A person sets up the list, names it, and the view is there next time, for them or for the whole team.

Both halves are in the filter drawer. Save as view stores the staged choices, and a `Saved views` select next to it loads one again. This recipe adds the model and points the list at it.

## Recipe

A view is a row in a model you own, so start with the model. It needs three string fields: a name, the table of the list it belongs to, and the serialized state. Foodio's also has `owner` and `shared`, which nothing reads yet:

```dart title="examples/foodio-adminpanel/lib/models/saved_view.dart"
--8<-- "examples/foodio-adminpanel/lib/models/saved_view.dart:foodioSavedViewSchema"
```

Run `beak prepare`. It generates `SavedViewModel` and a create-table migration; apply it with `beak migrate`.

Tell the list where views live. `BeakSavedViewStore.model` takes the model and the three fields, all as generated references:

```dart title="examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart:composedListSavedViews"
```

`savedViews:` is a parameter of `BeakListDefinition`, so it works on a composed list only. A plain `BeakTableScreen(fields: [...])` has no place for it, see [Composed lists](../panel/composed-lists.md).

The panel registers this model itself when a list names it, so it needs no `BeakResource` and no sidebar entry. Make it a resource only if people should get pages for it.

Saving now works. Open the filter drawer, set up the list, and press `Save as view` next to Apply. A dialog asks for a name and saves through the normal form path.

Loading is in the same drawer. Once the list has stored views, a `Saved views` select sits beside `Save as view`. Choosing one sets the list's search, filters, sort, columns and page size, and closes the drawer.

To offer the picker somewhere else as well, mount the exported `BeakSavedViews` widget yourself. The list's `header` is a block, `BeakWidgetBlock` runs any widget inside the list's query scope, and the widget needs three things: the store, the list's controller and the panel's data source. All three are one call away:

```dart
header: BeakWidgetBlock(
  (context) => BeakSavedViews(
    store: orderSavedViews,
    controller: BeakQueryScope.of(context),
    source: beakDependencies(context)<BeakDataSource>(),
  ),
),
```

`orderSavedViews` is the `BeakSavedViewStore.model(...)` above, pulled into a `final` so both places share it. This snippet is illustrative, assembled from the real constructors. Besides the select it renders a `Save view` button that saves the current, applied state.

## How it works

- A saved view is a name and a `BeakQueryState`. The state is everything a person can change on the list, serialized as versioned JSON, the same representation that goes into the address bar:

```dart title="packages/beak_frontend/lib/src/query/beak_query_controller.dart"
--8<-- "packages/beak_frontend/lib/src/query/beak_query_controller.dart:BeakQueryStateJson"
```

- `resource` holds the table of the list, so one model serves every list. The form fills `resource` and `state` itself and submits them hidden, so the person only types the name.
- Decoding accepts version `1` only. A row with anything else (or text that is not JSON) is left out of the picker, so one bad row never hides the others. `BeakSavedViewStore.decode` itself still throws a `BeakConfigurationException`: `The saved view contains invalid state.` for text that is not JSON, `Unsupported saved list state.` for another version.
- Who sees a view is the model's business. The store reads through the normal query route, so the model's policies and row rules decide. Foodio's `shared` and `owner` columns are declared and unused: every view there is visible to everyone who can read the model. Narrow it with `BeakSavedViewStore.model(filter: ...)` or scope the model with a row rule.
- A list shows at most 200 views.
- A restored choice is matched by the JSON of its predicate. Change a preset's or a filter's definition in code and old views stop selecting it.

## Variations

| You want | Do this |
| --- | --- |
| Views per user | A row rule on the saved-view model, or `filter: SavedViewModel.owner.eq(...)` on the store. |
| A preset instead of a saved view | A `BeakQueryPreset` in the definition. Presets are code, one deploy per change, and they get counts. See [Composed lists](../panel/composed-lists.md). |
| A link that opens a view | A `BeakNavigationItem.resource(model, preset: ...)`. The address carries the list state in `?list=`. |
| The picker outside the filter drawer | Mount `BeakSavedViews` in the list's header, as above. |
| A different label on the save button | `saveLabel:` on `BeakSavedViews`. |

## Verify

The store round trip has a package test: it saves a view through the store's form, lists it back, checks the namespace by table, and rejects malformed and unknown-version state. A panel test opens the filter drawer of a list, sees the stored view in the `Saved views` select, saves a second one through the drawer, and checks that choosing a view queries with its search and closes the drawer.

```console
$ cd packages/beak_frontend
$ flutter test test/src/table/beak_saved_views_test.dart test/src/panel/beak_saved_view_picker_test.dart
All tests passed!
```

To try it by hand, run Foodio, open Orders, set a filter in the drawer and save it. The view appears in the `Saved views` select of the drawer, and choosing it sets the filter again.

## Continue reading

- [A CSV import](a-csv-import.md) fills a resource from pasted CSV.
- [Composed lists](../panel/composed-lists.md) covers presets, staged filters, columns and export together with saved views.
- [Export to CSV](export-to-csv.md) exports what the list is currently showing.
