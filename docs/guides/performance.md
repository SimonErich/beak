---
title: Performance
description: How Beak keeps query counts low by default: eager loading, always-on pagination, database-side aggregates, and batched reference resolution.
---

# Performance

After this page you can reason about how many database round-trips a Beak
surface costs, and reach for the four levers that keep that number small:
eager-loaded relations, always-on pagination, aggregate pushdown, and the
batched reference cache.

Beak's performance story is mostly a story about query counts. A dashboard
that fires one query per row is slow no matter how fast the database is. Beak
is built so the obvious thing is also the cheap thing: a page loads its rows in
one query, the relations it needs in a handful more, and its stat tiles without
loading any rows at all.

## Beak never lazy-loads

There is no lazy loading anywhere in Beak. Reading a relation that was not
eager-loaded throws, rather than quietly firing a query behind your back. That
sounds strict, and it is: it is the rule that makes the N+1 query problem
impossible instead of merely discouraged.

You declare what a surface needs up front, and the backend loads it in bulk.

```dart title="packages/beak_core/lib/src/query/beak_relation_load.dart"
/// An eager-load directive: which relation to load with the main query,
/// optionally constrained and with nested loads of its own.
///
/// Beak never lazy-loads; every relation a surface needs is declared up
/// front through directives like this one (reference-dedup happens in the
/// backend).
```

On the frontend you never build these directives by hand. You chain the spec's
typed `withRelation` builder off a relationship constant, and it records the
key for you:

```dart title="packages/beak_core/lib/src/query/beak_query_spec.dart"
/// Returns a copy additionally eager-loading [relation], optionally
/// constrained by [constraint].
BeakQuerySpec withRelation(
  BeakRelationship relation, {
  BeakFilter? constraint,
}) => _copy(
  relationLoads: [
    ...relationLoads,
    BeakRelationLoad(relation.key, filter: constraint),
  ],
);
```

On the backend, the query translator turns each directive into one batched
eager-load path, not one query per row. Loading a hundred orders with their
customer costs two queries (the orders, then every customer in a single
`WHERE id IN (...)`), never a hundred and one.

!!! note "What just happened"
    - A surface asks for exactly the relations it renders, by constant.
    - The backend loads each relation in one extra query for the whole page.
    - A relation nobody asked for is never loaded, and reading it throws, so an
      accidental N+1 shows up as a loud error in a test, not a slow page in
      production.

You can go further. A `BeakRelationLoad` carries an optional `filter` to
constrain which related rows load, and `nested` directives to eager-load the
related model's own relations in the same batched pass:

```dart title="packages/beak_core/lib/src/query/beak_relation_load.dart"
// Load an order's line items that are still pending, and each item's
// product in turn.
const load = BeakRelationLoad(
  'items',
  filter: BeakFieldFilter.forKey(
    'status',
    BeakOperator.eq,
    BeakStringValue('pending'),
  ),
  nested: [BeakRelationLoad('product')],
);
```

## Pagination is on by default

Every list query carries a paging window, and it is populated whether or not
you set one. The default is a 1-based page of twenty-five rows:

```dart title="packages/beak_core/lib/src/query/beak_pagination.dart"
/// Creates a paging window on 1-based [page] with [perPage] records.
const BeakPagination({this.page = 1, this.perPage = 25})
  : assert(page >= 1, 'page is 1-based and must be >= 1'),
    assert(perPage >= 1, 'perPage must be >= 1');
```

Because the window always exists, the translator always applies a `LIMIT` and,
past page one, an `OFFSET`. There is no code path that selects a whole table by
accident:

```dart title="packages/beak_backend/lib/src/data/worm/query_translator.dart"
builder = builder.limit(spec.pagination.perPage);
final int offsetRows = (spec.pagination.page - 1) * spec.pagination.perPage;
if (offsetRows > 0) {
  builder = builder.offset(offsetRows);
}
```

Change the window with the spec's `paginate` builder. Tables in the panel do
this for you as the user moves between pages; you reach for it directly when a
chart or a batched job wants a larger or smaller page.

```dart
final spec = const BeakQuerySpec(table: 'products').paginate(perPage: 100);
```

!!! tip "Pick perPage deliberately"
    A large `perPage` trades round-trips for payload size and render cost. For a
    dense table twenty-five is a sensible default; for a chart that plots a
    whole series, set it high enough to fetch the series in one page rather than
    looping over pages.

## Aggregates run in the database

