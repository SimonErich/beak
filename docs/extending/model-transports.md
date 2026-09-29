---
title: Model-owned transports
description: Bind a BeakModel to an existing backend, with live permissions, separate create and edit commands and a confirmed archive action.
type: guide
audience: [expert]
status: stable
---

# Model-owned transports

After this page you can let an existing backend keep its models, authorization and business operations while Beak renders the panel, by binding a transport to the model instead of wiring a data source into the panel.

A `BeakModel` is metadata plus five optional hooks. A `BeakResource` selects the model and adds presentation: labels, icons, layouts, actions. You register the resource once in the panel. The panel finds the model's transport by itself, so there is no second list mapping resources to sources.

The hooks live on a hand-written `BeakModel`. A schema class with `@Resource` forwards only two of them from static getters (`permissions` and `capabilities`), and the names `dataSource`, `createModel` and `editModel` are reserved on it. `beak prepare` lists a hand-written model in the generated registry when it is a `const` class with a zero-argument constructor, anywhere under `lib/`. `ServerpodResource` is a `BeakModel` that sets all five hooks, built at runtime from a Serverpod client, and the Serverpod generator writes its subclasses for you.

## At a glance

```dart title="packages/beak_frontend/test/src/panel/model_configuration_test.dart"
--8<-- "packages/beak_frontend/test/src/panel/model_configuration_test.dart:BoundModel"
```

| Hook on `BeakModel` | Type | Default | What the panel does with it |
| --- | --- | --- | --- |
| `dataSource` | `BeakDataSource?` | `null` | Routes every query and write for `table` to it. Return a stable instance. |
| `capabilities` | `Set<BeakOperation>` | read, create, update, delete | Hides what the transport cannot do. Archive uses `delete`. |
| `permissions` | `BeakPermissions` | `BeakPermissions.allowAll()` | Live yes-or-no callbacks per operation. Missing rules deny. |
| `createModel` | `BeakModel?` | `null` | The create form is built from it. |
| `editModel` | `BeakModel?` | `null` | The edit form is built from it. |

## Bind the model once

The panel builds one `ModelBeakDataSource` from its registry. It picks a source per table when it registers the models:

| Situation | Transport used for the model |
| --- | --- |
| The model has a `dataSource` | That source |
| The model has none | The panel's HTTP source, `HttpBeakDataSource` |
| `BeakPanel(dataSource: source)` is set | `source`, for every model, bound ones included |
| The config has an auth adapter (external authentication) | No HTTP source exists, so every model must be bound or the panel needs an explicit `dataSource`. Otherwise startup throws `External authentication requires bound models or a data source.` |

```dart title="packages/beak_frontend/test/src/panel/model_configuration_test.dart"
--8<-- "packages/beak_frontend/test/src/panel/model_configuration_test.dart:bindingWithoutRegistrationTest"
```

That test registers one bound model, no `BeakClient` appears in the container, and a table nobody bound answers with a `BeakConfigurationException`.

Your adapter converts backend DTOs to `BeakRecord`, translates the query operations it supports and calls the existing commands. What it may not do is quietly ignore a filter or a sort it cannot honour: reject it with a typed exception, or the panel shows an unfiltered list as if it were the answer. The full method contract is in [Custom data sources](custom-data-sources.md).

### One error boundary

Every call passes through one wrapper. A `BeakException` goes through untouched. Any other `Exception` goes to `BeakPanelConfig.mapException`, which returns a localized `BeakException` for the failures it recognises and `null` for the rest, so a programming error stays loud:

```dart title="packages/beak_frontend/lib/src/data/model_beak_data_source.dart"
--8<-- "packages/beak_frontend/lib/src/data/model_beak_data_source.dart:run"
```

The wrapper covers record reads, mutations, aggregates, uploads and edit-command loading. `BeakPanel(mapException: ...)` takes the mapper directly, and a panel built from a `BeakPanelConfig` sets it there, because `config:` together with another everyday option throws.

### Which source method the panel calls

| Panel action | Bound source implements `BeakCommitDataSource` | Otherwise |
| --- | --- | --- |
| Form save (create or edit) | `commit(plan)`, resumed with `recover(saveId)` | A staged save: `create` and `update` in dependency order, stopping at the first failed or uncertain write. The same fallback runs when one save touches models bound to different sources |
| Delete and archive | A one-operation `commit` that keeps the model's soft delete | `delete(table, id)` |
| Record page (show, edit) | One `query` filtered on the primary key, with the relation loads the layout needs | The same |
| Edit page of a model with `editModel` | `loadEditValues(table, id)` when the source implements `BeakEditDataSource` | `getOne`, then the form prefills from the read record |

