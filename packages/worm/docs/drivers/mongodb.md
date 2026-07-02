---
title: MongoDB
description: Construct the worm_mongodb adapter and work within its document-store rules, including the by-design transaction throw.
---

`worm_mongodb` implements worm's adapter contract on MongoDB through the `mongo_dart` package. It is the document-store odd one out: no SQL, no joins, no multi-document transactions, but a live streaming cursor and full descriptor support. This page builds on [how drivers work](./how-drivers-work.md).

## Install

```yaml title="pubspec.yaml"
dependencies:
  worm:
    path: ../worm
  worm_mongodb:
    path: ../worm_mongodb
```

The driver packages are monorepo-internal today (`publish_to: none`), so you depend on them by path. The `mongo_dart` client (`^0.9.0`) comes in transitively.

## Construct

`MongoConnection` owns a single `mongo_dart` `Db`; the adapter takes it as a required parameter:

```dart
import 'package:worm_mongodb/worm_mongodb.dart';

// From a connection string.
final connection = MongoConnection.fromUri(
  'mongodb://app:secret@localhost:27017/app',
);
// Equivalent: MongoConnection(uri: '...').

// Or adopt a pre-built driver Db (tests).
final connection = MongoConnection.fromDb(db);

final adapter = MongoAdapter(connection: connection);

await Worm.initialize(
  config: const WormConfig(),
  adapters: {'default': adapter},
);
```

`MongoAdapter` also accepts an optional `compiler` (defaults to `const MongoFilterCompiler()`). Unlike the lazy SQL pools, `connect()` here does real work: it opens the `Db`. Both `open()` and `close()` are idempotent, and `connection.isOpen` reports the current state. There is no pool; the adapter holds one connection.

## id and \_id aliasing

worm's canonical primary-key column is `id`; MongoDB stores primary keys under `_id`. The adapter and compiler translate on every boundary:

- Writes: `id` in your values becomes `_id` in the stored document.
- Reads: `_id` in documents comes back as `id` in rows.
- Filters, sort keys, and projections: `id` compiles to `_id`.
- Aggregations: an `id` column or `groupBy` field maps to `_id`.

Your models and queries stay database-agnostic. If you insert without an `id`, the returned row carries the driver-generated `ObjectId` under `id`.

## Capability profile

| Flag | Value |
| --- | --- |
| `supportsTransactions` | `false` |
| `supportsSavepoints` | `false` |
| `supportsStreaming` | `true` |
| `supportsRawQuery` | `false` |
| `supportsReturning` | `true` |
| `supportsJoins` | `false` |
| `supportsPreparedStatements` | `false` |
| `supportsPartialIndexes` | `false` |
| `supportsAggregations` | `true` |
| `supportsSchemaIntrospection` | `true` |
| `supportsExplain` | `true` |

`supportsReturning` is `true` because `insert()` and `insertMany()` return the stored document (projected to `returning` columns when set), even though MongoDB has no SQL `RETURNING` clause. Joins are unsupported; worm's eager loading does not need them because it batches one query per relation path.

## No transactions, by design

`transaction()` always throws `TransactionException`. The `mongo_dart` 0.9 driver exposes no client-session or transaction API, so atomic multi-document commit and rollback cannot be guaranteed, even against a replica set. The adapter refuses rather than silently running writes without isolation, and it declares `supportsTransactions: false` so the runtime can gate accordingly.

Design around it: keep each write to a single document (single-document operations are atomic in MongoDB), or choose a SQL driver for workflows that need multi-statement atomicity. The [transactions page](../database/transactions.md) covers how the application-level API reacts to this capability.

## Queries and filters

`MongoFilterCompiler` translates worm predicate trees into filter documents: `eq` compiles to a direct match, the other comparison operators to `$ne`/`$gt`/`$gte`/`$lt`/`$lte`, list operators to `$in`/`$nin`, and the combinators to `$and`/`$or`/`$nor`. `like`/`ilike` compile to regex matches. Sorting, `limit`, `offset` (as `skip`), and column projections all map onto `modernFind`.

