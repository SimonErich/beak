---
title: Actions
description: Add record, bulk and global actions to a resource, declare model commands once, arrange them in a list, and know which checks the server repeats.
type: guide
audience: [beginner, expert]
status: stable
---

# Actions

A resource already lists, opens, edits and deletes. This page is about the buttons you add on top: an action on one row, on a selection, on the page, and the model commands (issue an invoice, cancel an order) that carry their business rules with them.

## At a glance

Beak has two kinds of action, and the difference decides where the rule lives.

| Kind | Declared with | Runs on | Where the panel shows it |
| --- | --- | --- | --- |
| Record action | `BeakResource.recordActions`, a `BeakRecordAction` | One record | List rows, the generated show page, the header of a form page |
| Bulk action | `BeakResource.bulkActions`, a `BeakBulkAction` | The selected records, all at once | The selection bar of the list |
| Global action | `BeakResource.globalActions`, a `BeakGlobalAction` | The page | The list header, next to Create |
| Model command | `BeakModelBehavior.actions`, a `BeakModelAction` | One stored record, saved as a graph commit | List rows, show page, forms, and the selection bar of a composed list |

A record, bulk or global action is a callback. It runs your Dart in the panel with the panel's data source, and to the server it looks like an ordinary update. A model command is a declaration. The server knows its name, checks `availableWhen` on the stored record and applies its `values` itself, so a client that skips the button cannot skip the rule.

Use a callback for things that do not change business state (open a phone dialer, print a delivery note, jump to a page). Use a model command for every transition that has a rule.

## What is there before you add anything

A resource gets view, edit, delete and create without a line of code. They are not unconditional, though. Each one follows the same switches that guard its route.

| Built-in | Shown when |
| --- | --- |
| View | The account may read the resource |
| Edit | `canEdit`, the model supports update (or a custom edit screen exists), `BeakModel.permissions` allow update, and `editableWhen` holds for that record |
| Delete or archive (`deleteAction`) | `canDelete`, the model supports delete, permissions allow it, `deletableWhen` holds for that record, and the server does not report `canDelete: false` for this account |
| Create | `canCreate`, the model supports create (or a custom create screen exists), permissions allow it, and the server does not report `canCreate: false` for this account |
| Duplicate | Create is allowed and the resource sets `duplication` |

`canDelete: false` on a shop order hides the button. It does not stop the API: that is `deletableWhen` on the model, or a policy on the server. The panel also asks the server what the signed-in account may do (`GET /api/{table}/capabilities`), so a role without delete permission gets no trash icon and one without create permission gets no Create button, without a line of configuration. A list asks once for the table, which is exact for role rules. A read page asks for the record. See [Resources](resources.md) for the switches.

## Callback actions

A record action gets the record and a `BeakActionContext`. The smallest useful one, from the package tests:

```dart title="packages/beak_frontend/test/src/actions/actions_test.dart"
BeakRecordAction(
  key: 'ping',
  label: 'Ping',
  onExecute: (record, context) async => executed = record,
),
```

`BeakActionContext` carries what an action needs and nothing it should capture from a widget: the resource's `model`, the `dataSource`, the `router`, a `refresh` hook, and `overlays` for confirmations, dialogs and toasts (see [Overlays](overlays.md)). `refresh` is `null` on surfaces that have nothing to reload, so call it as `await context.refresh?.call()`.

Every action, whether it comes from a button, a row or a menu, goes through one function:

```dart title="packages/beak_frontend/lib/src/actions/beak_action_button.dart"
--8<-- "packages/beak_frontend/lib/src/actions/beak_action_button.dart:executeBeakAction"
```

In words: check permission, ask for confirmation when `requiresConfirmation` is set, run the callback, and hand a `BeakException` it throws to `onActionError` (or to an error toast when the resource has none). Any other exception propagates unchanged, because that is a bug and not a failure. The permission check runs a second time after the dialog closes, so a session that lost access while the dialog was open does not run the action. `BeakActionButton` ignores taps while its action is running, so a double click runs it once.

A custom record action on a list row does not receive the row as the table loaded it. Beak fetches the current record first (one `getOne` for a record, one batch read for several) and hands you that, so a callback never acts on a stale copy. The built-in view, edit, delete and archive act by id and skip the fetch.

### Two factories for common jobs

