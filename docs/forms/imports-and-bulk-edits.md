---
title: Imports and bulk edits
description: Preview pasted CSV rows and the same change on many selected records, validate every row, then save them one graph at a time with recovery.
type: guide
audience: [expert]
status: stable
---

# Imports and bulk edits

After this page you can add a CSV import to a screen, add a bulk edit to a table, and predict what happens when a batch of fifty saves stops at row thirty.

Both features share one shape: build a preview, validate every row on the client with the model's own rules, show the review, and only then save. Both save row by row, each row as its own graph commit with its own receipt. That has a consequence you should read before you promise anyone an "undo": a batch is not one transaction.

## At a glance

An import is a widget you embed. The shop puts a category import on its Operations page:

```dart title="examples/clean_beak_config/lib/operations.dart"
--8<-- "examples/clean_beak_config/lib/operations.dart:categoryImportBlock"
```

A bulk edit is an action on a resource. The product resource adds two, one that turns products on and one that turns them off:

```dart title="examples/clean_beak_config/lib/resources/products/product_resource.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/product_resource.dart:ProductBulkActions"
```

| | Import | Bulk edit |
| --- | --- | --- |
| Entry point | `BeakImportView` with a `BeakImportDefinition` | `BeakBulkAction.edit(...)` in `bulkActions:` |
| Input | Pasted CSV text | The rows selected in the table, plus fixed `BeakFieldChange`s |
| Creates or updates | Creates | Updates |
| Per row | One create graph | One update graph, guarded by the record's `updated_at` |
| Where it appears | Wherever you put the widget | A dialog opened from the selection bar |

## Importing CSV

`BeakImportDefinition` names the model and the fields that a CSV may fill. The list is an allowlist of generated scalar fields of that model, so a CSV cannot reach a column you did not name, and there is no way to spell a column as a string. Headers default to each field's label. Rename one with `headers: {CategoryModel.name: 'Category'}`. Headers and fields must be unique, or the definition throws a `BeakConfigurationException`.

`BeakImportView(definition:, title:, initialCsv:, dataSource:)` is the surface. It shows the expected headers, a "CSV data" text area, and a Preview import button.

!!! note "There is no file picker"
    The CSV is pasted into the text area. That keeps the widget free of platform code, and it is enough for the few hundred rows the preview is meant for.

Parsing follows RFC-style CSV: quoted commas, doubled quotes, CRLF, line breaks inside quotes and a leading byte-order mark are accepted. Two limits apply before anything is validated: 2 million characters of text, and `maximumRows` data rows (500 by default). Beyond either, the preview fails with a message.

Each cell is parsed with the type of its column:

| Column | The cell holds |
| --- | --- |
| Text | The text as it is |
| Integer, decimal | A number in the panel's locale: the decimal and grouping separators come from the panel's formatting policy |
| Money, exact decimal | The same locale rules, at the column's scale. Extra decimal places are an error, not a rounding |
| Percentage | A number in percent, so `2.5` is stored as `0.025` for a column whose 100% is `1` |
| Boolean | `true` or `false`, any case |
| Calendar date, time, duration | ISO `YYYY-MM-DD`, `HH:MM` or `HH:MM:SS`, and `hours:minutes:seconds` |
| Date and time | An ISO 8601 timestamp |
| Enum | The enum value's name, checked by the column's rules |

An empty cell means an explicit null. A column left out of the CSV is left out of the row, so the model's defaults apply.

Then every row is validated with the model's rules, defaults and behavior, the same code the form and the server run. The review counts the rows, marks how many need correction, and lists the first 20 rows with their values and errors. Every row is validated, not only those 20. A malformed header, a bad cell, a missing required value or a field the account may not write blocks the import button. Derived values are computed for validation and are not sent as caller-owned data.

## Bulk edits

`BeakBulkAction.edit(key:, label:, changes:)` takes typed `BeakFieldChange`s. A `BeakFieldChange(ProductModel.active, true)` pairs a field with a value of the field's Dart type, so a wrong type does not compile. The action opens the review in a dialog for the selected rows.

