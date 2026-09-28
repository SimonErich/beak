---
title: Drafts, review and conflicts
description: Resume local work, inspect pending changes and resolve concurrent edits.
---

# Drafts, review and conflicts

`BeakFormDrafts` gives a configured form a draft store and a stable namespace. `reviewBeforeSave` adds a change review before committing; `showInspector` exposes the session's resolved fields and pending graph for development.

```dart title="examples/clean_beak_config/lib/shop_drafts.dart"
--8<-- "examples/clean_beak_config/lib/shop_drafts.dart"
```

## Persistence and identity

The draft key combines screen identity, table, record identity and application-supplied context. The document carries the schema version. Include the tenant and authenticated user in that context. Browser storage is provided through `BeakBrowserDraftStore`; native applications can supply the `BeakDraftStore` interface. The shop's native fallback is in-memory and does not survive process exit.

Persistence is debounced and retention is configurable. For an **unsubmitted draft**, restore is offered explicitly after loading current data. A schema-version mismatch is rejected with a notice, and an expired unsubmitted draft is removed. A confirmed successful save or explicit discard removes an ordinary saved draft.

Passwords and local upload bytes are excluded. An uncommitted local file needs reselection after restoration. Browser draft storage is local application data; applications handling sensitive content should choose an appropriate store and retention policy.

## Submission and interrupted saves

Before dispatching a save, Beak stores a redacted recovery snapshot containing the draft graph, save identity and operation-to-draft mapping. If that storage write fails, **the save is not dispatched** and the current edits remain available. This prevents a reload from losing the identity of a write that may already have reached the server.

On reload, a pending submission is restored as a frozen form. Beak automatically calls `recover(saveId)` with the original save identity; **Check save status** remains available when the result is still uncertain. Stored operations are never automatically resubmitted, and editing or discarding the pending submission stays blocked until its outcome is known.

A complete receipt clears the stored document and applies the confirmed record identities. Definite unapplied outcomes remain as correctable drafts; when a staged save partially succeeds, the confirmed operations are reconciled before the remaining changes become editable. A lost response keeps the recovery snapshot instead of turning the submission into a new save.

Pending save identities survive normal draft retention expiry and schema-version mismatches so that the original transaction can still be checked. This exception applies to pending submissions, not ordinary unsubmitted drafts. Recovery requires a `BeakCommitDataSource` that can retrieve the original receipt; use a provider with durable receipts for recovery across process or server restarts.

Command arguments are excluded from the stored recovery metadata, alongside passwords and local file bytes. If a command was definitely unapplied and needs to be invoked again, its argument form collects those values again.

## Review and concurrent edits

`session.reviewChanges` describes pending field and relationship changes. `refreshForConflicts` compares the draft's baseline, the local candidate and the latest remote record. Non-overlapping remote changes can be incorporated; a field changed on both sides requires an explicit local or remote choice. `resolveConflict` records that choice and advances the baseline revision. Saving remains blocked until conflicts are resolved.

Restored nested drafts preserve owned rows, relationship identities and pending operations. The server still checks revisions at commit time; a clean client comparison does not bypass concurrency control.

## Duplicate an existing graph

Resource `duplication` configuration enables a Duplicate action that opens an
unsaved create form. `BeakDuplicationSpec` names owned collections to copy and
additional fields to reset. Shared references remain references; identities,
revisions, unique values, secrets and snapshots are cleared. The product resource
copies specifications and variants, including variant attributes, while resetting
stock and SKU values. The administrator reviews the result before Save.

## Controlled escape hatches

`BeakFormReader` is the read-only reactive interface used by conditions and calculations. `BeakDraftScope` supplies typed editing and relationship operations for custom controls. The custom variant builder uses it to stage rows while Save, Cancel, validation and review stay under Beak's control. `session.explain()` exposes diagnostics without requiring application code to recreate form state.

## Continue reading

- [Forms](forms.md)
- [Dynamic attributes and variants](../models/dynamic-attributes-and-variants.md)
