---
title: How drivers work
description: The adapter contract that connects worm's query builder to any database backend.
---

This page explains the contract between worm core and a database driver: what crosses the boundary, how feature support is declared, and how native errors become typed exceptions. It builds on [query basics](../queries/query-basics.md) and sits between [choosing a database](./choosing-a-database.mdx) and the contributor guide for [writing your own driver](../contributing/writing-a-database-driver.md).

## Descriptors in, rows out

Worm core never writes SQL. The query builder compiles everything you express into immutable descriptor objects, then hands them to a `DatabaseAdapter`:

- Reads: `QueryDescriptor` (table, predicates, sort, projection, limit, offset)
- Writes: `InsertDescriptor`, `InsertManyDescriptor`, `UpdateDescriptor`, `DeleteDescriptor`
- Aggregates: `AggregateDescriptor`
- DDL: `SchemaDescriptor`

The adapter translates each descriptor into a native operation and returns plain `Map<String, Object?>` rows. The model layer above hydrates those maps into typed model instances. That's the whole boundary: descriptors go down, maps come up. The [architecture page](../contributing/architecture.md) shows the full layered diagram.

Because every backend consumes the same descriptors, your queries don't change when you swap adapters. Only construction code does.

## Adapter = compiler + executor + error mapper

Each shipped driver package splits into three parts:

- A **compiler**: a `const`, pure, I/O-free class that turns a descriptor into dialect-specific output. `SqliteCompiler` and `PostgresCompiler` emit SQL with positional parameters; `MongoFilterCompiler` emits filter documents.
- An **executor**: the adapter class itself. It runs compiled statements on the underlying client (`sqlite3`, `postgres`, `mysql_client_plus`, `mongo_dart`), manages connections or pools, and implements `transaction()`.
- An **error mapper**: a static class that wraps every call and converts native driver errors into worm's typed exception hierarchy.

Parameter binding is always positional and value-safe: PostgreSQL uses `$1, $2, ...`, SQLite and MySQL use `?` with prepared statements. User values never get interpolated into statement text.

## Capabilities describe, adapters enforce

Every adapter declares an `AdapterCapabilities` matrix. All 11 flags default to `false`, so a driver opts in to exactly what it can deliver:

`supportsTransactions`, `supportsSavepoints`, `supportsStreaming`, `supportsRawQuery`, `supportsReturning`, `supportsJoins`, `supportsPreparedStatements`, `supportsPartialIndexes`, `supportsAggregations`, `supportsSchemaIntrospection`, `supportsExplain`.

Two rules keep this honest:

1. **Capabilities describe.** The runtime consults flags before acting: `Worm.transaction` checks `supportsTransactions`, `TransactionContext.savepoint` checks `supportsSavepoints`, and the missing-index warner checks `supportsExplain`. `capabilities.supports('transactions')` is a safe string lookup that returns `false` for unknown keys and never throws.
2. **Adapters enforce.** The flags themselves stop nothing. If a caller invokes an unsupported method anyway, the adapter throws `UnsupportedOperationException`, naming the rejected operation and adapter. `InMemoryAdapter.rawQuery` is a good example.

Compare the declared matrices of all five backends in the [capability matrix](./choosing-a-database.mdx#capability-matrix).

## Dialect gates and AdapterType

Adapters also report an `AdapterType`: `sql`, `mongodb`, `inMemory`, or `custom` (the default for third-party adapters). The query builder's escape hatches consult it:

- `.sql()` unlocks SQL-only features such as joins, and throws `AdapterMismatchException` unless `adapterType == AdapterType.sql`.
- `.mongo()` unlocks Mongo-only features such as raw filters, and throws `AdapterMismatchException` unless `adapterType == AdapterType.mongodb`.

This is a compile-target check, not a capability check: it stops you from sending SQL concepts to a document store before anything reaches the database. See [advanced queries](../queries/advanced-queries.md) for the gated APIs.

## EXPLAIN is opt-in

`explain` is not part of the `DatabaseAdapter` contract. Adapters that can produce a query plan mix in `ExplainCapable` and implement:

```dart
Future<ExplainResult> explain(QueryDescriptor descriptor);
```

Consumers gate access with `capabilities.supportsExplain` plus an `is ExplainCapable` check. `ExplainResult` normalizes the answer across backends: `usesIndex`, `raw` plan text, optional `indexName`, `estimatedCost`, `estimatedRows`, and `scannedTables`. All five shipped adapters implement it, each from its native source (`EXPLAIN QUERY PLAN`, `EXPLAIN (FORMAT JSON)`, `EXPLAIN FORMAT=JSON`, Mongo's `explain` command, and a synthetic plan for in-memory).

## Seeing what an adapter would run

Every adapter implements `compileToString(Object descriptor)`. It's synchronous, never touches the database, and renders the native form of a descriptor: SQL text for the SQL drivers, `db.<collection>.find(...)` shell syntax for Mongo. The logging layer uses it to print real statements, and you can call it directly when debugging. `LoggingAdapter` in worm core is itself a `DatabaseAdapter` decorator that wraps any driver; see [logging and debugging](../guides/logging-and-debugging.md).

## Error mapping

Drivers never let native error types leak. Every call is wrapped, and errors map onto the shared hierarchy:

| Native condition | Worm exception |
| --- | --- |
| Unique or primary key violation | `UniqueConstraintException` |
| Foreign key violation | `ForeignKeyException` |
| Deadlock or serialization failure | `TransactionException` |
| Connection refused, dropped, or timed out | `ConnectionException` |
| Anything else the database rejects | `QueryException` |

Concrete code tables (SQLite result codes, PostgreSQL SQLSTATEs, MySQL error numbers, Mongo code 11000) live on the per-driver pages. Two invariants hold everywhere:

- An error that is already a `WormException` passes through unwrapped, so mapping never double-wraps.
- Your `catch` clauses stay backend-agnostic: catch `UniqueConstraintException`, not a driver-specific type.

## Gotchas

- Capability flags are declarations, not guards. Calling an unsupported operation raises `UnsupportedOperationException` from the adapter, not a silent no-op.
- `.sql()` and `.mongo()` check `adapterType`, not capabilities. A custom adapter defaults to `AdapterType.custom` and gets neither gate.
- `aggregateGrouped` has a concrete default on `DatabaseAdapter` (an in-memory rollup over selected rows). The shipped SQL and Mongo drivers override it to push `GROUP BY` down; a naive third-party adapter still works, just less efficiently.
- `stream()` is declared on all five shipped adapters, but only MongoDB streams a live cursor. The SQL drivers buffer the full result set first.
- `compileToString` output is for logging and debugging. It is not guaranteed to be an executable statement.

## Continue reading

- [Advanced queries](../queries/advanced-queries.md): the dialect gates and raw escape hatches in practice.
- [Adapter API reference](../reference/adapter-api.md): every contract method with signatures.
- [Writing a database driver](../contributing/writing-a-database-driver.md): implement the contract and validate it with the shared test kit.
