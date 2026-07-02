---
title: PostgreSQL
description: Construct, pool, and tune the worm_postgres adapter, the driver with the richest capability profile.
---

`worm_postgres` implements worm's adapter contract on PostgreSQL through the `postgres` v3 package. It is the only driver with every capability flag enabled, including native `RETURNING`. This page builds on [how drivers work](./how-drivers-work.md).

## Install

```yaml title="pubspec.yaml"
dependencies:
  worm:
    path: ../worm
  worm_postgres:
    path: ../worm_postgres
```

The driver packages are monorepo-internal today (`publish_to: none`), so you depend on them by path. The `postgres` client (`^3.0.0`) comes in transitively.

## Construct

Build a pool, then hand it to the adapter:

```dart
import 'package:worm_postgres/worm_postgres.dart';

final pool = PostgresConnectionPool.fromConfig(const ConnectionConfig(
  driver: 'postgres',
  host: 'localhost',
  port: 5432,
  database: 'app',
  username: 'app',
  password: 'secret',
  poolSize: 4,
  useSsl: true,
));

final adapter = PostgresAdapter(pool: pool);

await Worm.initialize(
  config: const WormConfig(),
  adapters: {'default': adapter},
);
```

`PostgresAdapter` takes a required `pool`, an optional `compiler` (defaults to `const PostgresCompiler()`), and an optional `preparedStatementCache` for observability. `connect()` is a no-op because the pool opens connections lazily; `disconnect()` closes the pool.

For tests you can inject a raw driver pool directly:

```dart
final pool = PostgresConnectionPool(
  pool: Pool<Object?>.withUrl(url),
  maxConnectionCount: 4,
);
```

## Pooling

`PostgresConnectionPool.fromConfig` translates worm's `ConnectionConfig`:

- `poolSize` becomes the pool's `maxConnectionCount`.
- `port: 0` (worm's "unset" sentinel) resolves to `5432`.
- `useSsl` selects `SslMode.require` or `SslMode.disable`.
- `connectionTimeout` is forwarded to the pool settings.

When `maxTotalConnections` is set, an isolate-wide reservation counter caps the sum of every pool's size across all named connections in the current isolate. If the requested `poolSize` only partially fits, the pool is silently clamped to the remaining slots. If no slots remain, `fromConfig` throws `ConfigurationException` with key `maxTotalConnections`. Slots return to the counter when you `close()` the pool (which `disconnect()` does).

Diagnostics: `PostgresConnectionPool.isolateReservedSlots` reports the current reservation; `resetIsolateReservationForTesting()` zeroes it in tests. Each adapter method acquires, uses, and releases its own pooled connection, so one adapter instance is safe to share across concurrent callers.

## Capability profile

`postgresAdapterCapabilities` is a package-level const shared between `PostgresAdapter` and `PostgresTransactionAdapter` so the two cannot drift:

| Flag | Value |
| --- | --- |
| `supportsTransactions` | `true` |
| `supportsSavepoints` | `true` |
| `supportsStreaming` | `true` |
| `supportsRawQuery` | `true` |
| `supportsReturning` | `true` |
| `supportsJoins` | `true` |
| `supportsPreparedStatements` | `true` |
| `supportsPartialIndexes` | `true` |
| `supportsAggregations` | `true` |
| `supportsSchemaIntrospection` | `true` |
| `supportsExplain` | `true` |

This is the only driver with real `RETURNING` and partial (filtered) index support.

## Dialect notes

- Identifiers are double-quoted (`"users"`); placeholders are positional `$1, $2, ...`.
- Inserts emit `RETURNING *` by default, or `RETURNING <columns>` when the descriptor lists them, so `insert()` returns the row as the database stored it, including generated keys and column defaults. An INSERT that produces no row throws `QueryException`.
- `ILIKE` is native.
- `inList`/`notInList` values chunk at `kInListChunkSize` (1000) and recombine with `OR`/`AND`.
- `SchemaOperation.alter` is not implemented in the V1 compiler and throws `QueryException`.

## Error mapping

`PostgresErrorMapper` classifies server errors by SQLSTATE:

| SQLSTATE | Meaning | Worm exception |
| --- | --- | --- |
| `23505` | unique_violation | `UniqueConstraintException` |
| `23503` | foreign_key_violation | `ForeignKeyException` |
| `40001` | serialization_failure | `TransactionException` |
| `40P01` | deadlock_detected | `TransactionException` |
| `08000`, `08001`, `08003`, `08004`, `08006`, `08P01` | connection failures | `ConnectionException` |
| any other code, or no code | | `QueryException` |

Errors that are not `PgException`s propagate unchanged, so programmer errors stay distinguishable from database failures. See [exceptions](../reference/exceptions.md).

## Transactions and savepoints

`transaction()` runs your callback inside `Pool.runTx` and hands it a `PostgresTransactionAdapter` bound to the transaction's session; every call in the callback is part of one atomic unit. A throw rolls the transaction back and rethrows.

Nested `transaction()` calls on the transaction adapter become savepoints named `worm_sp_1`, `worm_sp_2`, and so on: issued on entry, released on success, rolled back to on failure. The counter is per-instance, so concurrent transactions on different sessions never contend for names. For the application-level API, see [transactions](../database/transactions.md).

## EXPLAIN

`explain()` runs `EXPLAIN (FORMAT JSON)` over the compiled SELECT. `usesIndex` is `true` when the plan contains an `Index Scan`, `Index Only Scan`, or `Bitmap Index Scan` node; `scannedTables` lists the relations behind `Seq Scan` nodes; `raw` carries the full JSON plan.

## Aggregate typing

PostgreSQL may return `COUNT` as a string (a `bigint` above 2^53-1) and `SUM`/`AVG` as `DECIMAL` strings. The adapter's parsers coerce `int`, `num`, and `String` shapes, and throw `QueryException` for anything else. Aggregates over zero rows yield `null` for `sum`, `avg`, `min`, and `max`.

## Contract tests

The conformance suite is gated by the `PG_DB` environment variable and skips gracefully without a server:

```dart title="test/postgres_contract_test.dart"
final url = Platform.environment['PG_DB'];
// skip when unset ...
runAdapterContractTests(
  name: 'PostgresAdapter contract',
  capabilities: postgresAdapterCapabilities,
  adapterFactory: () async {
    final pool = PostgresConnectionPool(
      pool: Pool<Object?>.withUrl(url),
      maxConnectionCount: 4,
    );
    return PostgresAdapter(pool: pool);
  },
);
```

The monorepo's `docker-compose.yml` provides a `postgres` service on port 5432 for this.

## Gotchas

- `maxTotalConnections` clamps silently when slots partially fit and throws `ConfigurationException` only when none remain. Watch `isolateReservedSlots` if pool sizes surprise you.
- The cap is per isolate, not per process. Every isolate gets its own counter.
- `stream()` is buffered: it selects all rows first, then yields them.
- `preparedStatementCache` on the adapter is observability only. The `postgres` driver itself caches prepared statements per connection; worm's LRU (default `maxSize: 100`) just records reuse.
- Aggregates can arrive as strings; treat `sum()`/`avg()` results as `num?`/`double?` and let the adapter coerce.
- `SchemaOperation.alter` throws `QueryException`; write raw DDL through `rawExecute` if you need `ALTER TABLE` today.

## Continue reading

- [Production](../guides/production.md): pool sizing, SSL, and deployment checklists.
- [Performance](../guides/performance.md): using `explain()` and the missing-index warner.
- [Transactions](../database/transactions.md): the application-level transaction API built on this adapter.
