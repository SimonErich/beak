---
title: The data source seam
description: How BeakDataSource lets the panel and the server run the same operations over worm, HTTP, or a future Serverpod transport.
---

# The data source seam

After this page you can name the single interface every Beak data operation goes through, explain why the worm-backed server and the HTTP-backed panel are interchangeable, and describe exactly what a future `ServerpodDataSource` would and would not touch.

Beak has one data boundary, and it is an interface, not a class. `BeakDataSource` lives in `beak_core`, speaks only `beak_core` types, and both sides of Beak implement it: the server over the worm ORM, the panel over REST. That symmetry is the reason worm never leaks into the frontend and HTTP never leaks into a service, and it is the reason a new transport can slot in without editing the code that uses it.

The interface is `packages/beak_core/lib/src/data/beak_data_source.dart`; the two implementations are `packages/beak_backend/lib/src/data/worm/worm_data_source.dart` and `packages/beak_frontend/lib/src/data/http_beak_data_source.dart`.

## The interface

`BeakDataSource` is ten methods, all phrased in `beak_core` vocabulary: `BeakQuerySpec`, `BeakRecord`, `BeakPage`, `BeakAggregateSpec`, and primitive ids. No `Model`, no `Request`, no `http.Client`.

| Method | Returns | Job |
| --- | --- | --- |
| `query(spec)` | `Future<BeakPage<BeakRecord>>` | Run a spec, eager-loading every relation it declares. |
| `getOne(table, id)` | `Future<BeakRecord?>` | One record by primary key, or `null`. |
| `create(table, data)` | `Future<BeakRecord>` | Insert and return the stored record. |
| `update(table, id, data)` | `Future<BeakRecord>` | Update by id; throws `BeakNotFoundException` if absent. |
| `delete(table, id, {force})` | `Future<void>` | Soft-delete when the model opts in, else hard-delete. |
| `restore(table, id)` | `Future<BeakRecord>` | Clear a soft-delete marker and return the row as it now reads. |
| `batchGet(table, ids)` | `Future<List<BeakRecord>>` | Fetch many ids in one query (the dedup path). |
| `attach(table, id, relationKey, relatedIds)` | `Future<void>` | Link to-many relations. |
| `detach(table, id, relationKey, relatedIds)` | `Future<void>` | Unlink to-many relations. |
| `aggregate(spec)` | `Future<num>` | Compute a count/sum/avg over matching rows. |

`restore` is the one operation that deliberately reaches past the soft-delete scope, because the row it wants is by definition already outside it. It throws `BeakValidationException` when the model does not soft-delete at all: reporting success for a row that was hard-deleted would be a lie.

The interface's own doc comment states the contract implementations sign up to:

```dart title="packages/beak_core/lib/src/data/beak_data_source.dart"
/// Backend handlers and services speak only this interface (`WormDataSource`
/// is the default implementation, `beak_frontend`'s HTTP client another,
/// and a future `beak_serverpod` package can supply one more without
/// touching `beak_core`). Implementations
/// throw typed `BeakException`s (`BeakNotFoundException` for missing
/// records, `BeakConfigurationException` for unknown tables/relations) and
/// never leak ORM types.
abstract interface class BeakDataSource {
```

Two rules carry across every implementation: failures are the typed `BeakException` family, and ORM/transport types stay behind the boundary.

## The server side: `WormDataSource`

`WormDataSource` is the default implementation Beak ships. It translates every operation to worm against an injected `DatabaseAdapter`, honoring model metadata (primary keys, soft deletes, relationships) with no per-model code. One instance serves every registered model because the `BeakModelRegistry` resolves each table name to its `BeakModel`.

```dart title="packages/beak_backend/lib/src/data/worm/worm_data_source.dart"
final class WormDataSource implements BeakDataSource {
  WormDataSource(
    this.registry, {
    required DatabaseAdapter adapter,
    DateTime Function()? now,
  }) : _adapter = adapter,
       _now = now ?? DateTime.now,
       _translator = WormQueryTranslator(registry);
```

`query` is the shape of the whole class: hand the spec to the translator, run the builder, wrap the rows back into `BeakRecord`s. Worm's `WormRecordModel` appears inside the method and is gone by the time it returns.

```dart title="packages/beak_backend/lib/src/data/worm/worm_data_source.dart"
@override
Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) async {
  final BeakModel beakModel = registry.byTableOrThrow(spec.table);
  final builder = _translator.builderFor(spec, _adapter);
  final int total = await builder.count();
  final rows = await builder.get();
  return BeakPage(
    items: [
      for (final row in rows)
        row.toBeakRecord(
          loads: spec.relationLoads,
          model: beakModel,
          registry: registry,
        ),
    ],
    total: total,
    page: spec.pagination.page,
    perPage: spec.pagination.perPage,
  );
}
```

Because the adapter is injected, the same class runs against SQLite (the default, a file beside the process), Postgres, or an `InMemoryAdapter` in a test. The URL scheme picks it once, at boot. Nothing above the data source knows which.

## The client side: `HttpBeakDataSource`

The panel implements the exact same interface over the typed REST client. Every method forwards to `BeakClient`, so widgets and view models stay transport-blind.

```dart title="packages/beak_frontend/lib/src/data/http_beak_data_source.dart"
final class HttpBeakDataSource implements BeakDataSource, BeakUploadClient {
  const HttpBeakDataSource(this.client);

  final BeakClient client;

  @override
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec) =>
      client.query(spec.table, spec);

  @override
  Future<BeakRecord?> getOne(String table, Object id) =>
      client.getOne(table, id);

  @override
  Future<BeakRecord> create(String table, BeakRecord data) =>
      client.create(table, data);
```

