---
title: A CSV import
description: Add a paste-in CSV import for one model with BeakImportView. Every row is checked with the model's rules before anything is saved, then saved one by one.
type: recipe
audience: [beginner, expert, agent]
status: stable
---

# A CSV import

You have a spreadsheet of categories and you want them in the shop without typing them. Paste the CSV, see which rows are wrong, fix them, and save the rest.

## Recipe

Put a `BeakImportView` on a page. Its `BeakImportDefinition` names the model and the fields a CSV may fill. The shop puts a category import on its operations page:

```dart title="examples/clean_beak_config/lib/operations.dart"
--8<-- "examples/clean_beak_config/lib/operations.dart:categoryImportBlock"
```

`fields` is an allowlist of generated field references, so a CSV can reach only the columns you named, and no column is ever spelled as a string. The widget takes the panel's data source and formatting from the surrounding panel. The page it sits on is an ordinary `BeakScreen`, see [Custom screens](../panel/custom-screens.md).

Paste this into the CSV data box and press `Preview import`:

```csv
Name,Description
Beans,Whole beans
Filters,Paper filters
```

The review shows a card per row (`Row 2`, `Name: Beans`) and the count `2 records. 0 need correction.` Then `Import 2 records` saves them, and the panel reports `2 of 2 records saved.` The rows are numbered as in a spreadsheet: the header is row 1.

A row that breaks a rule is marked and blocks the button. With a missing name in the second row the review reads `2 records. 1 need correction.` and shows `Row 3`, `Name: —` and the rule's own message, `This field is required.` Correct the text and preview again.

## How it works

- Headers default to each field's label (`Name`, `Description`). Rename one with `headers: {CategoryModel.name: 'Category'}`. Headers must match the declared ones and be unique, or the preview stops with `CSV headers must be unique declared import fields.` A column you leave out of the CSV takes the model's default.
- Each cell is parsed with the type of its column. An empty cell is an explicit null. Numbers follow the panel's locale, so under `de_AT` money is `12,50` and `12.50` is rejected. The comma is also the CSV separator, so quote the cell: `"12,50"`. Enum cells hold the value's name, booleans `true` or `false`, dates ISO 8601.
- Then the row goes through the same rules as a form: the column rules, the model's `validationRules` and its behavior. That is the code the server runs, so a row that passes here can still be refused there by a policy, and the review does not pretend otherwise.
- `Import N records` sends one graph commit per row, each with its own `saveId` (`<batch>-<row number>`) and its own receipt. It is not one transaction: a rejected row stops the run and the earlier rows stay saved. A lost connection blocks the run until `Check interrupted save` reads the receipt, and nothing is sent twice.
- Before the preview, the widget asks the server whether the account may write the fields. If not, it says `Some import fields are not writable by your account.` and the import button stays off.
- The review lists the first 20 rows, and every row is validated, not only those. The text is limited to 2 million characters and to `maximumRows` data rows, 500 by default. Beyond either, the preview fails with a message.
- There is no file picker. The CSV is pasted, which keeps the widget free of platform code. It is meant for a few hundred rows, and a larger import belongs in a job of your own.

## Variations

| You want | Do this |
| --- | --- |
| Friendlier column names | `headers: {CategoryModel.name: 'Category'}` |
| More rows in one go | `maximumRows: 2000`. Raise it on purpose: every row is a request. |
| A template already in the box | `initialCsv: 'Name,Description\n'` on `BeakImportView`. |
| The import on a resource's list page instead of its own page | A `BeakGlobalAction` in `globalActions` whose `onExecute` opens a `BeakImportView` in `context.overlays.dialog`. `BeakBulkAction.edit` opens its review the same way. |
| To fill a relation | Not possible: only scalar fields of the model can be imported. There is no lookup by display name. |
| To update existing rows | Not possible: an import only creates. A bulk edit updates, see [A bulk edit](a-bulk-edit.md). |
| To import what you exported | Convert first. A raw export holds storage values such as integer cents, and a formatted export holds display strings. See [Export to CSV](export-to-csv.md). |

## Verify

The parser and the review have package tests: quotes, newlines, typed cells, invalid rows, permissions, interrupted saves and correction of a rejected row.

```console
$ cd packages/beak_frontend
$ flutter test test/src/form/beak_import_view_test.dart
All tests passed!
```

For the import on your own page, mount it in a widget test with an in-memory source and paste a CSV. The shop's operations screen was driven this way with the CSV above: the two rows were previewed, imported, and read back from the source as `Beans` and `Filters`. To try it by hand, run the shop (API on port 8080), open Operations, and paste the CSV into the category import.

## Continue reading

- [Export to CSV](export-to-csv.md) goes the other way, from a list to a file.
- [Imports and bulk edits](../forms/imports-and-bulk-edits.md) covers the batch queue, recovery and every parsing rule.
- [A money field](a-money-field.md) explains the exact amounts an import reads in the panel's locale.
