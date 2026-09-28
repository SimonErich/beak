---
title: Imports and bulk edits
description: Preview typed CSV input and mass changes through the graph save protocol.
---

# Imports and bulk edits

Use `BeakImportView` for an embedded CSV import and `BeakBulkAction.edit` for a resource-table selection. Both validate first, display a review and preserve per-record save identities during execution.

## CSV import

`BeakImportDefinition` names the model and an explicit list of generated scalar fields. Headers default to field labels and can be renamed with typed field keys. Parsing supports quoted commas, doubled quotes, CRLF and multiline text. Numeric, boolean, date and semantic inputs use typed codecs, and shared model rules validate each candidate.

The Operations page embeds a category import:

```dart title="examples/clean_beak_config/lib/operations.dart"
--8<-- "examples/clean_beak_config/lib/operations.dart:shopOperations"
```

Preview is bounded to 500 rows by default and two million characters. The view displays the first 20 rows while validating every row. Malformed headers, invalid cells and permission failures prevent submission. Derived fields are evaluated for validation but are not sent as caller-owned values.

## Typed bulk changes

`BeakBulkEdit.preview` takes a model, selected records and `BeakFieldChange` values. Every candidate is validated against its original record; save plans retain `updated_at` revisions. The reusable `BeakBulkEditView` displays before and after values. Resource configuration can use `BeakBulkAction.edit` to open that view automatically.

```dart title="examples/clean_beak_config/lib/resources/products/product_resource.dart"
--8<-- "examples/clean_beak_config/lib/resources/products/product_resource.dart"
```

## Execution and recovery

`BeakBatchRepository` commits one graph at a time. Each record retains the adapter's transaction guarantee; the whole batch is not one transaction. Completed rows remain saved if another row fails. Stop takes effect between records, after the in-flight receipt is collected. Resume skips confirmed rows.

A lost response is uncertain, not proof that nothing was saved. Check the interrupted save before continuing. Reusing a save identity with different content is rejected. The view keeps its batch plan and receipts while mounted; this batch queue is not persisted across a browser reload. Long-running background imports should persist their plans and receipts in an application-owned job service.

## Correcting interrupted batches

Each row keeps its own save identity. Resume skips confirmed rows and stops at
an unknown outcome until receipt recovery resolves it. Equivalent parent-widget
rebuilds preserve the mounted queue. Changing the source or batch configuration
stops continuation after the current write; the new configuration needs an
explicit new review, and unknown receipts must be resolved first.

After a definite rejection or cancellation, **Edit remaining rows** unlocks the
CSV. Keep saved rows unchanged and in their original positions. Preview checks
that constraint before accepting corrections; confirmed plans keep their original
identities, while unsaved rows receive fresh identities. Bulk edits offer
**Reload remaining records** to review the latest baselines and revisions before
retrying. Both paths recheck current field permissions before submission.

The built-in queue lives while the view is mounted. It is not a persistent batch
job or a browser-reload checkpoint. Keep the view open until pending writes and
unknown outcomes are resolved. A custom host that needs recovery across unmounts
must retain its plans, receipts and execution state outside the view.

Blank CSV cells mean explicit null; omitted columns remain absent so model
defaults can apply. Import cells use domain input text: decimal money amounts,
ISO dates and timestamps, and `true`/`false` booleans. Export formats are separate
contracts: raw exports may contain integer storage units, while formatted exports
may contain display symbols. Map those values explicitly before reimporting;
the importer does not infer the export mode. Quoted fields, embedded newlines
and a leading UTF-8 byte-order mark are supported.

## Continue reading

- [Actions](actions.md)
- [Drafts and review](drafts-and-review.md)