`BeakRecordAction.link` opens a phone dialer, mail composer, SMS composer or website. Only `http`, `https`, `mailto`, `tel` and `sms` are accepted, and a `uri` that returns `null` fails with a validation error instead of doing nothing. Foodio puts one on the order list only:

```dart title="examples/foodio-adminpanel/lib/resources/orders/order_resource.dart"
recordActions: [
  deliveryNoteAction(),
  BeakRecordAction.link(
    key: 'call-customer',
    roles: const {BeakScreenRole.list},
    label: 'Call customer',
    icon: OiIcons.phone,
    uri: (record) {
      final phone = OrderModel.contactPhone.readFrom(record);
      return phone == null || phone.isEmpty
          ? null
          : Uri(scheme: 'tel', path: phone);
    },
  ),
],
```

`BeakRecordAction.document` prints a fresh, authorized snapshot of the saved record (never an unsaved draft) and fails with `Save the record before printing.` for a record without an id. `deliveryNoteAction()` in the same folder builds one; [Printable record documents](../forms/record-documents.md) covers the document itself.

```dart title="examples/foodio-adminpanel/lib/resources/orders/actions/order_documents.dart"
BeakRecordAction deliveryNoteAction() => BeakRecordAction.document(
  key: 'delivery-note',
  label: 'Print delivery note',
  roles: const {BeakScreenRole.list, BeakScreenRole.read},
  document: BeakRecordDocument(
```

### Roles decide the surface

`BeakRecordAction.roles` says which generated pages show the action: `list`, `read`, `edit`. The default is all three, `link` defaults to `list` and `read`. A create page has no saved record, so a record action is never drawn there and `create` is not in the default. The role is presentation only. A form page follows its live mode, so an in-place Edit switches the read actions for the edit ones without a route change.

Two limits worth knowing. A form page shows record actions only for a saved record, so the `create` role never shows one. And wizard and full-screen forms have no generated page frame, so they show none at all. A model command can still be placed there with `BeakFormActions` (see [Screens and form layouts](../reference/screens-and-layouts.md)), a callback action cannot.

## Model commands

A command is declared once, as a static object, and every screen refers to that object. The shop's invoice has three; this is the first.

```dart title="examples/clean_beak_config/lib/resources/invoices/models/invoice.dart"
/// Issues a draft invoice and locks its contents.
static final issue = BeakModelAction(
  name: 'issue',
  allowOnCreate: true,
  label: 'Issue invoice',
  description:
      'Issue this invoice and lock its customer, prices, discounts and taxes.',
  availableWhen: (record) =>
      InvoiceModel.status.readFrom(record) == InvoiceStatus.draft,
  values: [
    BeakValueBehavior.derived(
      field: InvoiceModel.status,
      resolve: (_) => InvoiceStatus.issued,
    ),
  ],
);
```

The model lists its commands in `behavior`, and that list is the only registration:

```dart title="examples/clean_beak_config/lib/resources/invoices/models/invoice.dart"
--8<-- "examples/clean_beak_config/lib/resources/invoices/models/invoice.dart:InvoiceBehavior"
```

`editableWhen` locks the whole invoice once it leaves `draft`. And because `issue`, `markPaid` and `cancel` all write `status` in their `values`, the status field is never editable by hand, in the form or through the API. Running `issue` is allowed, typing `issued` into the field is refused.

A command may take typed input. Its `inputModel` is an ordinary `BeakModel` with columns, defaults and rules, and Beak opens a dialog for it. Foodio's "Add note" is the small case:

```dart title="examples/foodio-adminpanel/lib/domain/order_behavior.dart"
/// Adds an internal note without changing the order.
static const addNote = BeakModelAction(
  name: 'addNote',
  label: 'Add note',
  inputModel: OrderNoteInputModel(),
);
```

`OrderNoteInputModel` (`examples/foodio-adminpanel/lib/domain/_order_note_input.dart`) is a small `BeakModel` with a `body` string column, required by default and capped at 2000 characters. The same rules run in the dialog and on the server. A command without an `inputModel` opens a confirmation instead, showing its `description`.

### What a click does

1. The runner loads the record afresh and checks the command: the account's capabilities allow it, and `availableWhen` holds for the stored record.
2. Beak asks: a confirmation dialog, or the input dialog for an `inputModel`.
3. The command goes out as a graph commit with a receipt, the same path a form Save takes.
4. The server repeats the checks and applies `values` before it writes anything.