`BeakBulkEdit.preview(model:, records:, changes:)` builds the review. It applies the patch to a copy of each record and validates the result against the original, so a rule that reads several fields sees the whole record. It rejects a change to the primary key, a field listed twice, a field reached through a relation, an empty change list, and a selection that includes the same record twice or a record without an identity. Each update carries the record's `updated_at` when it has one, so a row someone edited after the selection loaded is refused instead of overwritten.

The button reads "Update N records". When the run stops, "Reload remaining records" refetches the not yet saved rows so their baselines and revisions are current before you try again.

## How the batch runs

`BeakBatchRepository` executes the plans in order, one commit at a time. The save id of each row is derived from the batch id and its row number, so a row has a stable identity for replay and recovery.

| Situation | What happens |
| --- | --- |
| A row applies | Progress advances. The next row starts |
| A row is refused by the server | The batch stops. Earlier rows stay saved |
| A row's outcome is unknown | The batch stops until "Check interrupted save" resolves it. Nothing is replayed blindly |
| You press "Stop after current record" | The in-flight row finishes and its receipt is collected. Then the batch stops |
| You press Resume | Rows with a complete receipt are skipped |

Each row keeps the atomicity of its own graph, so a row is saved completely or not at all. The batch as a whole is not atomic: rows that saved stay saved, and the review says so before you start ("Records save individually. Completed records stay saved if a later record fails or you stop.").

After a refused row or a stop, the CSV is locked and "Edit remaining rows" makes it editable again. Keep the saved rows unchanged and in the same positions, or the preview refuses the correction with "Row N has already been saved". Rows that saved keep their save ids. The rest get fresh ones, so a corrected row is a new save, not a replay of a rejected one. Before submission both features recheck which fields the account may write.

The queue lives as long as the widget is mounted. It is not stored across a reload and not shared between tabs. Changing the source or the definition while a batch is open stops it after the current record and asks you to start a new review. For an import of thousands of rows or one that must survive a closed browser, keep the plans and receipts in a job of your own; the widget is a review tool, not a job runner.

## Rules and limits

| Rule | Behavior |
| --- | --- |
| Commit-capable source only | Imports and bulk edits need a `BeakCommitDataSource`. Otherwise the run fails with "This source does not support graph imports." |
| Preview bound | 500 data rows and 2 million characters by default. Raise `maximumRows` deliberately |
| Field allowlist | Only the fields named in the definition can be imported, and they must be direct scalar fields of the model |
| Not one transaction | Rows save individually. A failure leaves the earlier rows saved |
| Unknown outcomes block | The batch does not continue past an unknown row until it is checked |
| Concurrent edits | A bulk update is conditional on `updated_at`. A model without that column is updated without a check |
| No persistence | The queue is in memory. A reload discards the review and the receipts |
| Export is a different contract | A raw export holds storage values such as integer cents, and a formatted export holds display strings. Convert before importing what you exported |
| Authorization | The server applies row, field and action policies to every graph, so a preview that passes can still be refused |

## Verify it

The parser, the review and the recovery paths have package tests:

```bash
cd packages/beak_frontend
flutter test test/src/form/beak_import_view_test.dart
```

The run ends with `All tests passed!`. To try it, run the shop (API on port 8080), open Operations, paste `Name,Description` followed by two rows into the category import, and press Preview import. Then select two products, choose "Stop selling" from the selection bar and check the review lists both.

## Reference

| Symbol | Where it is documented |
| --- | --- |
| `BeakImportDefinition`, `BeakBulkEdit`, `BeakFieldChange`, `BeakBatchRepository` | `packages/beak_frontend/lib/src/data/beak_record_batch.dart` |
| `BeakImportView`, `BeakBulkEditView` | `packages/beak_frontend/lib/src/form/beak_import_view.dart` |
| `BeakBulkAction.edit` | [Behavior and actions](../reference/behavior-and-actions.md#beakbulkaction) |
| The `/api/commits` route each row uses | [Graph commits](../architecture/graph-commits.md), [REST API](../reference/rest-api.md) |

## Continue reading

- [Actions](../panel/actions.md) how bulk actions sit next to record and global actions.
- [Drafts, review and conflicts](drafts-and-review.md) the receipts and recovery that each row reuses.
- [Search and export](../backend/search-and-export.md) the export side of a round trip.
- [A CSV import](../recipes/a-csv-import.md) and [a bulk edit](../recipes/a-bulk-edit.md) as short recipes.
