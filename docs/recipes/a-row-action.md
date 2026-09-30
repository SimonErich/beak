---
title: A row action
description: Add a business transition such as Issue invoice as a BeakModelAction. The list row, the show page and the form get the button, and the server enforces the rule.
type: recipe
audience: [beginner, expert, agent]
status: stable
---

# A row action

You want a button on a record that moves it through a business rule: an invoice goes from draft to issued, and only from draft. The button belongs in the list, on the show page and in the form, and a script that skips the button must not skip the rule.

## Recipe

Declare the command once, as a static object on the model side. `availableWhen` says when it may run, `values` says what it writes:

```dart title="examples/clean_beak_config/lib/resources/invoices/models/invoice.dart"
--8<-- "examples/clean_beak_config/lib/resources/invoices/models/invoice.dart:invoiceIssueAction"
```

List it in the model's `behavior`. That list is the only registration, and there is no resource, screen or route to touch:

```dart title="examples/clean_beak_config/lib/resources/invoices/models/invoice.dart"
--8<-- "examples/clean_beak_config/lib/resources/invoices/models/invoice.dart:InvoiceBehavior"
```

Run `beak prepare`. The invoice list now has an `Issue invoice` button on every draft row, and the generated show page has the same button. A form page offers the commands the account may run next to Save. Issued invoices show `Mark paid` and `Cancel invoice` instead, because each command has its own `availableWhen`.

Clicking it asks for confirmation (the dialog shows `description`), loads the stored record, and sends a graph commit whose plan carries the command's name. Nothing else about the invoice has to be in the request.

## How it works

- `availableWhen` runs against the stored record, never a draft, in the panel to decide whether to draw the button and again on the server before anything is written. On the server a command that is not available fails with `This action is unavailable in the current state.`
- `values` are applied by the server after the command is accepted. A field that any command writes is closed to ordinary edits, so `issue` writes `issued` and nobody else can. A plan that writes `status` without naming a command is refused with `This field is controlled by the record workflow.` The shop's test sends exactly that (`forged-status`) and asserts it fails.
- `editableWhen` on the same behavior locks the ordinary fields of a non-draft invoice. The commands are not blocked by it: an issued invoice can still be marked paid, and a cancelled or paid one has no available command left.
- The receipt makes the click idempotent. Running the same plan again returns the stored receipt and does not write. If the answer is lost in transit, the panel reports the outcome as unknown and offers `Check Issue invoice`, which reads the receipt instead of submitting again.
- `allowOnCreate: true` lets the command run while the record is still being created, so a wizard can offer `Issue invoice` on its last step. Without it, the button appears only for a saved record.
- A list shows the button only when the resource allows edit (`canEdit`, model support and permissions). `editableWhen` is not consulted for it, which is why `Mark paid` shows on an issued invoice.

## Variations

| You want | Do this |
| --- | --- |
| The user to fill in something first | Give the command an `inputModel`, a small `BeakModel`. Beak opens a dialog and the rules run on the server too. |
| One button for a whole selection | Use a composed list: `bulkModelActions`, or `BeakActionPresentation.model(...)` in `bulkActions`, see [Actions](../panel/actions.md). Each record gets its own receipt. |
| A different label or icon in the list | `BeakActionPresentation.model(InvoiceActions.issue, label: ..., icon: ...)` in a composed list's `rowActions`. |
| A button that only runs Dart, with no business state | A `BeakRecordAction` in the resource's `recordActions`. The server never sees it. |
| A side effect in the same transaction | A graph preparer that calls `plan.runs(...)`, see [Graph business rules](../backend/graph-business-rules.md). |

A command with input is the same declaration plus one field. Foodio's `Add note` writes no column of the order at all:

```dart title="examples/foodio-adminpanel/lib/domain/order_behavior.dart"
--8<-- "examples/foodio-adminpanel/lib/domain/order_behavior.dart:FoodioAddNote"
```

The input model is an ordinary `BeakModel`. Its column rules are the dialog's validators and the server's checks:

```dart title="examples/foodio-adminpanel/lib/domain/_order_note_input.dart"
--8<-- "examples/foodio-adminpanel/lib/domain/_order_note_input.dart:FoodioNoteInput"
```

Choose the callback only when the click changes nothing the server needs to guard. `BeakRecordAction` runs in the panel with the panel's data source, so to the server it is an ordinary update.

## Verify

The shop's test walks an invoice through its lifecycle over HTTP: a forged status is refused, `issue` succeeds and its replay returns the same receipt, `markPaid` follows, and `cancel` on a paid invoice is refused and leaves the status at `paid`.

```dart title="examples/clean_beak_config/test/shop_api_test.dart"
--8<-- "examples/clean_beak_config/test/shop_api_test.dart:invoiceWorkflowTest"
```

```console
$ cd examples/clean_beak_config
$ flutter test test/shop_api_test.dart --plain-name 'invoice named actions'
00:00 +1: All tests passed!
```

The panel half, a presentation referring to its command by object and a form screen submitting with it, is in the frontend package:

```console
$ cd packages/beak_frontend
$ flutter test test/src/pages/model_action_references_test.dart
00:01 +5: All tests passed!
```

## Continue reading

- [A bulk edit](a-bulk-edit.md) changes one field on every selected row with one input.
- [Actions](../panel/actions.md) covers record, bulk and global actions and how they are arranged.
- [Behavior and actions](../reference/behavior-and-actions.md) lists every parameter of `BeakModelAction` and `BeakModelBehavior`.
