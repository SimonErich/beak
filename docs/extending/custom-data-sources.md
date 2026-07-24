---
title: Custom data sources
description: Implement the nine methods of BeakDataSource to back Beak with any store, wire it into the panel or the server, and keep the Serverpod seam open.
---

# Custom data sources

After this page you can implement `BeakDataSource` yourself, back Beak with a
store it has never heard of (a different ORM, a REST gateway, a mock for tests),
and wire your implementation into the panel or the server. You write nine
methods. Everything above them keeps working.

Beak's promise is that your models, columns, and queries describe *what* you
want, never *which* database answers. The seam that makes that true is a single
interface. This page is the how-to side of it; for the why, read
[The data source seam](../backend/the-data-source-seam.md).

## The interface

`BeakDataSource` lives in `beak_core`, the pure-Dart package with no Flutter and
no worm. It speaks a source-agnostic vocabulary of typed records
(`BeakRecord`), query specs (`BeakQuerySpec`), and pages (`BeakPage`). Here it
is, whole:

```dart title="packages/beak_core/lib/src/data/beak_data_source.dart"
abstract interface class BeakDataSource {
  /// Runs [spec] and returns the requested page of typed records, with
  /// every relation load in the spec eagerly resolved (Beak never
  /// lazy-loads).
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec);

  /// The record of [table] with primary key [id], or `null` when it does
  /// not exist (or is soft-deleted).
  Future<BeakRecord?> getOne(String table, Object id);

  /// Inserts [data] into [table] and returns the stored record (including
  /// database-assigned values).
  Future<BeakRecord> create(String table, BeakRecord data);

  /// Updates the record of [table] with primary key [id] with the values of
  /// [data] and returns the stored result.
  ///
  /// Throws a `BeakNotFoundException` when no such record exists.
  Future<BeakRecord> update(String table, Object id, BeakRecord data);

  /// Deletes the record of [table] with primary key [id] - softly when the
  /// model opts into soft deletes, unless [force] hard-deletes.
  ///
  /// Throws a `BeakNotFoundException` when no such record exists.
  Future<void> delete(String table, Object id, {bool force = false});

  /// The records of [table] whose primary keys appear in [ids], fetched in
  /// a single query (the reference-deduplication path).
  Future<List<BeakRecord>> batchGet(String table, List<Object> ids);

  /// Links [relatedIds] to the record of [table] with primary key [id]
  /// through the to-many relation [relationKey]: belongs-to-many inserts
  /// pivot rows (skipping links that already exist), has-many re-parents
  /// the related rows' foreign keys.
  Future<void> attach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  );

  /// Unlinks [relatedIds] from the record of [table] with primary key [id]
  /// through the to-many relation [relationKey]: belongs-to-many removes
  /// the pivot rows, has-many clears the related rows' foreign keys.
  Future<void> detach(
    String table,
    Object id,
    String relationKey,
    List<Object> relatedIds,
  );

  /// Computes [spec]'s aggregate (count/sum/avg) over the matching rows,
  /// returning `0` when no rows match.
  Future<num> aggregate(BeakAggregateSpec spec);
}
```

Two implementations already ship. `WormDataSource` (in `beak_backend`) runs the
methods against the worm ORM over Postgres or SQLite. `HttpBeakDataSource` (in
`beak_frontend`) runs them against a REST server over the typed `BeakClient`.
Yours is the third.

### What each method owes you

| Method | Reads or writes | The contract |
| --- | --- | --- |
| `query` | A page of records | Apply `spec.filter`, `sorts`, `search`, `pagination`; eager-load every `relationLoad`. |
| `getOne` | One record or `null` | Return `null` (not throw) when the row is absent or soft-deleted. |
| `create` | The stored record | Echo back database-assigned values (id, timestamps). |
| `update` | The stored record | Throw `BeakNotFoundException` when the id is gone. |
| `delete` | Nothing | Soft-delete when the model opts in, unless `force` is set. |
| `batchGet` | Records for many ids | One query, not N. This backs reference deduplication. |
| `attach` / `detach` | Nothing | Manage the to-many link (pivot rows or foreign keys). |
| `aggregate` | A `num` | Return `0` when nothing matches, never `null`. |

## The rules an implementation follows

Three invariants keep the seam honest. Break one and the layers above start
leaking assumptions about your store.

1. **Throw typed exceptions, never your store's.** Map a missing record to
   `BeakNotFoundException`, an unknown table or relation to
   `BeakConfigurationException`, a duplicate to `BeakConflictException`. The
   backend's error-mapping middleware and the frontend's repository both catch
   the sealed `BeakException` family and nothing else. See
   [Results and errors](../concepts/results-and-errors.md).