If the answer to the commit is lost (a dropped connection, a closed laptop), the outcome is unknown, and the panel says so instead of guessing. The command stays in the runner's `unresolved` list, and a banner above the page offers `Check <label>`. That button reads the original receipt. It never submits a second time, and running the same command again does the same. The banner survives navigation and is scoped to the signed-in principal.

### Where commands show up

| Surface | What appears | Condition |
| --- | --- | --- |
| List row | A `model:<name>` action | The resource allows edit, and `availableWhen` holds for that row |
| Show page (generated) | One button per available command | The resource allows edit |
| Form page | Buttons beside Save, or inline where `BeakFormActions` places them | The account may run it and it is available; on create, only commands with `allowOnCreate` |
| Selection bar | Bulk commands of a composed list | Listed in `bulkModelActions`, or as `BeakActionPresentation.model` in `bulkActions` |

A bulk command asks once ("Apply Cancel order to 3 selected records? Each record is saved independently."), collects the input once, and then runs record by record. Every record has its own receipt. One failure does not stop the others, and the failures come back as one message naming each id.

## Arranging actions in a composed list

A plain list shows every action as an icon button in the row. A composed list (`BeakTableScreen.definition`) puts them in the row menu instead, and lets you decide. `rowActions` and `bulkActions` take `BeakActionPresentation` objects that only change how an existing action is drawn. Execution and policy stay shared. Foodio's order list:

```dart title="examples/foodio-adminpanel/lib/resources/orders/list/order_list_screen.dart"
rowActions: [
  const BeakActionPresentation(
    key: 'view',
    label: 'View order',
    icon: OiIcons.eye,
    group: 'record',
  ),
// ...
  BeakActionPresentation.model(
    OrderActions.addNote,
    label: 'Add internal note',
    icon: OiIcons.messageSquare,
    group: 'record',
  ),
  BeakActionPresentation.model(
    OrderActions.cancel,
    label: 'Cancel order',
    icon: OiIcons.circleX,
    destructive: true,
    group: 'destructive',
  ),
],
bulkActions: [
  BeakActionPresentation.model(
    OrderActions.sendPaymentLink,
    label: 'Send payment links',
    icon: OiIcons.send,
  ),
  const BeakActionPresentation(key: 'export', icon: OiIcons.download),
  BeakActionPresentation.model(
    OrderActions.cancel,
    icon: OiIcons.circleX,
    destructive: true,
    selectionLabel: (count) => 'Cancel $count orders',
  ),
],
```

The `key` names the action: `view`, `edit`, `delete` (or `archive`), `duplicate`, `export`, the `key` of your own action, or `model:<name>` for a command, which `BeakActionPresentation.model` derives from the object so nobody types it.

| `placement` | Where the action goes |
| --- | --- |
| `overflow` (default) | An entry in the row menu |
| `icon` | A compact icon button in the row |
| `primary` | A visible labelled button in the row |
| `column` | Nowhere in the row: only an action column can show it |

