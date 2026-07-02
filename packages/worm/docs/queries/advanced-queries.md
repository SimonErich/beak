---
title: Advanced queries
description: Grouped predicates, subqueries, bulk writes, streaming, raw SQL, and the per-dialect escape hatches.
---

This page covers everything past the basics: boolean grouping, subqueries, bulk operations, streaming large result sets, and the `.sql()` / `.mongo()` dialect gates. It builds on [query basics](./query-basics.md).

## Grouping predicates with whereGroup()

`whereGroup()` wraps a sub-builder's WHERE tree in parentheses and ANDs it onto the outer query:

```dart
// WHERE (name = 'Alice' OR name = 'Bob') AND age >= 18
final rows = await User.query()
    .whereGroup((q) => q.where(User$.name.eq('Alice')).orWhere(User$.name.eq('Bob')))
    .where(User$.age.gte(18))
    .get();
```

The inner builder runs with global scopes disabled, so scope predicates (soft deletes, tenancy) can't leak inside your parentheses. The outer builder still applies them at execution time, exactly once.

## Predicate combinators

Field operators return `PredicateTree` values you can compose directly, without a builder:

```dart
final tree = User$.age.gte(18)
    .and(User$.name.startsWith('A'))
    .or(User$.age.isNull())
    .group();

final rows = await User.query().where(tree.not()).get();
```

`and`, `or`, `not`, and `group` each return a new tree. `group()` adds explicit parentheses; `whereGroup()` is the fluent equivalent.

## Subqueries: whereExists() and whereNotExists()

Pass another builder as a correlated subquery:

```dart
final postsByUserOne = Post.query().where(Post$.userId.eq(1));

final withPosts = await User.query().whereExists(postsByUserOne).get();
final withoutPosts = await User.query().whereNotExists(postsByUserOne).get();
```

The subquery's descriptor is embedded as an EXISTS node; it never executes on its own.

## Column comparisons: whereColumn()

Compare two columns instead of a column and a value:

```dart
final rows = await User.query()
    .whereColumn(User$.updatedAt, User$.createdAt, operator: Operator.gt)
    .get();
```

The operator defaults to `Operator.eq`.

## Lists, ranges, and string matching

```dart
// Membership
User.query().where(User$.name.inList(['Alice', 'Bob']));
User.query().where(User$.name.notInList(['Mallory']));

// Ranges (ComparableField only), inclusive bounds
User.query().where(User$.age.between(18, 65));
User.query().where(User$.age.notBetween(0, 17));

// String matching (StringField only)
User.query().where(User$.name.like('A%'));
User.query().where(User$.name.ilike('a%'));      // case-insensitive
User.query().where(User$.name.contains('li'));    // sugar for LIKE '%li%'
User.query().where(User$.name.startsWith('Al'));  // LIKE 'Al%'
User.query().where(User$.name.endsWith('ce'));    // LIKE '%ce'
```

`whereIn` and `whereNotIn` are identical long-form aliases of `inList` and `notInList`.

## Bulk writes: update(), delete(), insertMany()

Bulk operations translate straight to one adapter call. No models are hydrated on the way in.

:::caution[No hooks, no validation]
**Bulk `update()`, `delete()`, and `insertMany()` skip lifecycle hooks and validation entirely.** No `saving`, `deleting`, or observer events fire, and no validators run. Use `Model.save()` or `Model.delete()` when per-row events matter. Global scopes still apply to the WHERE clause of bulk `update()` and `delete()`, so a soft-delete scope keeps trashed rows out of a bulk update unless you add `withTrashed()`.
:::

```dart
// UPDATE users SET is_active = false WHERE age < 18; returns affected count.
final updated = await User.query()
    .where(User$.age.lt(18))
    .update({'is_active': false});

// DELETE FROM users WHERE age > 120; returns affected count.
final deleted = await User.query().where(User$.age.gt(120)).delete();

// One INSERT for all rows; returns the hydrated models.
final users = await User.query().insertMany([
  {'id': 1, 'name': 'Alice', 'age': 30},
  {'id': 2, 'name': 'Bob', 'age': 25},
]);
```

`insertMany([])` returns an empty list without touching the adapter. Under strict mode, `update()` or `delete()` without a WHERE clause throws `FullTableScanException`; see [strict mode](../guides/strict-mode.md).

## Streaming and chunking

For result sets too large to hold in memory, process rows incrementally:

```dart
// One model at a time.
await for (final user in User.query().where(User$.age.gte(18)).stream()) {
  process(user);
}

// Batches via callback.
await User.query().chunk(500, (batch) async {
  await exportBatch(batch);
});

// Batches as a stream.
await for (final batch in User.query().streamChunks(500)) {
  await exportBatch(batch);
}
```

`chunk()` and `streamChunks()` throw `ConfigurationException` when `size` is zero or negative.

:::note[What streaming actually buffers]
`stream()` delegates to the adapter. Today only the MongoDB adapter streams from a live database cursor. The SQLite, PostgreSQL, and MySQL adapters materialize the full result set in the driver first, then emit rows one at a time. Streaming always bounds hydration memory on the Dart side, but with current SQL drivers it does not bound driver-side memory. Check the [driver pages](../drivers/how-drivers-work.md) for specifics.
:::

## Raw SQL fragments: whereRaw()

When no typed operator expresses your predicate, `whereRaw()` emits a fragment verbatim into the WHERE tree. You must opt in with `allowRaw: true`:

```dart
final evens = await User.query()
    .whereRaw('age % 2 = 0', allowRaw: true)
    .get();
```

