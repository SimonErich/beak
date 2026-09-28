---
title: Actions
description: Expose model transitions and typed bulk edits with automatic validation and persistence.
---

# Actions

Declare business transitions in `BeakModelBehavior.actions`. Beak renders available actions in configured forms and resource tables, collects optional typed arguments, validates the candidate and submits the named graph operation.

```dart title="examples/clean_beak_config/lib/resources/invoices/models/invoice.dart"
--8<-- "examples/clean_beak_config/lib/resources/invoices/models/invoice.dart"
```

The shop issues drafts, marks issued invoices paid, and cancels eligible documents. Terminal documents cannot be reopened by editing their status. Issuing a new document can create its lines and perform the transition in the same transaction. A replay uses the same receipt, so the transition is not executed twice.

## Permissions and failure

Availability is evaluated for presentation and rechecked on the server against the stored baseline. An optional `BeakActionPolicy` further authorizes action names for the authenticated account. The source’s `executableActions` capability allowlist expresses that account permission and whether the action can run during creation; it does not replace workflow availability. A rejected action leaves the draft reviewable. Validation and uncertain transport outcomes use the same paths as Save.

## Bulk configuration

`BeakBulkAction.edit` takes a key, label and typed `BeakFieldChange` values. The product resource demonstrates activation and deactivation of a selection. Beak loads selected records, previews shared validation, preserves revisions and executes a separate graph per record. See [Imports and bulk edits](import-and-bulk-edit.md) for progress and recovery semantics.

## List placement and recovery

A composed list uses `BeakActionPresentation` to place configured commands inline or in an overflow menu. Its `bulkModelActions` executes the named transition for selected records, with shared arguments and one receipt per record. The panel runner retains uncertain outcomes across mounted route changes and exposes recovery through a pending-action banner. Recovery reuses the original save identity; it does not dispatch a replacement operation. This queue is scoped to the current mounted panel and principal, rather than browser-reload persistence. See [Composed lists](composed-lists.md) for the complete query and action contract.

## Custom actions

`BeakRecordAction`, `BeakBulkAction` and `BeakGlobalAction` remain presentation extension points for application-specific tasks. Their callbacks receive `BeakActionContext`, including the current model, source, router, overlays and refresh hook. They do not replace shared model actions for server-owned business transitions. Standard view, edit, create, delete and archive actions remain available.

For delivery notes, receipts and similar record documents, use `BeakRecordAction.document`. Typed field bindings and collection columns define the content; Beak reloads the authorized persisted record, applies the panel's formatting and opens a print window or portable HTML download. See [Printable record documents](record-documents.md).

## Contact and web links

`BeakRecordAction.link` opens a typed URI using the shared platform launcher.
It checks current action permission and reports a missing destination or handler
through the normal typed error path. For example:

```dart
BeakRecordAction.link(
  key: 'call-customer',
  label: 'Call customer',
  icon: OiIcons.phone,
  roles: const {BeakScreenRole.list},
  uri: (record) {
    final phone = OrderModel.contactPhone.readFrom(record);
    return phone == null ? null : Uri(scheme: 'tel', path: phone);
  },
)
```

The shared `launchBeakUri` boundary supports absolute HTTP(S), `mailto`, `tel`
and `sms` destinations. Relative, file and executable schemes are rejected.
It calls the platform handler directly, preserving browser user activation;
platform failures become safe `BeakValidationException` values. Native hosts
must supply the platform plugin registration used by `url_launcher`. Advanced
hosts and tests can inject a `BeakUriLauncher` without replacing action policy.
A link action defaults to list/read roles; explicit roles avoid duplicating a
contact control already present in a detail layout.

## Continue reading

- [Model behavior](../models/behavior.md)
- [Imports and bulk edits](import-and-bulk-edit.md)
- [Printable record documents](record-documents.md)

## Presentation by resource role

`BeakRecordAction.roles` selects the generated surfaces that expose a custom
action. It defaults to all roles. Reuse the same `BeakScreenRole` values as screen
definitions; for example, `roles: {BeakScreenRole.list, BeakScreenRole.read}`
keeps a document action in list menus and read headers while editing focuses on
Save and Cancel. Shared read/edit forms follow their live mode, including an
in-place Edit or Cancel without a route change. Resource authorization and
server permissions are still checked independently.
