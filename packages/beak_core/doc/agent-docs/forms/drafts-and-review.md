# Drafts, review and conflicts

> Resume unfinished forms from local storage, review changes before they are sent, recover an interrupted save and resolve a clash with a newer version.

After this page you can let people leave a form and come back to it, show them what a save will change, and say what happens when a save is interrupted or someone else edited the same record.

These are separate mechanisms, and none is on by default. `drafts` and `reviewBeforeSave` are one parameter each on the screen. Recovery of an interrupted save works in the open page without them, and across a reload only with `drafts`. Conflict detection needs a column on the model. A form without `drafts` keeps its edits only while the page is open.

## At a glance

The shop stores unfinished forms with a small factory, and the product form switches drafts and the review dialog on:

```dart title="examples/clean_beak_config/lib/shop_drafts.dart"
import 'package:beak/panel.dart';
import 'package:flutter/foundation.dart';

final BeakDraftStore _shopDraftStore = kIsWeb
    ? const BeakBrowserDraftStore()
    : BeakMemoryDraftStore();

/// Resumable drafts for this single-user, local demonstration panel.
///
/// An authenticated host supplies its stable user and tenant identity here.
BeakFormDrafts shopDrafts(String form) => BeakFormDrafts(
  store: _shopDraftStore,
  key: form,
  context: 'clean-shop:local-demo',
  schemaVersion: 2,
);
```

```dart title="examples/clean_beak_config/lib/resources/products/product_resource.dart"
BeakFormScreen(
  roles: const {
    BeakScreenRole.read,
    BeakScreenRole.create,
    BeakScreenRole.edit,
  },
  layout: productForm(),
  drafts: shopDrafts('product'),
  reviewBeforeSave: true,
),
```

| Concern | Switch | Lives in | Survives a reload |
| --- | --- | --- | --- |
| Unfinished edits | `drafts` | A `BeakDraftStore` you choose | Yes, until retention runs out |
| A look before sending | `reviewBeforeSave`, `showChangeBar` | The session | No, it is a view of the draft |
| A save whose result is unknown | `drafts` plus a source with durable receipts | The store, and the server's receipt table | Yes |
| A newer version on the server | The model's `updated_at` | The server | Not applicable |

## Local drafts

`BeakFormDrafts` names the store and the identity of the form:

| Parameter | Default | Meaning |
| --- | --- | --- |
| `store` | required | A `BeakDraftStore`: `read`, `write` and `remove` on a string document |
| `key` | required | A stable name for this form definition, such as `'product'` |
| `context` | required | Who this draft belongs to: the signed-in user and the tenant, never an access token |
| `schemaVersion` | `1` | Bump it when the form's meaning or shape changes, and old drafts are dropped |
| `retention` | 7 days | Drafts older than this are discarded on load |
| `debounce` | 300 ms | Delay before a run of edits is written |

The storage key combines `context`, `key`, the table and the record id, so each record has its own draft, and every new-record form of that resource shares one. Two users of the same browser get two drafts, provided `context` tells them apart. A wrong `context` is how drafts leak between accounts, so build it from something the user cannot change.

Two stores ship. `BeakBrowserDraftStore` writes to `localStorage` and exists on the web only. `BeakMemoryDraftStore` lives as long as the process, which is why the shop uses it off the web and why its drafts do not survive an app restart. A native app that needs durable drafts implements `BeakDraftStore` over its own storage.

While the form is dirty, edits are written after the debounce. A clean form removes its draft, a confirmed save removes it, and Discard removes it. The draft holds field values, staged and removed rows, records created inline and inline command arguments. It never holds a password, and it never holds file bytes: a staged upload is stored as empty, and the form asks you to pick the file again after a resume.

### Resuming

Open a form that has a stored draft and the page shows a card, "An unfinished draft is available", with Resume draft and Discard saved draft. Until you choose, saving and moving between wizard steps are refused, and edits do not overwrite the stored candidate. An expired draft, or one written for another `schemaVersion` or `context`, is removed with a notice instead.

Resume does not paste the old values over the record. It re-applies your changes on top of the record as it is now, so a field that only the server changed keeps the server's value. A field that both sides changed to different values becomes a conflict, see below.

