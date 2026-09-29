---
title: Custom data sources
description: Implement the ten methods of BeakDataSource to back a panel or a server with any store, and prove it with the shipped contract suite.
type: guide
audience: [expert]
status: stable
---

# Custom data sources

After this page you can implement `BeakDataSource` for a store Beak has never heard of (another ORM, a REST gateway, a fake for tests), plug it into a panel or a server, and prove it behaves with the contract suite Beak ships.

Your schema classes, columns and queries describe what you want, never which database answers. One interface keeps that true, and it has ten methods. [The data source seam](../architecture/data-source-seam.md) covers why the interface is shaped this way. This page covers how to write one.

## At a glance

| Where a source plugs in | How | What it replaces |
| --- | --- | --- |
| One model | `BeakModel.dataSource` returns it | That model's transport only. See [Model-owned transports](model-transports.md). |
| The whole panel | `BeakPanel(dataSource: source)` | Every transport, bound models included. A test passes a fake here, and a host with its own transport passes it in production (the Serverpod admin does). |
| The server | `BeakServer(dataSource: source)` | The worm source behind the generated REST API, with the limits in [Rules and limits](#rules-and-limits). |

You implement the interface, and the layers above cannot tell your source from `WormDataSource` (backend), `HttpBeakDataSource` (panel), `ServerpodDataSource` or `InMemoryBeakDataSource` (in `package:beak/testing.dart`).

## The interface

`BeakDataSource` comes from `package:beak/beak.dart`, the library with no Flutter and no ORM in it. It speaks typed records (`BeakRecord`), query specs (`BeakQuerySpec`) and pages (`BeakPage`). Here it is, whole:

```dart title="packages/beak_core/lib/src/data/beak_data_source.dart"
--8<-- "packages/beak_core/lib/src/data/beak_data_source.dart:BeakDataSource"
```

Every method names a table by its stored name. Callers take that name from the generated model (`const ProductModel().table`), so your source receives strings and never has to guess how they were made.

### What each method owes the caller

The contract suite checks most of this, and the column says which part it checks.

| Method | Returns | The contract | In the suite |
| --- | --- | --- | --- |
| `query` | A `BeakPage` | Applies `spec.filter`, `sorts`, `search` and `pagination`. Reports the true `total`. A page past the end is empty, not an error. Hides soft-deleted rows unless `withTrashed`. Resolves every `relationLoads` entry. | Yes, relation loads included (plain, filtered and nested) when you pass `relationModels`. |
| `getOne` | A record or `null` | Returns `null`, never throws, when the row is absent or soft-deleted. | Yes |
| `create` | The stored record | Echoes database-assigned values (id, timestamps) and keeps an id it was given. | Yes |
| `update` | The stored record | A partial patch leaves other fields alone. Throws `BeakNotFoundException` when the id is gone. | Yes |
| `delete` | Nothing | Throws `BeakNotFoundException` for a missing id. Soft-deletes when the model does, unless `force` is set. | Yes |
| `restore` | The restored record | Clears the soft-delete marker. Throws `BeakNotFoundException` for a live or unknown id, and `BeakValidationException` when the model does not soft-delete. | Yes |
| `batchGet` | A list of records | One query, not one per id. Skips unknown ids. An empty list returns nothing. | Results, not the query count |
| `attach`, `detach` | Nothing | Link or unlink to-many rows: pivot rows for belongs-to-many, foreign keys for has-many. Attaching an existing link is skipped. Detaching a link that is not there, or a has-many row another parent owns, changes nothing. | Yes, when you pass `relationModels` |
| `aggregate` | A `num` | Count, sum or average of the matching rows. Returns `0` over an empty set, never `null`. | Yes |

## Three rules

Break one and the layers above start leaking assumptions about your store.

1. **Throw typed exceptions, never your store's.** Map a missing record to `BeakNotFoundException`, an unknown table or relation to `BeakConfigurationException`, a duplicate to `BeakConflictException`. The backend's error-mapping middleware and the panel's repository catch the sealed `BeakException` family and nothing else, so a raw driver error becomes a 500. See [Results and errors](../concepts/results-and-errors.md).
2. **Never leak store types.** No worm rows, no S3 responses, no ORM entities cross the boundary. In, out and thrown: only Beak types.
3. **Eager-load, never lazy-load.** `query` resolves every relation named in `spec.relationLoads` before it returns. Reading an unloaded relation is a design error in Beak, so nothing exists to lazy-load against.

The wrapper worth copying for rule 1 is the one `ServerpodDataSource` puts around every call. It lets Beak's own exceptions through and hands everything else to an optional `mapException` callback. When the callback returns null, the original exception propagates, so a programming error stays visible:

```dart title="packages/beak_serverpod/lib/src/data_source.dart"
--8<-- "packages/beak_serverpod/lib/src/data_source.dart:serverpodGuard"
```

## Optional capabilities

The ten methods are the floor. Panel features that need more ask the source for an extra interface, and degrade in the way the last column says when it is missing.

| Interface | Adds | Without it |
| --- | --- | --- |
| `BeakCommitDataSource` | `commit(plan)`, `recover(saveId)`, `commitCapabilities` | Form saves run as a staged commit over plain CRUD: writes in dependency order, stopping at the first failed or uncertain write, with no rollback. |
| `BeakEditDataSource` | `loadEditValues(table, id)` | The edit form prefills from `getOne`. |
| `BeakCapabilityDataSource` | `capabilities(table, {id})` | Every field is readable and writable, every action executable. |
| `BeakValidationDataSource` | `validateRecord(request)` | The panel validates asynchronous rules itself, with `query`. |
| `BeakSummaryDataSource` | `summary(spec)` | Summary blocks throw `This data source does not support summaries.` |
| `BeakExportDataSource` | `export(spec, ...)` | CSV export throws `This data source does not support CSV exports.` |
| `BeakUploadClient`, `BeakManagedUploadClient`, `BeakUploadUrlClient` | `upload`, `discardUpload`, `uploadUrl` | Upload columns throw `The data source for "<table>" does not support uploads.` |

`HttpBeakDataSource` implements all of them by delegating to the typed REST client, which makes it the readable example. Its declaration lists the interfaces, and each method forwards to `client`:

```dart title="packages/beak_frontend/lib/src/data/http_beak_data_source.dart"
--8<-- "packages/beak_frontend/lib/src/data/http_beak_data_source.dart:HttpBeakDataSource"
```

Your source swaps `client` for whatever answers your data: a SQL connection, a GraphQL client, a map. The signatures do not move.

A source used as a decorator is the smallest implementation of all. `BeakRecordingDataSource` (in `package:beak/testing.dart`) records each of the ten calls and forwards it to an inner source. Because it is a `base class`, a test overrides the single operation it wants to break, as the shop's `_FailingAggregate` does.

## Prove it with the contract suite

"Implement ten methods" is not a specification. The interface has edges that only bite in production: `getOne` returning null instead of throwing, `update` throwing when the row is gone, `aggregate` returning 0 over nothing, soft deletes hiding from `query` but not from `withTrashed`. `runBeakDataSourceContract` is the executable version, and every source Beak ships runs it. This is `WormDataSource`:

```dart title="packages/beak_backend/test/src/data/worm/worm_data_source_contract_test.dart"
--8<-- "packages/beak_backend/test/src/data/worm/worm_data_source_contract_test.dart:contract"
```

`_AuthorWithNotesModel` is the fixture's authors table with a has-many back to its notes, which lets the run load a relation inside a relation.

| Argument | Meaning |
| --- | --- |
| `registry`, `model` | The registry and the model whose table the suite seeds and queries. |
| `create` | Builds a fresh source for each test. |
| `seed` | Puts records into your store. The suite cannot know how: the in-memory source has `seed`, a SQL one needs SQL, a Serverpod one needs a session. |
| `sortableTextColumn`, `numericColumn` | Optional. Defaults to the first string column and the first int or decimal column. Without a numeric column the sum and average tests are skipped. |
| `relationModels` | Optional. The models whose relationships the relation groups exercise: eager loads (plain, filtered, nested), `attach` and `detach`. Their related tables must be in `registry` and seedable through `seed`, which also carries the foreign keys. Left empty, the suite runs one skipped test in place of the relation groups, so the gap shows in the output. |
| `seedLinks` | Optional. Writes many-to-many links the way your store holds them (pivot rows). Without it the suite links through your own `attach`, so a broken `attach` fails the load tests too. |

```console
$ cd packages/beak_backend
$ dart test test/src/data/worm/worm_data_source_contract_test.dart
00:00 +75: WormDataSource satisfies the BeakDataSource relation contract authors relations notes then comments (nested load) a filter on the first level still loads the second
00:00 +76: All tests passed!
```

A green run is your source saying it belongs. It does not say everything, because of the limits listed next.

## Wire it in

=== "The panel"

    `BeakPanel` takes a `dataSource`, and `registerBeakDependencies` under it takes the same. When the parameter is set it replaces every transport, including the ones models bind for themselves:

    ```dart title="packages/beak_frontend/lib/src/di/beak_locator.dart"
    --8<-- "packages/beak_frontend/lib/src/di/beak_locator.dart:registerDataLayer"
    ```

    `overrideBindings: dataSource != null` is that switch. The panel wraps your source in a `ModelBeakDataSource`, which adds the error mapping and the change stream, so your source does not implement `BeakMutationSource` itself. To give one model its own source and leave the rest on HTTP, bind it on the model instead. That is the subject of [Model-owned transports](model-transports.md).

=== "The server"

    `BeakServer` takes any `BeakDataSource`. The generated host builds a `WormDataSource` and hands it to `BeakServerDefaults`, and `build()` accepts a `dataSource:` (and a `storage:`) to replace what the host resolved, so `lib/server.dart` keeps the rest of the wiring:

    ```dart title="lib/server.dart"
    import 'package:beak/server.dart';

    BeakServer beakServer(BeakServerDefaults defaults) =>
        defaults.build(dataSource: MyDataSource());
    ```

    `MyDataSource` is yours. The block is illustrative (it is not a repository file) and compiles against a fresh `beak create` project. Every generated CRUD route then runs against your source, with the limits below. `defaults.dataSource` is still the worm source, and the host still connects the database first.

## Rules and limits

| Rule | Enforced where | What it means |
| --- | --- | --- |
| Atomic graph commits need a `WormDataSource` | Server: `POST /api/commits` is mounted for every source, and atomic only for it | Over your source the route saves `staged`: every operation is authorized first, then written through your `create`, `update`, `delete`, `attach` and `detach` in dependency order, stopping at the first failure, with no rollback. Receipts are kept in memory (the newest 1024), so a restart forgets them. The default panel's saves and deletes work. |
| Behavior and shared relation rules need one too | Server: the router refuses to start | A model with `behavior`, an `editableWhen`, or a record rule that loads relations makes `BeakServer` throw `Shared relationship validation requires an atomic graph data source.` |
| `preparePlan` and `finalizePlan` need one | Server: the same guard | `Graph preparation requires a Worm data source.` A plain `graphOnly` list works over any source. |
| The host still connects its database | Server: `BeakServeHost.serve` | It initialises the `DATABASE_URL` database before it calls your `beakServer`, even if your source never uses it. |
| The relation groups are opt-in | Test | `attach`, `detach` and `relationLoads` are tested for the models you name in `relationModels`. The suite seeds related rows with generated values in the foreign key columns it does not wire, so a store that enforces foreign keys on those tables fails at seed time. A relationship from a table to itself is skipped. |
| The suite checks soft deletes only if the model has them | Test | Pass a model with `softDeletes` to run the soft-delete group, and a model without to run the rejection test. |

```dart title="packages/beak_backend/lib/src/endpoints/beak_resource_router.dart"
--8<-- "packages/beak_backend/lib/src/endpoints/beak_resource_router.dart:commitRoutes"
```

## The Serverpod seam

`BeakModel` is metadata: columns, relationships, the display key and the primary key, none of it named to worm. That keeps the seam open from both sides. `beak_serverpod` supplies `ServerpodDataSource` over typed, generated client operations, and its `ServerpodResource` is a `BeakModel` that binds the source itself, so declaring a resource registers its transport. The Serverpod section covers both paths:

- [Bridge resources](../serverpod/bridge/resources.md) shows the frontend-only bridge.
- [Choosing an integration](../serverpod/choosing-an-integration.md) compares the bridge with the admin app inside a Serverpod workspace.

## Verify it

Run the suite against your source with `dart test`, then pump your panel's widgets against it by passing it as `dataSource:`. While the store is not ready, `InMemoryBeakDataSource` is the reference behaviour. It runs the same suite (`packages/beak_test/test/src/in_memory_beak_data_source_test.dart`) and honours the whole spec, so a green widget test means the widget is right, and not that a fake ignored the filter.

The suite's missing-row probes use the text id `no-such-id`, which a store with serial integer ids cannot take. The Serverpod example runs the suite on a throwaway table with a text id for that reason, in `examples/serverpod/bookshop_server/test/integration/beak/support/contract_note.dart`.

## Reference

| Symbol | Library | Role |
| --- | --- | --- |
| `BeakDataSource` | `package:beak/beak.dart` | The ten-method interface. |
| `BeakCommitDataSource`, `BeakEditDataSource`, `BeakCapabilityDataSource`, `BeakValidationDataSource`, `BeakSummaryDataSource`, `BeakExportDataSource` | `package:beak/beak.dart` | Optional capabilities. |
| `BeakException` family | `package:beak/beak.dart` | `BeakValidationException`, `BeakNotFoundException`, `BeakAuthenticationException`, `BeakAuthorizationException`, `BeakConfigurationException`, `BeakStorageException`, `BeakConflictException`. |
| `runBeakDataSourceContract`, `InMemoryBeakDataSource`, `BeakRecordingDataSource` | `package:beak/testing.dart` | The suite and the two reference sources. |
| `BeakServer(dataSource: ...)`, `BeakServerDefaults` | `package:beak/server.dart` | Serving a source. |
| `BeakPanel(dataSource: ...)` | `package:beak/panel.dart` | The panel-wide override. |

Sources: `packages/beak_core/lib/src/data/`, `packages/beak_test/lib/src/data_source_contract.dart`, `packages/beak_backend/lib/src/endpoints/beak_resource_router.dart`.

## Continue reading

- [Model-owned transports](model-transports.md) bind a source to one model instead of the whole panel.
- [The data source seam](../architecture/data-source-seam.md) how `WormDataSource` turns a spec into SQL.
- [The query contract](../architecture/query-contract.md) the serializable `BeakQuerySpec` your `query` receives.
- [Testing](../shipping/testing.md) the in-memory source, the recording decorator and the suite in context.
- [Custom storage drivers](custom-storage-drivers.md) the same pluggable pattern for files.