Counting a table by loading every row and calling `.length` is the classic way
to melt a dashboard. Beak's stat tiles and KPI blocks never do that. They carry
a `BeakAggregateSpec`, which the backend pushes down into a `COUNT`, `SUM`, or
`AVG` over a filtered query. No rows cross the wire.

```dart title="packages/beak_core/lib/src/query/beak_aggregate_spec.dart"
const price = BeakDecimalColumn(key: 'price', label: 'Price');

// "How many products are in stock?"
final activeCount = BeakAggregateSpec.count(
  table: 'products',
  filter: BeakFieldFilter(
    column: const BeakBoolColumn(key: 'in_stock', label: 'In stock'),
    operator: BeakOperator.eq,
    value: BeakValue.of(true),
  ),
);

// "What is the average product price?"
final avgPrice = BeakAggregateSpec.avg(table: 'products', column: price);
```

The translator builds the same scoped, filtered query it would for a list, then
hands it to the aggregate terminal instead of a row fetch:

```dart title="packages/beak_backend/lib/src/data/worm/query_translator.dart"
/// Builds the scoped, filtered worm query behind [spec]; the data source
/// picks the aggregate terminal (count/sum/avg).
QueryBuilder<WormRecordModel> aggregateBuilderFor(
  BeakAggregateSpec spec,
  DatabaseAdapter adapter,
) {
```

A dashboard with a dozen stat tiles is a dozen cheap aggregate queries, each one
a single number, not a dozen full-table scans. Filters on the spec become the
aggregate's `WHERE`, so "orders placed this week" costs exactly one query.

## Batched reference resolution

A table cell that shows a foreign key by name (a product's category, an order's
customer) has a resolution to do: turn an id into a display label. Doing that
one cell at a time is another N+1 waiting to happen. `ReferenceCache` collapses
it.

```dart title="packages/beak_frontend/lib/src/data/reference_cache.dart"
/// Coalesces reference lookups into batched fetches and caches the results
/// - many cells resolving the same or sibling references within a frame
/// cost one `batchGet` per table, never N `getOne`s.
```

Every cell that needs a reference calls `resolve`. Calls that land in the same
microtask window are coalesced into a single `batchGet` per table, and results
are cached until you invalidate them:

```dart title="packages/beak_frontend/lib/src/data/reference_cache.dart"
Future<BeakRecord> resolve(String table, Object id) {
  final cached = _recordsByTable[table]?[id];
  if (cached != null) {
    return Future.value(cached);
  }
  final pending = _pendingByTable.putIfAbsent(table, () => {});
  final existing = pending[id];
  if (existing != null) {
    return existing.future;
  }
  final completer = Completer<BeakRecord>();
  pending[id] = completer;
  if (pending.length == 1) {
    scheduleMicrotask(() => _flush(table));
  }
  return completer.future;
}
```

The cache is registered as a singleton for you, so cells share one instance and
one batch. After a mutation, drop the touched id so the next resolve refetches:

```dart title="packages/beak_frontend/lib/src/data/reference_cache.dart"
final category = await referenceCache.resolve('categories', categoryId);
// ...after editing that category:
referenceCache.invalidate('categories', categoryId);
```

## Query-count discipline

The four levers add up to a simple habit: for any surface, know its query count
and keep it flat as the data grows. This table is the whole discipline.

| Surface | Cheap shape | The trap it avoids |
| --- | --- | --- |
| A list page | One query for the page, one per eager-loaded relation | Reading an un-loaded relation (it throws, by design) |
| A detail page | Eager-load every relation the layout renders, up front | Per-relation lazy loads while the page paints |
| A stat tile or KPI | One `BeakAggregateSpec` (count/sum/avg) | Loading rows just to count or total them |
| A foreign-key column | `ReferenceCache.resolve`, batched per frame | One `getOne` per cell |
| A chart over a series | One page sized to hold the series | Looping page by page in the client |

!!! warning "Growth is a query-count question, not a row-count question"
    A page that costs a fixed number of queries stays fast as rows multiply. A
    page whose query count scales with rows will not, however fast each query
    is. When a surface feels slow, count its queries before you tune indexes.

## Continue reading

- [Relationships](../models/relationships.md) declare the relations you then
  eager-load.
- [How data flows](../concepts/how-data-flows.md) the query spec that carries
  filters, loads, and the paging window across the wire.
- [Dashboards](../panel/dashboards.md) where aggregate specs become stat tiles
  and KPI blocks.
- [The data source seam](../backend/the-data-source-seam.md) how the translator
  turns a spec into worm queries.