A wizard's header can offer the same thing on demand. `BeakFormHeader` with a draft store shows Save as draft and a "Draft saved" time, and writes nothing to the server.

## When a save is interrupted

A save is one `POST /api/commits` with a save id, and the server keeps the receipt. A lost response is therefore recoverable, but only if the client knows which save to ask about. This is what the session does:

1. Before sending, with `drafts` configured, it writes a recovery snapshot: the plan's shape, its save id and the mapping to local rows. Passwords, file bytes and command arguments are left out. If that write fails, nothing is sent and the edits stay, with the message "The recovery snapshot could not be stored. Nothing was submitted."
2. It sends the plan. If the response is lost, every operation is recorded as unknown and the form freezes.
3. The form asks the server for the receipt of the same save id (`GET /api/commits/<saveId>`). On a reload, this happens by itself, from the snapshot. "Check save status" repeats it by hand.
4. The receipt decides. Nothing is ever sent again on its own.

| Receipt | What the form does |
| --- | --- |
| Complete | Applies the real ids, clears the snapshot and the draft |
| Some operations unapplied | Keeps the unapplied edits as a correctable draft. The banner says how many changes were saved, and the button reads "Save remaining changes" |
| Some operations unknown | Stays frozen: no edits, no discard, no new save, until the outcome is known. The one exception is `receiptLost`, see Rules and limits |

The snapshot survives retention and a `schemaVersion` bump, because the original transaction still has to be checked. The receipt has to survive too. `HttpBeakDataSource` reads it from the server's receipt table, which is durable. A source that is not commit-capable falls back to receipts held in memory, and those are gone after a reload.

Without `drafts` there is no snapshot. The unknown state and the "Check save status" button still work in the open page, but a reload forgets which save was in flight.

## Reviewing changes

`reviewBeforeSave: true` inserts a step between Save and the request. The dialog lists each change: a field with its before and after values, a created record, a removed row. Back returns to the form and Continue sends the save. Password fields show no values.

The dialog is built from three members of the session:

| Member | Returns |
| --- | --- |
| `session.reviewChanges` | Every field and relationship change, as `BeakDraftChange` objects with a path, a label, a kind (`update`, `create`, `detach`, `delete`) and the before and after values |
| `session.reviewChangeCount` | The number of operations, where a new row counts once |
| `session.reviewChangeSummary` | One label per operation (the field label, or `Items added`, `Items deleted`, `Items removed` for rows), joined with a middle dot |

The count and the summary come from the same list without the fields inside newly created rows. They feed the change bar (`showChangeBar`), which pins "N unsaved changes", "N fields need attention", Discard changes and Save. A ghost button "Review changes" opens the dialog on demand when neither the change bar nor the rail is in use.

`showInspector: true` adds "Inspect form" for development. It lists each field with its visibility, editability, origin, dependencies and rules, without values, so opening it exposes no secret. `session.explain()` returns the same list.

## Concurrent edits

Two protections stack.