Adjacent menu entries with different `group` values get a separator. `labelValue` gives a label that reads the record (foodio's `Call <customer name>`), and `selectionLabel` takes the selected count.

Here is the part that catches people. Once `rowActions` is set, an action you leave out of it is not dropped, it is moved to `column` placement. It vanishes from the menu, and stays reachable only from a `BeakTableColumn.action` cell. Forget `delete` in the list and the row loses its delete button without a warning.

That column is how foodio's "Next step" cell works: a selector field says which command applies to the row, and the cell shows it as a button.

```dart title="examples/foodio-adminpanel/lib/resources/orders/list/order_list_presets.dart"
BeakTableColumn.action(
  key: 'next_step',
  label: 'Next step',
  widthInPixels: 188,
  selector: BeakValueBinding.field(OrderModel.nextAction),
// ...
```

Presets, saved views and the rest of the composed list are on [Composed lists and query state](composed-lists.md).

## Bulk edits and duplication

`BeakBulkAction.edit` applies typed field changes to a selection. The shop uses it to switch products on and off:

```dart title="examples/clean_beak_config/lib/resources/products/product_resource.dart"
bulkActions: [
  BeakBulkAction.edit(
    key: 'activate-products',
    label: 'Make available',
    changes: [BeakFieldChange(ProductModel.active, true)],
  ),
  BeakBulkAction.edit(
    key: 'deactivate-products',
    label: 'Stop selling',
    changes: [BeakFieldChange(ProductModel.active, false)],
  ),
],
```

A `BeakFieldChange` pairs a typed field with a value of the field's Dart type: `true` for a bool column, a `BeakDecimal` for money. The action loads the selection, previews validation, and saves each record with its own receipt. Progress, cancellation and interrupted saves are in [Imports and bulk edits](../forms/imports-and-bulk-edits.md).

Duplication is a switch plus a spec of what to copy:

```dart title="examples/clean_beak_config/lib/resources/products/product_resource.dart"
duplication: BeakDuplicationSpec(
  relations: [ProductModel.attributes, ProductModel.variants],
  reset: [ProductModel.sku, ProductVariantModel.stock],
),
```

Shared references (the category) are kept. `relations` lists the owned collections to copy with new identities, and must be has-many relationships that the record owns. `reset` clears extra fields on the root or on a copied child. Beak always clears the id, timestamps, soft-delete marker, unique and password columns, and derived, snapshot and initial values (initial ones are regenerated). `includeNestedOwned` (default `true`) also copies what the copies own.

Nothing is saved. The Duplicate action opens the create form prefilled with the draft, and the copy exists when someone presses Save. In the shop, `ProductModel.sku` is not unique, so Beak would copy it and the spec clears it. `ProductVariantModel.sku` is unique and is cleared without being listed; `stock` is listed because a copy should not inherit the count.

## Delete and archive

`deleteAction` decides what the delete button does.

| Value | Behavior |
| --- | --- |
| `BeakDeleteAction()` (default) | The row disappears at once and an undo snackbar reading `Record deleted.` (in the panel language) stays for 5 seconds. The delete reaches the data source when the window passes. Deleted from a record page, the router then returns to the list that page was opened from, with its search, filters, sort and page; deleted from a list row, the list stays where it is. A delete the server refuses, or cannot confirm, puts the row back and shows the server's message in an error toast |
| `BeakDeleteAction.confirmed()` | Asks first, waits for the server, then refreshes and leaves the way the default delete does. No undo. A refusal keeps you on the record |
| `BeakArchiveAction()` | The confirmed delete under the key `archive` and the label Archive. It calls the data source's delete, so what archiving means (soft delete, a status change) is the backend's decision. No restore is implied |

Pick the confirmed form whenever the server owns cleanup you cannot take back, or refuses deletes in some states. Starting a second undoable delete commits the first one immediately, so the undo window is per action, not a queue.

## Permissions: what hides, what enforces

| Layer | Mechanism | Effect |
| --- | --- | --- |
| Panel presentation | `canCreate`, `canEdit`, `canDelete`, `BeakModel.permissions`, the server's `canCreate` and `canDelete` capabilities, `editableWhen`, `deletableWhen`, `availableWhen`, `roles` | Buttons are not drawn, and routes redirect to `/403` |
| Panel guard | `BeakActionContext.checkPermission`, before and after the confirmation | A stale button reports a `BeakAuthorizationException` (a toast unless `onActionError` takes it) and does not run |
| Server | `BeakPolicies`, `BeakActionPolicy.canExecuteAction`, the command's `availableWhen`, `editableWhen`, `deletableWhen` | The write is refused |

A callback action has no name on the server. If it calls `context.dataSource.update`, that is an ordinary update, checked as one. `BeakActionPolicy` sees model commands only, which is one more reason to make a business transition a command. Panel checks make the UI honest, and the server is the only place they are binding: see [Auth and policies](../backend/auth-and-policies.md).

## Rules and limits

- `BeakActionPresentation` finds its action by `key`. A `rowActions` or `bulkActions` entry whose key matches no action of the resource makes the panel throw a `BeakConfigurationException` at startup, naming the list and the keys the resource offers, so a typo in `'delete'` cannot pass as a missing button.
- `requiresConfirmation` uses `overlays.confirm`, which renders the confirm button destructively when the action's `color` is `BeakColor.error`. For a custom message, skip the flag and call `context.overlays.confirm(...)` inside `onExecute`.
- Global and bulk actions appear on the list only. A bulk callback receives all selected records in one call, and a bulk model command runs once per record.
- Bulk model commands appear only in a composed list (`BeakTableScreen.definition`). Without one, a selection has only the actions in `bulkActions`.
- A row's model action is drawn while `availableWhen` holds for the row as the table loaded it. The click re-checks against the stored record.
- The list offers model commands, on rows and on a selection, only when the resource allows edit.
- On list rows and on the show page, `deletableWhen` hides the button of a `BeakDeleteAction` (including `.confirmed()`) and of a `BeakArchiveAction`.
- The banner for an unknown command outcome belongs to the principal that started it. Signing in as someone else hides it.
- `BeakRecordAction.link` accepts only `http`, `https`, `mailto`, `tel` and `sms`. Relative, file and executable URIs are rejected.

## Verify it

Callbacks, confirmations, the built-in delete and the row actions of a list are covered by the frontend package tests:

```console
$ cd packages/beak_frontend
$ flutter test test/src/actions test/src/pages/resource_actions_test.dart
00:05 +33: All tests passed!
```

The runner tests are the ones that pin the "never submitted twice" promise:

```console
$ flutter test test/src/actions/beak_model_action_runner_test.dart
00:00 +0: unknown commands recover the same save without another confirmation or dispatch
00:00 +1: concurrent invocations coalesce and another principal cannot reuse the pending record
00:00 +2: All tests passed!
```

A resource with `canCreate`, `canEdit` and `canDelete` off loses the buttons and the write routes:

```console
$ flutter test test/src/panel/beak_panel_test.dart --plain-name "read-only resources hide writes"
00:00 +0: generated routes read-only resources hide writes and reject write routes
00:01 +1: All tests passed!
```

The shop tests its duplication spec, including which selling identities it resets:

```console
$ cd examples/clean_beak_config
$ flutter test test/shop_resource_test.dart --plain-name "product duplication"
00:00 +0: product duplication preserves catalog values and resets selling identities
00:00 +1: All tests passed!
```

## Reference

| Symbol | Kind | Notes |
| --- | --- | --- |
| `BeakAction` | Sealed base | `key`, `label`, `icon`, `color`, `requiresConfirmation` |
| `BeakRecordAction` | `final class` | `onExecute(record, context)`, `roles`; factories `.link` and `.document` |
| `BeakBulkAction` | `final class` | `onExecute(records, context)`; factory `.edit(key, label, changes, icon)` |
| `BeakGlobalAction` | `final class` | `onExecute(context)` |
| `BeakViewAction`, `BeakEditAction`, `BeakCreateAction` | Built-ins | Navigate to the route |
| `BeakDeleteAction`, `BeakArchiveAction` | Built-ins | See Delete and archive |
| `BeakActionContext` | `final class` | `buildContext`, `model`, `dataSource`, `router`, `refresh`, `stageRemoval`, `onError`, `canExecute`, `checkPermission`, `reportError`, `overlays` |
| `BeakActionButton` | Widget | Renders one action; `compact` gives the icon-only variant |
| `BeakActionPresentation` | `final class` | `key`, `label`, `labelValue`, `selectionLabel`, `icon`, `destructive`, `group`, `placement`; `.model(action)` |
| `BeakActionPlacement` | Enum | `icon`, `primary`, `overflow`, `column` |
| `BeakModelAction` | `final class` | `name`, `label`, `description`, `availableWhen`, `inputModel`, `allowOnCreate`, `values` |
| `BeakModelActionRunner` | Panel service | `execute(...)`, `unresolved` (`ReadonlySignal<List<BeakPendingModelAction>>`) |
| `BeakDuplicationSpec` | `final class` | `relations`, `reset`, `includeNestedOwned` |
| `BeakFieldChange<T>` | `final class` | `field`, `value`; checked against the field's Dart type |

The context every callback receives:

```dart title="packages/beak_frontend/lib/src/actions/beak_action.dart"
--8<-- "packages/beak_frontend/lib/src/actions/beak_action.dart:BeakActionContext"
```

Full signatures with defaults, and the server-side checks of a command in order, are on [Behavior and actions](../reference/behavior-and-actions.md). The model side (value lifecycles, `editableWhen`) is on [Model behavior](../models/behavior.md).

## Continue reading

- [Overlays](overlays.md) the confirmations, dialogs and toasts an action reaches through its context.
- [Composed lists and query state](composed-lists.md) presets, saved views and export around the row and bulk actions.
- [Model behavior](../models/behavior.md) value lifecycles and the commands a model declares.
- [Imports and bulk edits](../forms/imports-and-bulk-edits.md) progress and recovery of a bulk edit.