That is the whole class: a thin adapter from the interface to HTTP. It additionally implements `BeakUploadClient` so image and file fields can upload through the same object.

## The third implementation: `InMemoryBeakDataSource`

`package:beak/testing.dart` ships a complete implementation over plain maps. Complete is the operative word. It honours filters, sorts, search, relation loads, pagination and soft deletes, so a widget test that pumps a real `BeakDataTable` over it proves the table's paging and filtering actually work.

```dart
final source = InMemoryBeakDataSource(registry: buildBeakRegistry())
  ..seed(const ProductModel(), [beakFakeRecord(const ProductModel())]);
```

The same library exports `BeakRecordingDataSource`, which wraps any source and counts calls, for tests that assert how many round trips a screen costs. And it exports `runBeakDataSourceContract`, an executable definition of done: a suite of groups and expectations any implementation can be run against. `WormDataSource` is run against it, so the contract is not a document that can rot.

## The symmetry, and why it pays

Read the two `query` methods side by side. One builds a worm query and counts rows; the other posts a JSON body to `/api/{table}/query`. They have identical signatures because they satisfy the same interface, and everything upstream, on both sides, is written against that interface rather than against either implementation.

```mermaid
flowchart TB
  subgraph frontend [beak_frontend]
    VM[ViewModel] --> REPO[BeakResourceRepository]
    REPO --> HTTP[HttpBeakDataSource]
  end
  subgraph backend [beak_backend]
    SVC[BeakResourceService] --> WORM[WormDataSource]
  end
  IFACE([BeakDataSource<br/>in beak_core])
  HTTP -. implements .-> IFACE
  WORM -. implements .-> IFACE
  HTTP -->|REST| SVC
```

The seam buys three things:

- **A test seam.** Frontend tests inject an `InMemoryBeakDataSource` and never spin up a server; backend tests inject a `WormDataSource` over an `InMemoryAdapter` or `sqlite::memory:`. Neither has to mock a transport.
- **Transport blindness.** A `BeakDataTable` or a `BeakDataForm` calls `query` and `create`. It cannot tell, and does not care, whether the bytes end up in Postgres or on the far side of an HTTP hop.
- **A clean extension point.** Adding a data backend means writing one class, not editing the panel.

## The future: `ServerpodDataSource`

The seam's payoff is a package that does not exist yet. Beak's default stack is worm over SQLite or Postgres, but the architecture reserves room for a `beak_serverpod` package to add a `ServerpodDataSource`. Both implementations spell out the promise in their own docs. The server side:

```dart title="packages/beak_backend/lib/src/data/worm/worm_data_source.dart"
/// This is the concrete implementation Beak ships; a future
/// `ServerpodDataSource` would satisfy the same [BeakDataSource] interface
/// without touching `beak_core` or `beak_backend`. Wire one over any worm
```

And the client side:

```dart title="packages/beak_frontend/lib/src/data/http_beak_data_source.dart"
/// This is the production source [registerBeakDependencies] wires up over a
/// [BeakClient] pointed at `apiBaseUrl`; tests inject a fake
/// [BeakDataSource] instead. Because it is source-agnostic, a future
/// transport (e.g. Serverpod) can replace it without touching the rest of
/// the frontend.
```

Concretely, that new package would implement the ten methods over Serverpod's client, map Serverpod's errors to the `BeakException` family, and register itself with the frontend's DI. It would not touch `beak_core` (the interface is already there), it would not touch `beak_backend` (worm is one implementation among peers, not a hard dependency of the seam), and no widget or view model would change, because they were never written against worm or HTTP in the first place.

It would also have something to prove itself against. `runBeakDataSourceContract` is the executable half of this page: hand it a builder and a seeder and it runs every edge the interface has, from `getOne` returning `null` rather than throwing to soft deletes hiding from `query` but not from `withTrashed`.

## Keeping types from leaking

The seam only works if the boundary holds, and Beak enforces that structurally.

- **worm is imported by exactly one runtime package.** `beak_backend` is the only one that depends on the ORM. `WormRecordModel` and `QueryBuilder` appear inside `WormDataSource`; they never appear in a return type or a `beak_core` symbol. (`package:beak/migrations.dart` re-exports worm's `Migration` and `Schema`, because a migration is worm's, but that library is on the server side of the wall.)
- **obers_ui lives on the other side.** `beak_frontend` is the only Flutter package, and its widgets never see `dart:io` or Shelf.
- **The interface is the vocabulary.** Everything crossing the seam is a `BeakQuerySpec`, `BeakRecord`, `BeakPage`, or `BeakAggregateSpec`, all defined in `beak_core`, the pure-Dart package both sides share.

Hold those three lines and the framework stays layered: a change to the ORM cannot ripple into the panel, and a change to the panel cannot reach the database.

## Continue reading

- [The data source seam (backend view)](../backend/the-data-source-seam.md) how the server wires a `WormDataSource` over an adapter.
- [Custom data sources](../extending/custom-data-sources.md) writing your own implementation of the interface.
- [The query contract](query-contract.md) the `BeakQuerySpec` the seam consumes.
- [Testing](../guides/testing.md) `InMemoryBeakDataSource`, the recording source, and the contract suite in practice.
- [The four layers](../concepts/the-four-layers.md) where the data source sits in each flow.