The server is the authority. When an edit loads a record that has `updated_at`, the plan carries it as `expectedUpdatedAt`, and the write is conditional on it. If the stored stamp moved, the operation is refused with "The record changed since it was loaded." and the whole graph rolls back. [Graph commits](../architecture/graph-commits.md#conditional-writes) has the mechanics. The precondition needs the column: `@Resource(timestamps: true)` adds it. Foodio's order has it, and so does the shop's invoice. The rest of the shop's models do not, so their edits are last write wins.

The client merges. When a stored draft is resumed, when "Compare with latest version" is pressed after a refused save, or when `session.refreshForConflicts()` is called, the session fetches the record again and lines up three versions: the baseline the draft started from, your value and the server's value. A field that only you changed keeps your value, a field that only the server changed takes the server's, and a field that both changed to different values turns into a card:

- "Your draft: ..." and "Latest version: ..." for the field,
- Keep draft and Use latest.

A row you edited that someone else deleted becomes a conflict as well: keep it as a new record, or discard it. Save stays disabled until every conflict is resolved, and `resolveConflict(path, useRemote:)` records the choice.

Duplicating a record is a separate feature: the copy opens as an unsaved create form. It is configured on the resource, see [Actions](../panel/actions.md#bulk-edits-and-duplication).

## Rules and limits

| Rule | Behavior |
| --- | --- |
| Drafts are opt in | No `drafts`, no local storage, no snapshot |
| Web storage | `BeakBrowserDraftStore` throws `UnsupportedError` off the web. Choose the store by platform, as `shopDrafts` does with `kIsWeb` |
| What is excluded | Passwords and file bytes are never stored. A resumed upload needs picking again |
| Retention | Applies to unsent drafts only. A pending save is kept until its receipt is known |
| Recovery needs a durable receipt | The server's receipt table survives a restart. The in-memory fallback does not, and a reload against it leaves the save `receiptLost` instead of guessing |
| Which failures are unknown | A dropped connection, a timeout or an opaque 5xx is recorded as unknown with the reason `responseUnavailable`, because it cannot prove the server wrote nothing. A refusal the server states before it writes, an HTTP 401, 403, 404, 409, 413 or 422, is recorded as `unapplied` with the reason `rejected`, and the form stays editable. "Check save status" on an unknown save that the server never received (its receipt lookup answers 404) resolves to `unapplied` with the reason `notReceived`, so the form is free again. That holds for a source with durable receipts and for a save the same page sent. After a reload against a source that keeps receipts in memory only, the 404 proves nothing: the save stays unknown with the reason `receiptLost`, the banner says so, and the form offers Discard changes once you have checked whether the record was saved |
| Stale writes | A refused save arrives as an unapplied receipt, not as an error. The form shows the receipt banner with the server's message and keeps the draft. When a refusal carries the `conflict` code, the banner also offers "Compare with latest version", which calls `refreshForConflicts()`: the record is fetched again, your edits are merged onto it, the refusal is cleared and the next save carries the fresh version. Saving the same edits again without comparing would send the same stale version and be refused again |
| Conflict detection needs `updated_at` | Models without it are last write wins |
| Frozen forms | While a save is unknown, editing, discarding and a second save are refused. A `receiptLost` save allows Discard changes only |
| A stored draft waiting | Save stays disabled until the stored draft is resumed or discarded, so a tap never does nothing silently |
| Checking a settled save | `recover()` does nothing once every outcome is known. Asking for the receipt of a save that was applied would overwrite the edits made since with the values it saved |
| Server rules | Validation and concurrency are enforced by the server. The draft is a convenience of the client |
| Wording | The banner, button and dialog texts quoted here are the English ones. A German panel translates most of them, and some stay English, see [Formatting and localization](../theming/formatting-and-localization.md) |

## Verify it

The draft store, resume, snapshot and recovery paths are covered by package tests:

```bash
cd packages/beak_frontend
flutter test test/src/form/resumable_draft_test.dart
```

The run ends with `All tests passed!`. To see the pieces, run Foodio (API on port 8081), start a new order, fill the first step, then reload the page: the "An unfinished draft is available" card offers to resume it. The order wizard stores its draft in the browser.

## Reference

| Symbol | Where it is documented |
| --- | --- |
| `BeakFormDrafts`, `BeakDraftStore`, `BeakMemoryDraftStore`, `BeakBrowserDraftStore` | `packages/beak_frontend/lib/src/form/beak_form_drafts.dart` |
| `BeakDraftChange`, `BeakDraftChangeKind`, `BeakDraftConflict`, `BeakFieldExplanation` | `packages/beak_frontend/lib/src/form/beak_form_drafts.dart` |
| `reviewBeforeSave`, `showInspector`, `drafts`, `showChangeBar` | [Screens and form layouts](../reference/screens-and-layouts.md#beakformscreen) |
| `BeakFormHeader` | [Screens and form layouts](../reference/screens-and-layouts.md#beakformheader) |
| `BeakFormSession` members: `reviewChanges`, `refreshForConflicts`, `resolveConflict`, `recover`, `explain` | `packages/beak_frontend/lib/src/form/beak_form_draft_runtime.dart`, `packages/beak_frontend/lib/src/form/beak_form_session.dart` |

## Continue reading

- [Graph commits](../architecture/graph-commits.md) plans, receipts, idempotent replay and conditional writes on the server.
- [Uploads and galleries](uploads-and-galleries.md) what happens to staged files when a save fails or is unknown.
- [Imports and bulk edits](imports-and-bulk-edits.md) the same receipts, one per record.
- [Results and errors](../concepts/results-and-errors.md) how failures become typed values.
