---
title: A bulk edit
description: Add a Make available or Stop selling button to a table's selection bar, review the change per record, and save each record with its own receipt.
type: recipe
audience: [beginner, expert, agent]
status: stable
---

# A bulk edit

You want to tick twenty products in the list and switch them off in one go. The change is the same for every row, it is validated like any other edit, and a row someone else changed in the meantime is refused instead of overwritten.

## Recipe

Add a `BeakBulkAction.edit` to the resource's `bulkActions`. Each one is a key, a label and the typed changes it applies. The shop has two, one per direction:

```dart title="examples/clean_beak_config/lib/resources/products/product_resource.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/product_resource.dart:ProductBulkActions"
```

`BeakFieldChange(ProductModel.active, true)` pairs a generated field with a value of the field's Dart type. Pass `'yes'` and it does not compile. Two or more changes in one action are fine, each on a different field of the same model.

The list gains a selection bar. Tick rows and `Make available` and `Stop selling` appear in it. Clicking one opens a dialog titled with the label:

1. `Preview changes` builds the review: one card per record, with each changed field as `Label: before → after`, plus the model's validation errors for that record.
2. `Update N records` saves. Each record is its own graph commit with its own receipt. `Working…` and `K of N records saved.` show the progress, and `Stop after current record` stops the run.
3. Close the dialog and the table reloads.

## How it works

- The patch is applied to a copy of each selected record, and the result is validated against the original. A rule that reads two fields sees the whole record, and a record that would become invalid is marked in the review and blocks the button.
- The review asks the server what the account may write on each selected record. A record or field it may not write fails the review with `Some selected records or fields are not writable by your account.` The check runs again just before saving, so a permission revoked while the dialog was open stops the run.
- Each update carries the record's `updated_at` as `expectedUpdatedAt`. If someone saved the row after your table loaded, that row is refused and the batch stops there. `Reload remaining records` refetches the rows that are not saved yet, with fresh baselines, and you press `Update` again. Rows that saved stay saved.
- A model without an `updated_at` column is updated without that check. The shop's `Product` is one (`@Resource()` without `timestamps: true`), so a concurrent edit of a product wins or loses by arrival order. Declare `@Resource(timestamps: true)` if that matters.
- The batch is not one transaction. A refused row stops the run and leaves the earlier rows saved. The review says so before you start: `Records save individually. Completed records stay saved if a later record fails or you stop.`
- An unknown outcome (a dropped connection) blocks the run until `Check interrupted save` reads the receipt. Nothing is sent twice.
- `BeakBulkEdit.preview` refuses a change on the primary key, the same field twice, a field reached through a relation, an empty change list, and a selection that contains a record twice or one without an id. Each of those throws a `BeakConfigurationException`.

## Variations

| You want | Do this |
| --- | --- |
| The user to type the new value | `BeakBulkAction.edit` changes are fixed in code. Use a bulk model command with an `inputModel`: the dialog asks once and every record gets the same input. See [A row action](a-row-action.md). |
| A change that follows a business rule | A `BeakModelAction` with `values`. The server checks `availableWhen` per record, which a plain edit cannot. |
| A different icon | `icon:` on `BeakBulkAction.edit`. The default is a pencil. |
| Nothing but Dart in the panel | The plain `BeakBulkAction(key:, label:, icon:, onExecute:)`. It gets the selected records and a `BeakActionContext`, and to the server it is an ordinary update. |
| A bulk action in a composed list | Present it with `BeakActionPresentation` in `bulkActions:` of the list definition, see [Actions](../panel/actions.md). |

Field changes work on scalar fields of the edited model. To change a relation for many rows, use a model command that writes the foreign key.

## Verify

Both halves are covered by frontend package tests: the review shows `Title: Before → After`, checks capabilities, sends `expectedUpdatedAt`, and after a conflict keeps the completed rows.

```console
$ cd packages/beak_frontend
$ flutter test test/src/form/beak_import_view_test.dart --plain-name 'bulk'
All tests passed!
```

To try it by hand, run the shop, open Products, tick two rows and choose `Stop selling`. The review lists both, and after `Update 2 records` and closing the dialog, the `Active` column shows the new value on both rows.

## Continue reading

- [A multi-step form](a-multi-step-form.md) splits a long form into steps that validate one at a time.
- [Imports and bulk edits](../forms/imports-and-bulk-edits.md) covers the batch queue, recovery and the CSV side.
- [Actions](../panel/actions.md) arranges bulk actions next to record and global actions.
