# Performance

> See how Beak keeps query counts low and where to look when a page is slow.

After this page you can reason about how many round-trips a Beak surface costs,
and reach for the levers that keep that number small: relations loaded with the
page, always-on pagination, aggregate pushdown, and paged relation managers.

Beak's performance story is mostly a story about query counts. A dashboard that
fires one query per row is slow no matter how fast the database is. Beak is
built so the obvious thing is also the cheap thing: a list page costs one query,
a show page costs one query, and a stat tile costs one query that returns a
single number.

## Beak never lazy-loads

There is no lazy loading anywhere in Beak. Reading a relation that was not
eager-loaded gives you nothing, rather than quietly firing a query behind your
back. That sounds strict, and it is: it is the rule that makes the N+1 query
problem impossible instead of merely discouraged.

You declare what a surface needs up front, and the backend loads it in bulk.

```dart title="packages/beak_core/lib/src/query/beak_relation_load.dart"
/// An eager-load directive: which relation to load with the main query,
/// optionally constrained and with nested loads of its own.
///
/// Beak never lazy-loads; every relation a surface needs is declared up
/// front through directives like this one (reference-dedup happens in the
/// backend). User code obtains loads through the spec's typed `withRelation`
/// builder, which reads the key from a relationship constant.
```

You rarely build these directives by hand. You chain the spec's typed
`withRelation` builder off a relationship constant, and it records the key for
you:

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

A `BeakRelationLoad` also carries an optional `filter` to constrain which
related rows load, and `nested` directives to eager-load the related model's own
relations in the same pass:

```dart title="packages/beak_core/lib/src/query/beak_relation_load.dart"
/// // Load an order's line items that are still pending, and each item's
/// // product in turn.
/// const load = BeakRelationLoad(
///   'items',
///   filter: BeakFieldFilter.forKey(
///     'status',
///     BeakOperator.eq,
///     BeakStringValue('pending'),
///   ),
///   nested: [BeakRelationLoad('product')],
/// );
```

## A list page is one query

A generated table asks for its rows and every to-one relationship of its model
in the same spec. Nothing on the page has to look a foreign key up afterwards,
because the related record arrived with the row.

```dart title="packages/beak_frontend/lib/src/data/beak_relation_loads.dart"
/// Returns [spec] eager-loading every to-one relationship of [model] it does
/// not already load.
///
/// Without them a foreign key renders as the uuid it stores — the panel showed
/// `a3f9c1e2-…` where the reader expected `Beverages`. Loading them with the
/// page costs one query rather than one per row, which is the whole reason
/// this is a list rather than a lookup.
```

The table then renders a column per to-one relationship, showing the related
record's display value, and hides the raw foreign-key column that would show the
same fact twice, once unreadably. You get "Beverages" instead of
`a3f9c1e2-…`, at no extra cost.

> **Note: What just happened**
>
> - The table asked for the relations, so every caller gets names instead of
>   uuids without knowing to request them.
> - One page, one request. Behind it, the backend resolves each eager-load in
>   one batched pass for the whole page: a hundred products with a category
>   is the page query plus one `WHERE id IN (...)`, never a hundred and one.
> - A relation nobody asked for is never loaded, so an accidental N+1 cannot
>   hide: there is no code path that would issue it.

## A show page is one query too

The generated show page loads the record and the relations its layout renders in
one request. With no additional relation requests it uses `getOne`; requested
eager relations use a single filtered query because `getOne` cannot carry them.

```dart title="packages/beak_frontend/lib/src/data/beak_relation_loads.dart"
/// Loads the [id] record of [model] with [relations] eager-loaded, in one
/// request.
///
/// Without additional relation requests, use [BeakDataSource.getOne]: a
/// transport can support record lookup without allowing primary-key filters
/// on its list queries. Any relations already included in that record survive.
/// When relations are requested, load them with the record in a single query;
/// the caller reads each relation off [BeakRecord.relations].
```

The relation managers on that page are then seeded with what already arrived, so
the tabs paint without going back to the server:

```dart title="packages/beak_frontend/lib/src/detail/relation_manager.dart"
  /// The related records the parent already loaded, if any.
  ///
  /// A detail page eager-loads every relation with the record it shows, so
  /// passing them here means N managers cost zero extra queries on first
  /// paint. Any mutation still refetches.
  final List<BeakRecord>? initialRecords;
```

One exception, and it is deliberate: a resource with a custom `detail:` layout
renders whichever blocks it names, which the page cannot know statically, so
those blocks load their own data. If a bespoke show page feels chattier than the
default one, that is why.

## Relation managers page their rows

A to-many can be unbounded. The manager reads a page of it and offers the next
one, instead of pretending the first page is everything:

```dart title="packages/beak_frontend/lib/src/detail/relation_manager.dart"
  /// How many related rows to read at a time.
  ///
  /// A to-many can be unbounded, so the manager reads a page and offers to
  /// read the next one rather than pretending the first page is all of it.
  final int pageSize;
```

The count beside it is the real total, not the page size, so a parent with 400
children says 400 and offers to load the rest. An order with two line items and
an order with two thousand cost the same first paint.

That paging is what a has-many needs, because it is a query of its own. A
many-to-many is different: its pivot comes back whole with the parent, so the
manager already holds everything and shows it without paging.

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

> **Tip: Pick perPage deliberately**
>
> A large `perPage` trades round-trips for payload size and render cost. For a
> dense table twenty-five is a sensible default; for a chart that plots a
> whole series, set it high enough to fetch the series in one page rather than
> looping over pages.

## Aggregates run in the database

Counting a table by loading every row and calling `.length` is the classic way
to melt a dashboard. Beak's stat tiles and KPI blocks never do that. They carry
a `BeakAggregateSpec`, which the backend pushes down into a `COUNT`, `SUM`, or
`AVG` over a filtered query. No rows cross the wire.

The shop's `overview.dart` uses typed count aggregates for open orders and
low-stock variants. Its `ShopReceivablesCard` sums invoice amounts on the source
and formats the resulting minor units without fetching all invoices.

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

Some places still turn an id into a label one widget at a time: a belongs-to
picker on a form, prefilled with the record it points at. `ReferenceCache`
collapses those into one round-trip.

```dart
/// Coalesces reference lookups into batched fetches and caches the results
/// — many cells resolving the same or sibling references within a frame
/// cost one `batchGet` per table, never N `getOne`s.
```

Calls that land in the same microtask window are coalesced into a single
`batchGet` per table, and results are cached until you invalidate them. The
cache is registered as a singleton by `registerBeakDependencies`, so every
picker on a form shares one instance and one batch.

```dart
/// final category = await referenceCache.resolve('categories', categoryId);
/// // ...after editing that category:
/// referenceCache.invalidate('categories', categoryId);
```

## Hide a resource without removing it

A panel with forty resources in the sidebar is slow for the person using it. Any
resource can be kept out of the navigation from `beak.yaml` without losing
anything else:

The canonical shop registers `OrderResource` in the panel and reaches owned order
items through `OrderModel.items.tableForm(...)`; it does not need a separate line
item navigation entry. Schema registration still provides the relationship
metadata and API contracts.

The model stays registered, the REST endpoints stay generated, and the resource
stays reachable as the far side of a relationship. All it loses is the sidebar
entry. Line items, pivots and lookup tables usually should not have one anyway.

## Query-count discipline

The levers add up to a simple habit: for any surface, know its query count and
keep it flat as the data grows. This table is the whole discipline.

| Surface | Cheap shape | The trap it avoids |
| --- | --- | --- |
| A list page | One query: the page plus every to-one relation | One lookup per cell to turn a foreign key into a name |
| A show page | One query: the record plus the relations the layout renders | One round trip per relation panel |
| A relation tab | Seeded from the parent's load, then paged | Reading an unbounded to-many whole |
| A stat tile or KPI | One `BeakAggregateSpec` (count/sum/avg) | Loading rows just to count or total them |
| A form's picker | `ReferenceCache`, batched per frame | One `getOne` per picker |
| A chart over a series | One page sized to hold the series | Looping page by page in the client |

You do not have to take any of this on trust. `BeakRecordingDataSource`, from
`package:beak/testing.dart`, wraps a working source and records every call, so a
widget test can assert that a screen costs one `query` and that the spec carried
the relation loads you expected. [Testing](testing.md) covers it.

> **Warning: Growth is a query-count question, not a row-count question**
>
> A page that costs a fixed number of queries stays fast as rows multiply. A
> page whose query count scales with rows will not, however fast each query
> is. When a surface feels slow, count its queries before you tune indexes.

Then tune indexes. `@Column(indexed: true)` puts an index in the generated
migration, `@Column(unique: true)` makes it a unique one, and every belongs-to
foreign key is indexed without being asked.

## Continue reading

- [Relationships](../models/relationships.md) declare the relations that then load with the page.
- [How data flows](../concepts/how-data-flows.md) the query spec that carries filters, loads, and the paging window across the wire.
- [Testing](testing.md) the recording data source that counts a screen's round-trips.
- [Dashboards](../panel/dashboards.md) where aggregate specs become stat tiles and KPI blocks.
- [The data source seam](../architecture/data-source-seam.md) how the translator turns a spec into worm queries.
