---
title: Model-owned transports
description: Bind an existing backend to Beak models, share live permissions, and configure commands and archive actions without duplicating panel wiring.
---

# Model-owned transports

An existing backend can remain responsible for its models, authorization and
business operations while Beak renders the admin panel. A `BeakModel` combines
resource metadata with an optional transport binding. A `BeakResource` selects
that model and adds presentation: labels, icons, layouts and actions. Register
the resource once in `BeakPanelConfig.resources`; the panel discovers its
transport automatically.

## Bind the model once

`BeakModel.dataSource` is optional. Return a stable `BeakDataSource` instance
from a bound model. The panel captures the binding when it registers the model,
then dispatches queries and mutations by the model's table name. No separate
resource-to-source registration list is needed.

| Model or panel configuration | Transport used |
| --- | --- |
| Model has `dataSource` | That model's bound transport |
| Model has no `dataSource` | The panel's HTTP transport |
| Explicit `BeakPanel(dataSource: fake)` | The supplied source for every model, including bound models |
| An external auth adapter is configured | Every model must be bound, or the panel must receive an explicit source |

The adapter owns converting backend DTOs to `BeakRecord`, translating supported
query operations, and calling the existing backend commands. Beak's data layer
continues to speak the same [data source interface](custom-data-sources.md).
Reject unsupported filters, sorts and operations explicitly instead of ignoring
them or returning an unfiltered result.

At the panel boundary, `BeakPanelConfig.mapException` can translate recognized
transport exceptions into localized `BeakException` values. Return `null` for
unrecognized exceptions so programming failures remain visible. Existing
`BeakException` values pass through unchanged. The same boundary covers record
reads, mutations, aggregates and edit-command loading.

## Keep capabilities and permissions on the model

`BeakModel.capabilities` declares what the transport implements. Its CRUD
operations are `read`, `create`, `update` and `delete`; archive uses the delete
operation. An adapter should omit unsupported commands from this set.

`BeakModel.permissions` declares whether the current account may use those
operations. Use live callbacks so an account refresh changes access without
rebuilding a separate permissions map for every resource:

```dart
BeakPermissions({
  BeakOperation.read: () => account.canReadUsers,
  BeakOperation.create: () => account.canWriteUsers,
  BeakOperation.update: () => account.canWriteUsers,
  BeakOperation.delete: () => account.canWriteUsers,
})
```

Omitted rules deny access. Models without a host policy retain
`BeakPermissions.allowAll()` for the standalone workflow. These are presentation
checks; backend endpoints still authorize every call.

A resource is visible only when read capability, read permission and its optional
`visibleWhen` rule all allow access. Create, edit and delete additionally require
the corresponding permission, capability and resource restriction. Resource
`canCreate`, `canEdit`, `canDelete` and their live `can*When` callbacks can narrow
access. A custom `createBuilder` or `editBuilder` can provide a workflow when the
ordinary single-record transport command is unavailable; it still requires the
model's permission.

## Separate read records from write commands

Read DTOs often contain joined names, calculated prices or audit snapshots that
must not be written back. A model may expose `createModel` and `editModel` for
separate command metadata. Beak builds the corresponding forms from those
models instead of the read columns. A source implementing `BeakEditDataSource`
supplies the edit command through `loadEditValues`; otherwise Beak loads the
record with `getOne`.

Model-owned command forms submit complete values by default, including explicit
nulls needed to clear a field. Ordinary record forms retain populated-value
submission. The resource's `formValueMode` can override this behavior. Configure
`createFields` and `editFields` only for presentation overrides or typed choice
loaders; field types and serialization belong to the generated command metadata.

For operations such as checkout that may create several records, use a custom
`createBuilder`. It preserves the resource route and panel shell while the
workflow calls the backend's existing business commands. Do not force a
multi-record result into the ordinary single-record `create` contract.

## Load detail records through their lookup operation

A detail page without additional relation requests calls `getOne(table, id)`.
Nested records already included in that response remain available to detail
blocks. This does not assume that a list endpoint accepts an arbitrary
primary-key filter.

When metadata requests eager relation loads, Beak currently uses a single
filtered query containing the primary key and those relation loads. A transport
using that path must support the query. Preloaded DTO relations alone do not
require extra remote relation metadata. Do not declare unsupported relation
queries or replace them with per-row requests.

## Configure domain archive behavior

```dart
BeakResource(
  model: userModel,
  icon: const BeakIconToken(OiIcons.users),
  deleteAction: const BeakArchiveAction(),
)
```

The action confirms, awaits the model transport's `delete` operation, then
refreshes and navigates to the list. The backend decides how archiving affects
status, associated records and audit history. Failed requests remain on the
current page. There is no optimistic removal or unsupported restore action.

Archive and archived-history browsing are separate capabilities. A transport
may support explicit history queries without exposing a history toggle in the
resource UI; declaring the archive action does not add one automatically.

Use `const BeakDeleteAction.confirmed()` for the same behavior with a Delete
label. See [Actions](../panel/actions.md) for the
completion and error contract.

## Verify the real integration

Test the configured resource and its actual model binding, replacing only the
backend client. Cover list, direct detail URLs, edit prefill and one meaningful
mutation. A fake generic data source alone cannot reveal mismatches between
allowed list filters and a backend's dedicated lookup endpoint.

Also cover a read-only account, a permission change during the session, failed
mutations, and confirmed archive. An explicit panel source remains useful for
isolated widget tests, but it deliberately overrides every model binding.

## Continue reading

- [Serverpod adapter](https://github.com/SimonErich/beak/blob/main/packages/beak_serverpod/README.md) documents the typed RPC transport.
- [Serverpod generator](https://github.com/SimonErich/beak/blob/main/packages/beak_serverpod_generator/README.md) documents generated model resources and endpoint conventions.
- [Custom data sources](custom-data-sources.md) defines the typed transport contract.
- [Actions](../panel/actions.md) covers confirmation, errors and custom operations.
- [Forms](../panel/forms.md) explains generated fields and command presentation.