## Capabilities and permissions

`capabilities` says what the transport implements: `BeakOperation.read`, `create`, `update`, `delete`. An adapter without an update endpoint drops `update` from the set and the edit action disappears.

`permissions` says whether the current account may use those operations. Use callbacks that read the account each time, so a refresh changes access without rebuilding anything:

```dart title="packages/beak_frontend/test/src/panel/beak_panel_test.dart"
--8<-- "packages/beak_frontend/test/src/panel/beak_panel_test.dart:WriteGatedNoteModel"
```

The resource combines the two with its own switches. Every column of the table is required for the action to show, and every route redirects to `/403` when its own check fails:

| Check | Passes when |
| --- | --- |
| `isVisible` (list and show routes, navigation entry) | `capabilities` has read and `permissions` allows read |
| `allowsCreate` | visible, `canCreate` is true, `capabilities` has create (or a custom create screen exists), `permissions` allows create |
| `allowsEdit` | visible, `canEdit` is true, `capabilities` has update (or a custom edit screen exists), `permissions` allows update |
| `allowsDelete` | visible, `canDelete` is true, `capabilities` has delete, `permissions` allows delete |

```dart title="packages/beak_frontend/test/src/panel/model_configuration_test.dart"
--8<-- "packages/beak_frontend/test/src/panel/model_configuration_test.dart:permissionsGovernTest"
```

`canCreate`, `canEdit` and `canDelete` on `BeakResource` narrow access further. They never widen it.

A custom screen fills in an operation the transport does not offer. `BeakCustomResourceScreen(roles: {BeakScreenRole.create}, builder: ...)` supplies the create workflow while the resource keeps its route, its shell and the model's `create` permission. Use one when checkout creates an order, its lines and a payment, a result the single-record `create` contract cannot express. [Custom screens](../panel/custom-screens.md) covers the widget side.

These are presentation checks. Panel permissions hide UI, and the backend must still authorize every call.

## Separate read records from write commands

Read DTOs often carry joined names, calculated prices or audit snapshots that must not be written back. A model can expose `createModel` and `editModel` with a different column set, and Beak builds the create and edit forms from those.

```dart title="packages/beak_frontend/test/src/panel/model_configuration_test.dart"
--8<-- "packages/beak_frontend/test/src/panel/model_configuration_test.dart:ProjectedModel"
```

Three rules come with it:

- The command model reports the same `table` as the read model. A draft rejects fields from any other table.
- Command forms submit every field, including the nulls that clear one (`BeakFormValueMode.complete`). A plain model submits what is populated. The resource pages pick the mode from the model, and a custom screen can set `BeakConfiguredForm(valueMode: ...)` itself, for example `BeakFormValueMode.changes` for a partial-update endpoint.
- The edit form is prefilled with `loadEditValues` when the bound source implements `BeakEditDataSource`, which lets the adapter project the read DTO into the command shape. Without it, the record's `getOne` result fills the form.

Field types and serialization belong to the command model. A `BeakFormScreen` in the resource's `screens` changes presentation only.

## Load detail records through query

A record page loads its record with a single query on the primary key, and asks for the relations its layout uses in the same request:

```dart title="packages/beak_frontend/lib/src/form/beak_form_session.dart"
--8<-- "packages/beak_frontend/lib/src/form/beak_form_session.dart:recordLoad"
```

```dart title="packages/beak_frontend/test/src/pages/beak_resource_pages_test.dart"
--8<-- "packages/beak_frontend/test/src/pages/beak_resource_pages_test.dart:showPageQueryTest"
```

So a transport needs a `query` that accepts an `eq` filter on the primary key with `perPage: 1`, and that either loads the requested relations or rejects them. `getOne` serves row actions and the edit-command fallback, not the record page. If your backend has a dedicated lookup endpoint and a list endpoint that cannot filter by id, the adapter maps that query shape onto the lookup call. Do not declare relation loads the backend cannot serve, and do not replace them with one request per row.

## Archive instead of delete

Backends that archive rather than delete configure the resource with the confirmed action:

```dart
BeakResource(
  model: userModel,
  icon: const BeakIconToken(OiIcons.users),
  deleteAction: const BeakArchiveAction(),
)
```