2. **Never leak store types.** No worm rows, no `minio` responses, no ORM entity
   crosses the boundary. In, out, and thrown: only `beak_core` types. This is
   the rule that lets the frontend and backend share one interface.
3. **Eager-load, never lazy-load.** `query` resolves every relation named in
   `spec.relationLoads` up front. Reading an unloaded relation is a design
   error in Beak, so there is nothing to lazy-load against.

## A reference implementation

The cleanest one to copy is `HttpBeakDataSource`: every method delegates to one
transport, so the shape of the interface is visible with no store logic in the
way. It also implements `BeakUploadClient` (the `upload` method) so a panel can
push files through the same object.

```dart title="packages/beak_frontend/lib/src/data/http_beak_data_source.dart"
final class HttpBeakDataSource implements BeakDataSource, BeakUploadClient {
  /// Creates a data source over [client].
  const HttpBeakDataSource(this.client);

  /// The transport the source delegates to.
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

  @override
  Future<BeakRecord> update(String table, Object id, BeakRecord data) =>
      client.update(table, id, data);

  @override
  Future<void> delete(String table, Object id, {bool force = false}) =>
      client.delete(table, id, force: force);

  // batchGet, attach, detach, upload, aggregate follow the same one-line
  // delegation.
}
```

Your implementation swaps `client` for whatever answers your data: a SQL
connection, a GraphQL client, an in-memory map for a test. The signatures do not
move.

!!! note "What just happened"
    `HttpBeakDataSource` holds no query logic of its own. It translates the
    source-agnostic call into a REST call and hands back the typed result. A
    custom source does the same translation to its own protocol. The layer above
    (a `ViewModel`, a `BeakResourceService`) cannot tell the difference.

## Wiring your source in

A `BeakDataSource` plugs into whichever side needs it. Both sides take it as a
constructor or wiring argument, so no other code changes.

=== "Frontend (the panel)"

    `registerBeakDependencies` accepts a `dataSource`; pass yours and the panel
    resolves it everywhere via `beakLocator<BeakDataSource>()` instead of
    building an `HttpBeakDataSource`. `BeakPanel` exposes the same seam as a
    test hook.

    ```dart title="packages/beak_frontend/lib/src/panel/beak_panel.dart"
    // In a widget test, inject a fake source so no HTTP is issued:
    await tester.pumpWidget(
      BeakPanel(config: buildPanelConfig(), dataSource: fakeSource),
    );
    ```

=== "Backend (the server)"

    `BeakServer` requires a `dataSource`. The default is `WormDataSource`;
    hand it your own and every generated route runs against it.

    ```dart title="packages/beak_backend/lib/src/data/worm/worm_data_source.dart"
    final dataSource = WormDataSource(registry, adapter: adapter);

    final page = await dataSource.query(
      BeakQuerySpec(table: 'products'),
    );
    ```

## The Serverpod seam

`BeakModel` is ORM-neutral metadata. It describes columns, relationships, the
display key, and the primary key, and it names none of them to worm. That is the
second half of what keeps the seam open: the interface is store-agnostic, and so
is the model that describes each table.

Because of that, a future `beak_serverpod` package can add a
`ServerpodDataSource` without a line changing in `beak_core` or `beak_backend`.
You supply the same column and relationship metadata for your generated
Serverpod classes, implement the nine methods over the Serverpod client, and
hand Beak the data source. The panel, the query contract, and the blocks never
learn that the store changed. The README states the seam plainly:

> `BeakDataSource` is an interface and `BeakModel` is ORM-neutral metadata. worm
> never leaks into `beak_core`. A future `beak_serverpod` package will implement
> `ServerpodDataSource` and adapt generated Serverpod classes as Beak models
> without changing beak_core or beak_backend.

The same door is open for any store you like. Implement the interface, keep the
three rules, and Beak treats your source exactly like the two it ships with.

## Continue reading

- [The data source seam](../backend/the-data-source-seam.md) the concept behind the interface, and how `WormDataSource` translates a spec to SQL.
- [How data flows](../concepts/how-data-flows.md) the serializable `BeakQuerySpec` your `query` method receives.
- [Results and errors](../concepts/results-and-errors.md) the sealed `BeakException` family your source throws.
- [Custom storage drivers](custom-storage-drivers.md) the same pluggable pattern, one layer down, for files.