Two predicate shapes have no Mongo find-filter equivalent and throw `UnsupportedOperationException`: `whereExists` (use an aggregation pipeline with `$lookup`) and `whereRaw` (no SQL to evaluate).

`compileToString(descriptor)` renders shell-style syntax, useful in logs:

```text
db.users.find({ "age": { "$gte": 18 } })
```

## Raw access

`rawQuery` and `rawExecute` throw `AdapterMismatchException`: there is no SQL surface to pass through. Use descriptors, or reach for `adapter.connection.db` when you need a driver API worm does not wrap.

## Schema operations

Collections are schemaless, so `executeSchema` maps table DDL onto collection operations:

- `create` and `drop` become `createCollection`/`dropCollection` (honoring `ifNotExists`/`ifExists`).
- `truncate` becomes `deleteMany({})`.
- `alter` throws `QueryException`: there is no schema to alter.
- A `SchemaIndexDescriptor(collection: 'users', field: 'email', unique: true)` becomes `createIndex`.

`introspectSchema()` returns the collection names, each with an empty column list (documents carry no fixed columns).

## Streaming

`stream()` iterates the driver's live cursor and yields each document as it arrives. This is the only worm driver that truly streams; the SQL drivers buffer the full result first. Prefer `stream()` over `get()` for large scans.

## Error mapping

`MongoErrorMapper` recognizes one native code:

| Native code | Meaning | Worm exception |
| --- | --- | --- |
| `11000` | duplicate key | `UniqueConstraintException` |
| any other `MongoDartError` | | `QueryException` |
| any other thrown object | | `QueryException` |

Write-command failures reported on a `WriteResult` (rather than thrown) are picked off and mapped through the same code path. Pre-existing `WormException`s pass through unwrapped. See [exceptions](../reference/exceptions.md).

## EXPLAIN

`explain()` issues the database `explain` command with `verbosity: executionStats` around the compiled `find`. `usesIndex` is `true` when `executionStats.totalKeysExamined` is greater than zero; `raw` carries the entire response as JSON.

## Contract tests

The conformance suite is gated by the `MONGO_URI` environment variable and skips gracefully without a server:

```dart title="test/mongo_contract_test.dart"
final url = Platform.environment['MONGO_URI'];
// skip when unset ...
runAdapterContractTests(
  name: 'MongoAdapter contract',
  capabilities: const AdapterCapabilities(
    supportsStreaming: true,
    supportsReturning: true,
    supportsAggregations: true,
    supportsSchemaIntrospection: true,
    supportsExplain: true,
  ),
  adapterFactory: () async {
    final adapter = MongoAdapter(
      connection: MongoConnection.fromUri(url),
    );
    await adapter.connect();
    return adapter;
  },
);
```

The monorepo's `docker-compose.yml` provides a `mongo` service on port 27017.

## Gotchas

- `transaction()` always throws `TransactionException`. This is by design, not a bug to work around.
- `rawQuery`/`rawExecute` throw `AdapterMismatchException`. There is no raw SQL here.
- The query builder's `.mongo(...)` gate requires an adapter reporting `AdapterType.mongodb`. `MongoAdapter` currently inherits the base default `AdapterType.custom`, so `.mongo(...)` throws `AdapterMismatchException` even on a Mongo connection in this version. Stick to the portable builder surface.
- `connect()` is required before use. The SQL pools connect lazily; the Mongo `Db` does not.
- `whereExists` and `whereRaw` predicates throw `UnsupportedOperationException` in the filter compiler.
- `SchemaOperation.alter` throws `QueryException`; collections are schemaless.
- Aggregates `sum`/`avg`/`min`/`max` require a column and return `null` over zero documents; calling one without a column throws `QueryException`.
- `count()` counts documents matching the filter; there is no chunked `IN` limit like the SQL drivers.

## Continue reading

- [Transactions](../database/transactions.md): how worm's transaction API behaves when the adapter declares no transaction support.
- [Advanced queries](../queries/advanced-queries.md): streaming, chunking, and the dialect gates in one place.
- [Choosing a database](./choosing-a-database.mdx): when a document store fits and when it does not.
