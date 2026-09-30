---
title: Tables and filters
description: Choose the columns of a resource list, scope and sort its rows, and put typed filters above it. Every change is one server-side query.
type: guide
audience: [beginner]
status: stable
---

# Tables and filters

A resource with no screens already lists its model as a table. This page covers what you usually change next: which columns show, which rows are in scope and in what order, and which filters sit above the table. All of it is configuration on the resource, and the work happens on the server.

## At a glance

| | |
| --- | --- |
| Declared on | `BeakResource.screens` (one `BeakTableScreen`) and `BeakResource.filters` |
| Smallest form | Nothing. The resource lists the model's table columns and its to-one relations |
| Columns | `BeakTableScreen(fields: [...])`, typed field references in display order |
| Scope, order, page size | `BeakTableScreen(query: ...)`, a `BeakQuerySpec` from `const XModel().query(...)` |
| Filters | `BeakResource.filters`, or one control per `filterable` column when you list none |
| Where the work happens | On the server. A sort, a filter or a page change is one `BeakQuerySpec` |
| Needs more | Add `definition:` and the list becomes a [composed list](composed-lists.md) |

## What a list shows without a screen

`BeakResource(model: const NoteModel())` lists the columns the model shows in the table context (`@Column(visibleOn: ...)`, default: table, form and detail). Every to-one relation is loaded with the page, in the same query, and shown by its display label instead of its foreign key, so you read `Beverages` where a raw column would say `a3f9c1e2-…`. The label links to the related record.

A click on a row opens the show page. A header sorts only if the column says `@Column(sortable: true)`. The table asks for 25 rows at a time and offers 10, 25, 50 and 100 per page. A failed load renders an error state with a Retry button, and an empty result renders an empty state.

