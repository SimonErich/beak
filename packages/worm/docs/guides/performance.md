---
title: Performance
description: Practical advice for keeping worm fast, from eager loading and cursor pagination to driver knobs, and what worm deliberately does not optimize for you.
---

This page collects the habits that keep a worm app fast, with links to the mechanism behind each one. It also lists, honestly, what worm does not do for you.

## Fix N+1 queries first

Nothing else on this page matters if your request runs 200 queries where 3 would do. Worm never lazy-loads relations, so an N+1 in worm is always explicit code: a query inside a loop. Replace it with [eager loading](../relations/eager-loading.md):

```dart
// N+1: one query for users, one per user for posts
final users = await User.query().get();
// ... looping and querying posts per user ...

// Eager: exactly one extra query per relation path
final users = await User.query().withRelationPaths(['posts']).get();
```

Turn on `warnOnN1Queries` (or `throwOnN1Queries` in CI) so the [N+1 detector](./logging-and-debugging.md#n1-detection) finds the loops you missed. One flight for the whole flock beats one flight per worm.

If you only need a number or a flag per parent, don't load the relation at all. `withCount`, `withSum`, and `withExists` inject aggregates in bulk, pushed down to the database. See [eager loading](../relations/eager-loading.md).

## Let the database count

Aggregate terminals (`count`, `sum`, `avg`, `min`, `max`) compile to aggregate queries on the adapter; they never pull rows into Dart. Two related habits:

- Use `exists()` instead of `count() > 0`. `exists()` is a `LIMIT 1` probe that stops at the first matching row; `count()` counts every match. See [query basics](../queries/query-basics.md).
- Use `pluck()` when you need a single column. It projects just that column instead of hydrating full models. See [advanced queries](../queries/advanced-queries.md).

## Stream large result sets

`get()` materializes every row in memory. For exports, backfills, and batch jobs, use `stream()`, `chunk(size, callback)`, or `streamChunks(size)` to process rows with bounded memory. How bounded depends on the driver: some stream from a live cursor, others buffer per page. Details on [advanced queries](../queries/advanced-queries.md) and [how drivers work](../drivers/how-drivers-work.md).

## Paginate deep lists with cursors

Offset pagination (`paginate`) runs two queries (a page select and a count) and gets slower the deeper the page, because the database still walks every skipped row. Cursor pagination (`cursorPaginate`) runs one query with a `perPage + 1` probe and stays flat at any depth. Use offset pagination for page-numbered UIs, cursors for infinite scroll and APIs. The trade-offs live on [pagination](../queries/pagination.md).

## Index what you filter

Every column that appears in a hot `where`, `orderBy`, or join should be indexed. In worm:

1. Declare indexes in migrations with the schema builder's `index()` and `unique()` on the table blueprint. See [schema builder](../database/schema-builder.md).
2. Verify a query actually uses them with `query.explain()` on an `ExplainCapable` adapter (Postgres, SQLite, in-memory). See [logging and debugging](./logging-and-debugging.md#inspecting-a-query-without-running-it).
3. Enable `warnOnMissingIndex` in staging so the [missing-index warner](./logging-and-debugging.md#missing-index-warnings) flags filtered queries whose plan does a full scan.

The in-memory adapter always reports an index hit, so do this verification against a real database.

## Write less, batch more

- **Updates are already minimal.** Worm tracks dirty fields, and `save()` on an existing model sends only the changed columns in the `UPDATE`. Details on [saving and updating](../models/saving-and-updating.md).
- **Batch inserts with `insertMany`.** One statement for many rows beats a `save()` loop. The trade-off: bulk `insertMany`, `update`, and `delete` skip lifecycle hooks and validation. See [advanced queries](../queries/advanced-queries.md).
- **Wrap multi-write jobs in one transaction.** `Worm.transaction` gives you one commit instead of one per row, which is a large win on drivers that fsync per commit. See [transactions](../database/transactions.md).
- **Keep pivot syncs small.** `sync()` on a many-to-many relation issues one query per attached id and one per detached id. Syncing a 500-id set is roughly 500 queries plus the diff read. Prefer small incremental `attach`/`detach` calls over re-syncing large sets. See [working with relations](../relations/working-with-relations.md).

## Mute events for bulk jobs

Every `save()` dispatches up to six lifecycle events through the model's hooks and all registered observers. For a seeding run or a migration backfill, that's pure overhead. `Worm.withoutEvents(body)` mutes dispatch for a region (validation still runs), and seeders can opt in per class with `muteEvents`. See [lifecycle hooks and observers](../models/lifecycle-hooks-and-observers.md) and [seeding](../database/seeding.md).

## Know your driver's knobs

Each driver has its own performance profile; the driver pages carry the details:

- **PostgreSQL**: a real connection pool (`poolSize`, `maxTotalConnections` with per-isolate reservation), native `RETURNING`, partial indexes, and JSON-format EXPLAIN. See [PostgreSQL](../drivers/postgresql.md).
- **SQLite**: a single connection with WAL mode, a 128-entry LRU prepared-statement cache (cleared by DDL), and automatic chunking of `IN` lists past 900 parameters. See [SQLite](../drivers/sqlite.md).
- **MySQL**: server-side prepared statements created per call; its statement cache exists for observability, not reuse. See [MySQL](../drivers/mysql.md).
- **In-memory**: everything is a Dart map operation; it's the baseline for "how fast can the ORM layer itself go". See [in-memory](../drivers/in-memory.md).

Pool sizing lives on `ConnectionConfig` (`poolSize` defaults to 10). Raising it helps concurrent request handling until the database's own connection limit becomes the bottleneck. See [configuration options](../reference/configuration-options.md).

## Use strictness flags as tripwires

[Strict mode](./strict-mode.md) is a performance tool as much as a safety tool:

- `warnOnN1Queries` and `warnOnMissingIndex` surface the two most common silent slowdowns.
- `preventFullTableScans` and `preventDestructiveWithoutWhere` stop accidental whole-table work before it starts.
- `slowQueryThreshold` (500 ms default on `StrictnessConfig`) feeds slow-query capture; tighten it as your baseline improves.

One caution: keep `throwOnN1Queries` off in bulk-write and benchmark suites. Rapid single-row writes can look like an N+1 pattern to the detector and abort your job with a `DangerousQueryException`. Warn there instead.

## What worm doesn't do (on purpose)

Being honest about non-features saves you from designing around machinery that isn't there:

- **No identity map.** Two queries that return the same row give you two independent model instances. Mutating one does not update the other, and worm never deduplicates instances for you. If a request handler needs one authoritative instance, fetch once and pass it along.
- **No partial-model projection.** Worm hydrates whole rows into whole models. There is no "select two columns into a lightweight User". When you need a slice, use `pluck()` for one column or drop to the adapter's raw layer; don't hydrate models with holes in them.
- **No lazy loading.** Accessing an unloaded relation throws instead of silently querying. This is why N+1 problems in worm are always visible in your own code, and why the fix is always the same: [eager load it](../relations/eager-loading.md).
- **No query cache.** Every terminal hits the database. Cache at the application layer where you can see and invalidate it.

These are deliberate: worm prefers predictable, visible query behavior over hidden optimizations that fail in surprising ways.

## Gotchas

- `exists()` and `count()` answer different questions at different costs; don't use `count()` for a boolean.
- Bulk writes skip hooks and validation. Fast, but observers and rules won't see those rows.
- `withoutEvents` mutes hooks and observers, not validation.
- Cursor pagination advances in ascending order only; it's not a drop-in for arbitrary sorts. See [pagination](../queries/pagination.md).
- Benchmarking against `InMemoryAdapter` measures the ORM layer, not your production database. Do both.
- `throwOnN1Queries` can false-positive on bulk single-row writes; prefer `warnOnN1Queries` outside CI.

## Continue reading

- [Eager loading](../relations/eager-loading.md): the single biggest performance lever in worm.
- [Pagination](../queries/pagination.md): offset vs cursor mechanics and when each wins.
- [Logging and debugging](./logging-and-debugging.md): measure before you optimize.
- [Strict mode](./strict-mode.md): the full flag catalog behind the tripwires above.
