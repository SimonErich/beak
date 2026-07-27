---
title: Custom data sources
description: Implement the ten methods of BeakDataSource to back Beak with any store, prove it with the shipped contract suite, and keep the Serverpod seam open.
---

# Custom data sources

After this page you can implement `BeakDataSource` yourself, back Beak with a
store it has never heard of (a different ORM, a REST gateway, a mock for tests),
prove your implementation with the contract suite Beak ships, and wire it into
the panel or the server. You write ten methods. Everything above them keeps
working.

Beak's promise is that your schema classes, columns, and queries describe *what*
you want, never *which* database answers. The seam that makes that true is a
single interface. This page is the how-to side of it; for the why, read
[The data source seam](../backend/the-data-source-seam.md).

## The interface

`BeakDataSource` comes from `package:beak/beak.dart`, the library with no
Flutter and no ORM in it. It speaks a source-agnostic vocabulary of typed
records (`BeakRecord`), query specs (`BeakQuerySpec`), and pages (`BeakPage`).
Here it is, whole:

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

  /// Deletes the record of [table] with primary key [id] — softly when the
  /// model opts into soft deletes, unless [force] hard-deletes.
  ///
  /// Throws a `BeakNotFoundException` when no such record exists.
  Future<void> delete(String table, Object id, {bool force = false});

  /// Clears the soft-delete marker on the record with primary key [id],
  /// returning it as it now reads.
  ///
  /// A deletion the user can walk back is the difference between a panel
  /// people trust and one they are afraid of, and it only works if the row
  /// is still there — so this is the one operation that deliberately reaches
  /// past the soft-delete scope.
  ///
  /// Throws a [BeakNotFoundException] when no soft-deleted record has that
  /// id, and a [BeakValidationException] when the model does not soft-delete
  /// at all — restoring a hard-deleted row is not a thing that can be done,
  /// and reporting success would be a lie.
  Future<BeakRecord> restore(String table, Object id);

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

Three implementations already ship. `WormDataSource` (backend) runs the methods
against the worm ORM over SQLite or Postgres. `HttpBeakDataSource` (panel) runs
them against the generated REST API over the typed `BeakClient`.
`InMemoryBeakDataSource` (in `package:beak/testing.dart`) runs them against maps
and honours the whole spec. Yours is the fourth.

### What each method owes you

| Method | Reads or writes | The contract |
| --- | --- | --- |
| `query` | A page of records | Apply `spec.filter`, `sorts`, `search`, `pagination`; eager-load every entry of `relationLoads`. |
| `getOne` | One record or `null` | Return `null` (not throw) when the row is absent or soft-deleted. |
| `create` | The stored record | Echo back database-assigned values (id, timestamps). |
| `update` | The stored record | Throw `BeakNotFoundException` when the id is gone. |
| `delete` | Nothing | Soft-delete when the model opts in, unless `force` is set. |
| `restore` | The restored record | Clear the soft-delete marker; throw `BeakValidationException` when the model does not soft-delete. |
| `batchGet` | Records for many ids | One query, not N. This backs reference deduplication. |
| `attach` / `detach` | Nothing | Manage the to-many link (pivot rows or foreign keys). |
| `aggregate` | A `num` | Return `0` when nothing matches, never `null`. |

## The rules an implementation follows

Three invariants keep the seam honest. Break one and the layers above start
leaking assumptions about your store.

1. **Throw typed exceptions, never your store's.** Map a missing record to
   `BeakNotFoundException`, an unknown table or relation to
   `BeakConfigurationException`, a duplicate to `BeakConflictException`. The
   backend's error-mapping middleware and the panel's repository both catch
   the sealed `BeakException` family and nothing else. See
   [Results and errors](../concepts/results-and-errors.md).
2. **Never leak store types.** No worm rows, no `minio` responses, no ORM entity
   crosses the boundary. In, out, and thrown: only Beak types. This is the rule
   that lets the panel and the server share one interface.
