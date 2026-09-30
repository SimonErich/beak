---
title: Export to CSV
description: Add an Export button to a composed list so the CSV holds every row the current filters, search and sort match, formatted like the screen or as raw values.
type: recipe
audience: [beginner, expert, agent]
status: stable
---

# Export to CSV

You want the orders list to hand people a spreadsheet of what they are looking at: the same filters, the same search, every page, and an amount that reads `€ 12,50` and not `1250`.

## Recipe

Give the list a `BeakListExport`. It lives on the `BeakListDefinition` of a composed list, and its `fields` decide the columns, in order. Foodio's order list exports eight:

```dart title="examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart"
--8<-- "examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart:composedListExport"
```

`fields` are direct scalar fields of the listed model, by generated reference. A field that is a related record's field (`OrderModel.customer.email`) is not allowed. `OrderModel.grossCents.currency(minorUnits: true)` tells the export that the integer is cents and should read as money. Without it `1250` stays `1250`.

The list now has an `Export` button in the page header. Pressing it freezes the list's current query and asks the server for a CSV. The file has one column per field in `fields`, headed with the model's column labels, and it saves as `orders.csv`: through a save dialog on desktop, as a download in the browser.

The same `Export` also appears in the selection bar. Tick rows there and it exports only the selection, through the same query with the ticked ids added.

## How it works

- The button sends `POST /api/{table}/export` with the list's `BeakQuerySpec`, the column keys, and the display policy. The server ignores the page the list is on and streams every row that matches the filters, search and sorts, in pages of 500 rows, with the primary key as the last sort so no row is skipped or repeated between pages. Nothing is scraped from the table on screen.
- The server authorizes the export as a query. Row scope, field read access and password masking apply, and a column the account may not read is dropped from the file.
- Formatted (what the button sends unless the definition says `raw: true`) uses the panel's `BeakFormatting` (locale, currency, date patterns), so the file reads like the screen. The shop's API produces this for its products under `de_AT` and `EUR`, in primary-key order because no sort is set:

```csv
Name,Sku,Net price,Active
Espresso Beans,,"€ 12,50",Yes
Hand Grinder,,"€ 48,00",Yes
Ethiopia — Yirgacheffe,COF-ETH,"€ 14,50",Yes
```

- `BeakListExport(raw: true)` skips the formatting and writes storage values. The same rows:

```csv
Name,Sku,Net price,Active
Espresso Beans,,1250,true
Hand Grinder,,4800,true
Ethiopia — Yirgacheffe,COF-ETH,1450,true
```

- Raw money is the scaled integer, `1250` for 12.50. Use raw for a machine that knows the scale, and formatted for a person. A formatted `BeakDecimal` never passes through a `double`.
- A missing value is an empty cell in both modes, so a spreadsheet sees a blank and not the panel's `—`. Text that starts with `=`, `+`, `-` or `@` gets a leading `'`, so a product called `=HYPERLINK(...)` opens as text and does not run. A plain number such as `-5` is left alone.
- An export field that is empty, listed twice, reached through a relation or unknown to the model throws when the button first draws, not at the click and not when the panel starts. A source that cannot export answers `This data source does not support CSV exports.` at the click, and the reason shows under the button.
- The first page is queried before the response starts, so a bad request is a normal error. A failure on a later page truncates the file, because the status line is already sent.

## Variations

| You want | Do this |
| --- | --- |
| Another label or file name | `BeakListExport(label: 'Download CSV', fileName: 'kitchen.csv', ...)` |
| A date or number formatted on purpose | `Model.field.formatted(BeakValueFormat.date)` in `fields`. Its format travels with the request. |
| The API without the panel | `curl -X POST localhost:8080/api/orders/export -H 'content-type: application/json' -d '{"table":"orders","raw":true}'`. Body keys are in [REST API](../reference/rest-api.md#export). |
| A resource with no composed list | No button. Use `BeakClient.export` from your own action, or the route above. |
| To import the file again | Not round-trip safe. Convert first, see [A CSV import](a-csv-import.md). |
| A limit on rows | None: the export streams all matching rows. Restrict by filter or by row policy. |

## Verify

The frontend test checks that the button sends the active query, the column list and the panel's formatting, and downloads once. The backend tests cover the header, CSV quoting, formatting, the raw values and the 422 for malformed options.

```console
$ cd packages/beak_frontend
$ flutter test test/src/table/beak_list_export_test.dart
00:00 +5: All tests passed!
$ cd ../beak_backend
$ dart test test/src/export/csv_export_test.dart
00:00 +16: All tests passed!
```

To see the file, run the Foodio API (port 8081) and the panel, open Orders, filter the list, and press `Export`. The rows in the file are the rows the filters match, not the 15 on the first page.

## Continue reading

- [A CSV import](a-csv-import.md) goes the other way, from pasted CSV to records.
- [Composed lists](../panel/composed-lists.md) covers the list definition that carries the export.
- [REST API](../reference/rest-api.md#export) documents the route and every body key.
