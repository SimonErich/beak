---
title: A saved list view
description: Let people save a list's filters, sort and columns as a named view stored in a model, and mount the picker that brings a view back, which the toolbar lacks.
type: recipe
audience: [beginner, expert, agent]
status: stable
---

# A saved list view

You want "Open orders in the kitchen" to be one click instead of five filters. A person sets up the list, names it, and the view is there next time, for them or for the whole team.

One half of this is wired for you and the other is not. Saving from the filter drawer works out of the box. The picker that loads a saved view is not in the built-in toolbar, so this recipe mounts it.

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

Register the model as a resource. The saving form is an ordinary form over that model, and the panel refuses a table it does not know: `No model registered for table "saved_views".` Nothing else relates to the saved-view model, so it is only known if it is a resource. In a generated panel that is the default, as long as `beak.yaml` does not hide the table (see [Hide a resource](hide-a-resource.md)). In an authored panel it is one entry in `resources:`, illustrative here and using the real constructor:

```dart
BeakResource(
  model: const SavedViewModel(),
  icon: BeakIconToken(OiIcons.bookmark),
),
```

A registered resource is a page, and a generated panel puts every page in the sidebar. An authored panel with a `BeakNavigation` lists its entries explicitly, so the resource can stay out of the sidebar by not being mentioned. Foodio has such a navigation, and its `foodioResources()` does not list `SavedViewModel`, so saving a view in the running Foodio ends in the error above until the resource is added.

Saving now works. Open the filter drawer, set up the list, and press `Save as view` next to Apply. A dialog asks for a name and saves through the normal form path.

For the picker, mount `BeakSavedViews` yourself. The list's `header` is a block, `BeakWidgetBlock` runs any widget inside the list's query scope, and the widget needs three things: the store, the list's controller and the panel's data source. All three are one call away:

```dart
header: BeakWidgetBlock(
  (context) => BeakSavedViews(
    store: orderSavedViews,
    controller: BeakQueryScope.of(context),
    source: beakDependencies(context)<BeakDataSource>(),
  ),
),
```

`orderSavedViews` is the `BeakSavedViewStore.model(...)` above, pulled into a `final` so both places share it. This snippet is illustrative, assembled from the real constructors, and it was run in a scratch widget test: with a stored view named `Weekly` holding `search: weekly`, picking it in the `Saved views` select set the list's search to `weekly`. It also renders a `Save view` button that saves the current, applied state.

## How it works

- A saved view is a name and a `BeakQueryState`. The state is everything a person can change on the list, serialized as versioned JSON, the same representation that goes into the address bar:

```dart title="packages/beak_frontend/lib/src/query/beak_query_controller.dart"
--8<-- "packages/beak_frontend/lib/src/query/beak_query_controller.dart:BeakQueryStateJson"
```

- `resource` holds the table of the list, so one model serves every list. The form fills `resource` and `state` itself and submits them hidden, so the person only types the name.
- Decoding accepts version `1` only. A row with anything else fails with `The saved view contains invalid state.` in the picker.
- Who sees a view is the model's business. The store reads through the normal query route, so the model's policies and row rules decide. Foodio's `shared` and `owner` columns are declared and unused: every view there is visible to everyone who can read the model. Narrow it with `BeakSavedViewStore.model(filter: ...)` or scope the model with a row rule.
- A list shows at most 1000 views.
- A restored choice is matched by the JSON of its predicate. Change a preset's or a filter's definition in code and old views stop selecting it.

## Variations

| You want | Do this |
| --- | --- |
| Views per user | A row rule on the saved-view model, or `filter: SavedViewModel.owner.eq(...)` on the store. |
| A preset instead of a saved view | A `BeakQueryPreset` in the definition. Presets are code, one deploy per change, and they get counts. See [Composed lists](../panel/composed-lists.md). |
| A link that opens a view | A `BeakNavigationItem.resource(model, preset: ...)`. The address carries the list state in `?list=`. |
| The picker inside the filter drawer | Not available: the toolbar builds `BeakSavedViews` with `showSelector: false`. |
| A different label on the save button | `saveLabel:` on `BeakSavedViews`. |

## Verify

The store round trip has a package test: it saves a view through the store's form, lists it back, checks the namespace by table, and rejects malformed and unknown-version state.

```console
$ cd packages/beak_frontend
$ flutter test test/src/table/beak_saved_views_test.dart --plain-name 'shared views'
00:00 +1: All tests passed!
```

To try it by hand, run Foodio with the model registered, open Orders, set a filter in the drawer and save it. The view appears in the picker you mounted, and picking it sets the filter again.

## Continue reading

- [A CSV import](a-csv-import.md) fills a resource from pasted CSV.
- [Composed lists](../panel/composed-lists.md) covers presets, staged filters, columns and export together with saved views.
- [Export to CSV](export-to-csv.md) exports what the list is currently showing.