This block is illustrative (it is not a repository file, and `userModel` is your model). `BeakArchiveAction` confirms, awaits the transport's delete operation, then refreshes and returns to the list. The backend decides what archiving does to status, related records and audit history. A refused request keeps the user on the record and reports through the resource's `onActionError`. There is no optimistic removal, no undo and no restore action.

Archiving and browsing archived rows are separate capabilities. A transport can support history queries without the resource showing a history toggle, and declaring the archive action does not add one. `const BeakDeleteAction.confirmed()` is the same behaviour with a Delete label. [Actions](../panel/actions.md) has the completion and error contract.

## Rules and limits

| Rule | Enforced where | What it means |
| --- | --- | --- |
| Bind in a hand-written `BeakModel` | Generator | A schema class cannot set `dataSource`, `createModel` or `editModel`. |
| Return a stable `dataSource` | Client | The panel reads it when it registers the models, not per request. A getter that builds a new source on every call gets no second chance. |
| An explicit `BeakPanel(dataSource:)` overrides bindings | Client | Useful for isolated widget tests, and wrong for a test that means to exercise the binding. |
| Permissions and capabilities only hide UI | Client | The backend authorizes every call. `BeakPermissions` denies an operation with no rule. |
| The command model shares the `table` | Client | `createModel` and `editModel` describe the write shape of the same table. |
| Unsupported operations fail loudly | You | Throw `BeakValidationException` or `BeakConfigurationException` for a filter, sort or operation the transport cannot serve. The Serverpod bridge does this per operation. |
| Record pages depend on `query` by id | Client | See above. A transport that cannot filter by primary key cannot show record pages. |

## Verify it

Test the configured resource with its real model binding, replacing only the backend client underneath. Cover a list, a direct detail URL, an edit prefill and one meaningful mutation. A generic fake source cannot reveal a mismatch between the filters your list endpoint accepts and what the record page asks it for.

Also cover a read-only account, a permission change during the session, a failed mutation and a confirmed archive. `BeakPanel(dataSource:)` stays useful for isolated widget tests because it deliberately overrides every binding.

```console
$ cd packages/beak_frontend
$ flutter test test/src/panel/model_configuration_test.dart
00:01 +6: edit projection and failures use the shared transport boundary
00:01 +7: an explicit panel source overrides bound transports for tests
00:01 +8: All tests passed!
```

## Reference

| Symbol | Library | Role |
| --- | --- | --- |
| `BeakModel.dataSource`, `capabilities`, `permissions`, `createModel`, `editModel` | `package:beak/beak.dart` | The five hooks. |
| `BeakOperation` | `package:beak/beak.dart` | `read`, `create`, `update`, `delete`. |
| `BeakPermissions(Map<BeakOperation, bool Function()>)`, `BeakPermissions.allowAll()` | `package:beak/beak.dart` | Live permission rules. |
| `BeakEditDataSource`, `BeakCommitDataSource` | `package:beak/beak.dart` | Optional source capabilities the panel uses when present. |
| `BeakPanelConfig.mapException` | `package:beak/panel.dart` | Maps recognised transport exceptions. |
| `BeakResource.canCreate`, `canEdit`, `canDelete`, `deleteAction`, `screens` | `package:beak/panel.dart` | Resource-level narrowing and workflows. |
| `BeakArchiveAction`, `BeakDeleteAction.confirmed()` | `package:beak/panel.dart` | Confirmed, awaited deletion. |
| `BeakCustomResourceScreen` | `package:beak/panel.dart` | A widget replacing one or more resource routes. |
| `BeakFormValueMode` | `package:beak/panel.dart` | `populated`, `complete`, `changes`. |

Sources: `packages/beak_core/lib/src/model/beak_model.dart`, `packages/beak_core/lib/src/model/beak_permissions.dart`, `packages/beak_frontend/lib/src/data/model_beak_data_source.dart`, `packages/beak_frontend/lib/src/panel/beak_resource.dart`, `packages/beak_serverpod/lib/src/resource.dart`.

## Continue reading

- [Bridge resources](../serverpod/bridge/resources.md) `ServerpodResource`, the production user of these five hooks.
- [Generating bridge resources](../serverpod/bridge/generator.md) `BeakModel` subclasses generated from a Serverpod client.
- [Actions](../panel/actions.md) confirmation, errors and custom operations.
- [Form screens](../forms/form-screens.md) generated fields and command presentation.
- [Using Beak widgets standalone](using-beak-widgets-standalone.md) the panel's widgets outside a panel.