3. **Eager-load, never lazy-load.** `query` resolves every relation named in
   `spec.relationLoads` up front. Reading an unloaded relation is a design
   error in Beak, so there is nothing to lazy-load against. A list page and a
   show page each ask for their relations in the spec and expect them back with
   the page.

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

  @override
  Future<BeakRecord> restore(String table, Object id) =>
      client.restore(table, id);

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

## Prove it with the contract suite

"Implement ten methods" is not a specification. The interface has edges that
only bite in production: `getOne` returning null rather than throwing, `update`
throwing when the row is gone, `aggregate` returning 0 rather than null over an
empty set, soft deletes hiding from `query` but not from `withTrashed`.
`package:beak/testing.dart` ships the executable version of all of it, and every
built-in source runs it.

```dart
import 'package:beak/testing.dart';

void main() {
  runBeakDataSourceContract(
    'MyDataSource',
    registry: buildBeakRegistry(),
    model: const ProductModel(),
    create: () async => MyDataSource(),
    seed: (source, model, records) async => mySeed(source, model, records),
  );
}
```

Point `create` at your source and `seed` at whatever populates it (a contract
cannot assume how: the in-memory one has `seed`, a SQL one needs SQL, a
Serverpod one needs a session). A green run is your source saying it belongs.

## Wiring your source in

A `BeakDataSource` plugs into whichever side needs it.

=== "The panel"

    `BeakPanel` takes a `dataSource`, and so does `registerBeakDependencies`
    under it. The generated `BeakApp` forwards the parameter, so a widget test
    injects a fake without any wiring of its own.

    ```dart title="examples/store/lib/beak/app.g.dart"
      /// Creates the app; [dataSource] injects a fake in widget tests.
      const BeakApp({this.dataSource, super.key});

      /// Test seam replacing the HTTP-backed data source.
      final BeakDataSource? dataSource;
    ```

    Pass yours and the panel resolves it everywhere through
    `beakLocator<BeakDataSource>()` instead of building an
    `HttpBeakDataSource`.

=== "The server"

    `BeakServer` requires a `dataSource`, and the generated host builds a
    `WormDataSource` for it. To serve something else, eject `lib/server.dart`
    and construct the server yourself from the resolved defaults.

    ```dart
    BeakServer beakServer(BeakServerDefaults defaults) => BeakServer(
      config: defaults.config,
      registry: defaults.registry,
      dataSource: MyDataSource(),
      storage: defaults.storage,
    );
    ```

    Every generated route then runs against your source, unchanged.

## The Serverpod seam

`BeakModel` is ORM-neutral metadata. It describes columns, relationships, the
display key, and the primary key, and it names none of them to worm. That is the
second half of what keeps the seam open: the interface is store-agnostic, and so
is the model that describes each table.

Because of that, a future `beak_serverpod` package can add a
`ServerpodDataSource` without a line changing in Beak. You supply the same
column and relationship metadata for your generated Serverpod classes (a
hand-written `BeakModel` is a supported way to do it, see
[Escape hatches](../models/escape-hatches.md)), implement the ten methods over
the Serverpod client, and hand Beak the data source. The panel, the query
contract, and the blocks never learn that the store changed.

The same door is open for any store you like. Implement the interface, keep the
three rules, run the contract suite, and Beak treats your source exactly like
the ones it ships with.

## Continue reading

- [The data source seam](../backend/the-data-source-seam.md) the concept behind the interface, and how `WormDataSource` translates a spec to SQL.
- [How data flows](../concepts/how-data-flows.md) the serializable `BeakQuerySpec` your `query` method receives.
- [Testing](../guides/testing.md) the in-memory source, the recording decorator, and the contract suite in context.
- [Results and errors](../concepts/results-and-errors.md) the sealed `BeakException` family your source throws.
- [Custom storage drivers](custom-storage-drivers.md) the same pluggable pattern, one layer down, for files.