One thing it does not have: a search field. The plain list filters, it does not search. Search lives elsewhere, see [Search](#search).

## Choose the columns

`BeakTableScreen.fields` takes typed field references, in the order you want them. A path through a relationship is a field like any other, so a product list can show its category's name.

```dart title="examples/clean_beak_config/lib/resources/products/product_resource.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/product_resource.dart:listProductFields"
```

Related paths are loaded automatically with the page. A related column displays but does not sort, because a sort names a column of the listed model. `.formatted(BeakValueFormat.text, label: 'Category')` gives the column its heading and leaves the text as it is.

Formatting is display-only. The shop's invoice list shows its exact total as money under a friendlier heading:

```dart title="examples/clean_beak_config/lib/resources/invoices/invoice_resource.dart"
--8<-- "examples/clean_beak_config/lib/resources/invoices/invoice_resource.dart:listInvoiceFields"
```

`.formatted(...)` and `.currency(...)` (with `minorUnits: true` for integer cents) wrap the field. Queries, sorts and filters keep the original field and value type, so no formatted string travels to the server as data. The locale and currency come from the panel's `BeakFormatting`, see [Formatting and localization](../theming/formatting-and-localization.md).

## Scope, order and page size

`BeakTableScreen.query` is the list's permanent query. `const OrderModel().query()` starts a `BeakQuerySpec`, and the copy-builders add to it.

```dart title="examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart:composedListQuery"
```

That is the highest order number first, 15 rows per page. The user can still click another header (which replaces your sort), page through the result and change the page size. What they cannot do is remove the query's `filter:`. It stays in force whatever the filter bar adds, so `query` is the place for "only open orders" or "only my region".

A permanent scope shapes what the panel asks for. It does not authorize anything. Row policies and field policies run on the server for every request, whatever the panel sends, see [Auth and policies](../backend/auth-and-policies.md).

## Filters

A resource declares its filters as typed builders on the generated field references. None of them takes a string.

```dart title="examples/clean_beak_config/lib/resources/invoices/invoice_resource.dart"
--8<-- "examples/clean_beak_config/lib/resources/invoices/invoice_resource.dart:listInvoiceFilters"
```

A select for the status, a record picker for the customer, a date range for the invoice date. The products list mixes in a boolean and a money range:

```dart title="examples/clean_beak_config/lib/resources/products/product_resource.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/product_resource.dart:listProductFilters"
```

List no filters and Beak builds one control per column marked `filterable: true`, of the kind the column's type calls for. Marking two columns `filterable` is the whole filter bar for a resource. Declared filters replace those defaults completely, they do not merge with them. Every builder, its control and the predicate it emits is in [Filter builders](../reference/filter-builders.md).

The filter bar shows compact chips. An inactive filter is an outlined chip with its label, an active one shows a short summary of its value and a remove button, and a Clear all button appears while anything is active. Choosing a chip opens the editor in a popover, so a resource with six filters does not push the table down by six empty inputs.

Each active control contributes one predicate. Beak combines them with AND, and with the `filter:` of `query`. A change in the bar rebuilds the table from its initial query, so it starts again on page one.

## Search

A plain list has no search field. Two other places search, and both use the same field list:

- The command bar (Ctrl-K or Cmd-K) searches every visible resource at once, see [Navigation](navigation.md).
- A composed list has its own search field, see [Composed lists and query state](composed-lists.md).

`BeakResource.globalSearchSources` says which fields they search.

```dart title="examples/clean_beak_config/lib/resources/products/product_resource.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/product_resource.dart:listProductSearch"
```

List nothing and the search runs over the model's `@Column(searchable: true)` columns. The list may name scalar fields of the model, fields reached through a to-one relation (`ProductModel.category.name`) and text inside a to-many relation (`ProductModel.variants.search(ProductVariantModel.sku)`).

## Rows, selection and actions

A row click opens the show page and appends `returnTo`, the address of the list you left. The Back button follows it, so you land on the same list. View, Edit and Create pass it on, so saving an edit and going Back, or creating a record, ends at the same list too. Only local paths are accepted: a `returnTo` with a scheme or a host is ignored and Back goes to the resource's list route.

The row menu holds View, Edit and Delete (each only while the resource and the model's permissions allow it), the resource's `recordActions` and the model actions available for that row. Checkboxes appear once the list has bulk actions, and the selection belongs to the current page. Defining the actions is on the [Actions](actions.md) page.

## Staying current

The table watches its data source. A confirmed write to its table, or to a table that has a relationship to it, reloads the current page. Responses resolve latest-wins, so a slow answer never overwrites a newer one. Changes made by other people arrive only when the panel has a `BeakRefreshPolicy`, see [Composed lists and query state](composed-lists.md#refresh).

## Rules and limits

| Rule | What happens |
| --- | --- |
| One list screen per resource | `screenFor` throws `Resource "products" defines more than one list screen.` when the resource is built |
| `query` targets the resource's own table | Otherwise `Table screen query must target "products".` at startup |
| `fields` holds scalar fields | Relation paths are allowed. A related column does not sort |
| A column sorts only when `sortable: true` | The header of any other column is inert |
| Declared `filters` replace the derived ones | List a filter for every column you still want |
| Two filters over one field would share one state | The panel throws a `BeakConfigurationException` at startup. Declare one filter per field |
| The filter bar does not survive a reload | Plain lists keep no filter state in the address. Composed lists do |
| A filter change, or an action that refreshes the list, rebuilds the table | Sort and page go back to what `query` says |
| Checkboxes need bulk actions | A resource with none has no selection |
| Selection is per page | Moving to another page starts a new selection |
| `globalSearchSources` are fields rooted at this model | A field of another model throws `Global search for "products" requires scalar fields rooted at that model.` |
| Password columns cannot be searched | The command bar reports a configuration error for that resource |

The permanent scope is presentation. Authorization happens on the server.

## Verify it

The table, its filter bar and the shop's product list have tests that run without a server. From `packages/beak_frontend`:

```console
$ flutter test test/src/table/beak_data_table_test.dart test/src/table/resource_filters_test.dart test/src/table/beak_table_view_model_test.dart --reporter expanded
00:01 +13: test/src/table/resource_filters_test.dart: derived enum filters have one typed control on a resource
00:02 +20: test/src/table/beak_data_table_test.dart: rendering a foreign key renders the related record, in one query
00:03 +24: test/src/table/beak_data_table_test.dart: server-side operations tapping a sortable header emits a replaced BeakSort
00:03 +25: test/src/table/beak_data_table_test.dart: server-side operations pagination emits the requested BeakPagination
00:04 +26: test/src/table/beak_data_table_test.dart: server-side operations changing the page size refetches from page one
00:05 +33: All tests passed!
```

And the shop's product list against an in-memory source, from `examples/clean_beak_config`:

```console
$ flutter test test/shop_widget_test.dart --reporter expanded
00:01 +1: the product list shows exact euro prices
00:03 +6: All tests passed!
```

## Reference

The screen, verbatim:

```dart title="packages/beak_frontend/lib/src/panel/beak_resource_screen.dart"
const BeakTableScreen({this.fields, this.query, this.definition})
  : super(roles: const {BeakScreenRole.list});
```

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `fields` | `List<BeakScalarField<Object>>?` | `null` | Columns in display order, related paths allowed. `null` keeps the model's table columns |
| `query` | `BeakQuerySpec?` | `null` | Permanent filter, initial sort and initial page size. `null` means an unfiltered first page of 25 |
| `definition` | `BeakListDefinition?` | `null` | Turns the list into a [composed list](composed-lists.md) |

Field helpers, from `package:beak/panel.dart`:

| Helper | On | Effect |
| --- | --- | --- |
| `formatted(BeakValueFormat format, {String? label})` | any scalar field | Display format and heading. The field keeps its type |
| `currency({bool minorUnits, int scale, String? label})` | numeric field | Money display. `minorUnits: true` reads integer cents |
| `ascending()`, `descending()` | scalar field of the listed model | A `BeakSort` for `query(sorts: [...])` |

`BeakValueFormat` has the values `text`, `number`, `currency`, `date`, `dateTime`, `time` and `percent`.

Members of `BeakResource` that shape the list:

| Member | Meaning |
| --- | --- |
| `screens` | Holds the `BeakTableScreen`. At most one per role |
| `filters` | Declared filter definitions. Empty means the derived ones |
| `effectiveFilters` | The filters the list page renders |
| `globalSearchSources` | Fields the command bar and a composed list's search field use |
| `recordActions`, `bulkActions`, `globalActions` | Actions on a row, on the selection and on the page |
| `canCreate`, `canEdit`, `canDelete` | Switches for the matching buttons and routes |

| Default | Value |
| --- | --- |
| Rows per page without `query` | 25 |
| Page-size choices | 10, 25, 50, 100, plus the current size |
| Filter bar presentation | Chips |

## Continue reading

- [Composed lists and query state](composed-lists.md): preset tabs, staged filters, saved views and CSV export on one shared query.
- [Filter builders](../reference/filter-builders.md): every filter definition, the control it renders and the predicate it emits.
- [Actions](actions.md): row, bulk and page actions on a resource.
- [Queries](../reference/queries.md): the `BeakQuerySpec` behind every list.