Omitting `allowRaw: true` throws `ConfigurationException`. The flag exists to make raw SQL visible at every call site.

:::caution[Injection risk]
Raw fragments bypass every ORM safety guarantee and are emitted verbatim. Never interpolate untrusted input into the SQL string; pass values through `parameters` instead. See [security](../guides/security.md).
:::

The Mongo and in-memory adapters cannot compile raw SQL: a query containing a `RawNode` throws `UnsupportedOperationException` at execution time on those backends.

## Dialect gates: .sql() and .mongo()

The portable builder surface is backend-neutral by design. Constructs that only make sense on one backend live behind gates that check the adapter family (`DatabaseAdapter.adapterType`) and throw `AdapterMismatchException` when it doesn't match. The exception carries `expectedAdapter` and `actualAdapter` so the message names both sides.

### .sql(): joins, grouping, having

`sql()` hands your callback a `SqlQueryContext<T>` with SQL-only chainables. `.builder` exits back to the portable builder:

```dart
final builder = User.query().sql((q) => q
    .join(
      'posts',
      const Field<Object?>('user_id', tableName: 'posts'),
      const Field<Object?>('id', tableName: 'users'),
    )
    .groupBy(const [Field<Object?>('id', tableName: 'users')])
    .having('COUNT(*)', Operator.gt, 5)
    .builder);

final prolificAuthors = await builder.get();
```

`SqlQueryContext` offers `join`, `leftJoin`, `groupBy`, `having`, and its own `whereRaw(sql, {parameters})` (no `allowRaw` flag: entering the gate already states the intent). `having` takes a raw aggregate expression such as `'COUNT(*)'` or `'SUM(views)'`, so the injection caution above applies to it too.

:::caution[Joins collide columns]
A `join` without `select([...])` compiles to `SELECT *`, which flattens both tables into one row and collides same-named columns (both `id` columns, for example). Pair joins with an explicit projection. For loading related rows into typed models, prefer [eager loading](../relations/eager-loading.md); it batches into a constant number of queries and hydrates each side cleanly.
:::

Calling `.sql()` on a non-SQL adapter throws:

```dart
// On InMemoryAdapter:
User.query().sql((q) => q.builder);
// AdapterMismatchException: .sql(...) requires a SQL-capable adapter
// (expected: worm_postgres, actual: InMemoryAdapter)
```

### .mongo(): raw filters and pipelines

`mongo()` hands your callback a `MongoQueryContext<T>`:

```dart
final ctx = User.query().mongo((m) => m
    .withRawFilter({'meta.flag': true})
    .withPipeline([
      {r'$sort': {'age': -1}},
    ]));

ctx.rawFilter; // {'meta.flag': true}
ctx.pipeline;  // [{'$sort': {'age': -1}}]
```

`withRawFilter` merges extra `find()` filter expressions; `withPipeline` appends aggregation stages. Both accumulate on the context object, not on the builder: read them back through the `rawFilter` and `pipeline` getters, and note that returning `.builder` from the callback hands back the portable builder without those fragments. Calling `.mongo()` on a non-Mongo adapter throws `AdapterMismatchException` (expected: `worm_mongodb`). The MongoDB driver page covers how filters and pipelines execute; on that backend, multi-document `transaction()` calls throw `TransactionException` by design, so don't wrap bulk Mongo writes in one.

## Inspecting queries

`toSql()` and `toMongoFilter()` compile the current builder, including global scopes, without executing anything:

```dart
User.query().where(User$.name, 'Alice').toSql();
// SELECT * FROM users WHERE name = 'Alice'

User.query().where(User$.name, 'Alice').toMongoFilter();
// {"name":"Alice"}
```

:::caution[toSql() output is not executable]
`toSql()` inlines literal values to produce deterministic, snapshot-friendly strings. Adapters parameterize their real queries separately. Never feed `toSql()` output back into a database.
:::

`debug()` logs a one-line builder summary via `dart:developer` and returns the builder unchanged, so you can drop it into any chain. `explain()` asks the adapter for a query plan. Both are covered in [logging and debugging](../guides/logging-and-debugging.md).

## Gotchas

- `whereGroup()` runs its inner builder with global scopes disabled; the outer builder still applies them. Your parentheses stay clean and the scopes still fire.
- Bulk `update()`, `delete()`, and `insertMany()` skip lifecycle hooks and validation. Global scopes still constrain bulk `update()` and `delete()`.
- `chunk()` and `streamChunks()` throw `ConfigurationException` for `size <= 0`.
- `whereRaw()` without `allowRaw: true` throws `ConfigurationException`; with it, the fragment bypasses all type checking.
- Queries containing a `RawNode` throw `UnsupportedOperationException` on the Mongo and in-memory adapters.
- `.sql()` and `.mongo()` throw `AdapterMismatchException` on the wrong adapter family. The in-memory adapter rejects both.
- Mongo `withRawFilter` / `withPipeline` state lives on the `MongoQueryContext`, not the builder. Returning `.builder` discards it.
- `toSql()` inlines literals for inspection only; it is never what the adapter executes.

## Continue reading

- [Query basics](./query-basics.md): the full chainable and terminal API summary tables.
- [Logging and debugging](../guides/logging-and-debugging.md): `debug()`, `explain()`, and the logging adapter.
- [How drivers work](../drivers/how-drivers-work.md): what adapters do with your descriptors, and per-driver capabilities.
- [Security](../guides/security.md): the rules for raw SQL and untrusted input.
