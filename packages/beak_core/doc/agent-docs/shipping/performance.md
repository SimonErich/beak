# Performance

> Count what a Beak surface costs in requests and statements, learn the levers that change it, and see the limits the framework leaves to your server.

Beak's performance questions are mostly questions about counts: how many requests a screen makes, how many statements each request runs, and how much of a table a statement has to read. After this page you can say what a surface costs, which setting changes that, and which limits Beak leaves for your server and proxy to enforce.

Nothing in Beak lazy-loads. A relation nobody asked for is not loaded, and nothing fetches it behind your back, so the classic N+1 query cannot creep in through a getter. The bird makes one trip to the ground, with a shopping list. The price is that the cost of a screen is written down in its query spec, where you can read it.

## At a glance

These counts were taken with worm's `LoggingAdapter` around the endpoint tests' notes fixture (30 rows, page size 25). They are statements on the database, not HTTP requests.

| Operation | HTTP requests | Statements |
| --- | --- | --- |
| List page, no relations | 1 | 2 (a `COUNT`, then the page `SELECT`) |
| Each to-one relation loaded with the page | 0 | +1 (`WHERE id IN (...)` for the page's keys) |
| Each has-many relation loaded with the page | 0 | +1 (`WHERE fk IN (...)`) |
| Each many-to-many relation loaded with the page | 0 | +1 for the pivot rows, +1 for the related rows when the pivot has any |
| `getOne`, or a batch of ids | 1 | 1 |
| Stat tile (`aggregate`) | 1 | 1 |
| Summary with 3 measures | 1 | 3 (one grouped aggregate per measure) |
| CSV export of 5,000 rows | 1 | 20 (ten pages of 500, each with its own `COUNT` and `SELECT`) |

The panel adds what a screen composes. A generated table asks for its rows and for every to-one relation of its model in the same spec, so a foreign key renders as a name and not as a uuid. That page costs 2 statements plus one per to-one relation, in one request.

## Read the cost off the spec

A relation load is a directive in the query spec, so the number of statements a page costs is visible before it runs. The backend resolves each load for the whole page in one batched pass. A hundred products with a category are the count, the page and one `IN` lookup, never a hundred more. Beak's own suite pins this with a count of statements:

```dart title="packages/beak_backend/test/src/endpoints/crud_handlers_test.dart"
test(
  'a paged list with a pivot relation load stays at four queries',
  () async {
    await call('POST', '/api/notes', body: {'id': 'n1', 'title': 'One'});
    await call('POST', '/api/labels', body: {'id': 'l1', 'name': 'hot'});
    await call(
      'POST',
      '/api/notes/n1/relations/labels/attach',
      body: {
        'ids': ['l1'],
      },
    );
    logger.clear();

    const spec = BeakQuerySpec(
      table: 'notes',
      relationLoads: [BeakRelationLoad('labels')],
    );
    await call('POST', '/api/notes/query', body: spec.toJson());

    // count + parent select + pivot select + related select.
    expect(logger.entries, hasLength(4));
  },
);
```

The data source that produces those statements does the count first and the page second:

```dart title="packages/beak_backend/lib/src/data/worm/worm_data_source.dart"
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

The panel adds the to-one loads for you. This is the function that does it, and it leaves any load you supplied alone, because yours may carry a constraint it cannot know about:

```dart title="packages/beak_frontend/lib/src/data/beak_relation_loads.dart"
BeakQuerySpec beakWithToOneLoads(BeakQuerySpec spec, BeakModel model) {
  final loaded = <String>{
    for (final load in spec.relationLoads) load.relationKey,
  };
  var result = spec;
  for (final relation in beakToOneRelationsOf(model)) {
    if (loaded.add(relation.key)) {
      result = result.withRelation(relation);
    }
  }
  return result;
}
```

A show page loads the record and the relations its layout renders with one filtered query. A resource with a custom `detail:` layout renders whichever blocks it names, which the page cannot know in advance, so those blocks load their own data. If a bespoke show page is chattier than the default one, that is why.

Relation tabs on the show page are seeded from what the parent already loaded, and a to-many is paged rather than read whole:

```dart title="packages/beak_frontend/lib/src/detail/relation_manager.dart"
  /// How many related rows to read at a time.
  ///
  /// A to-many can be unbounded, so the manager reads a page and offers to
  /// read the next one rather than pretending the first page is all of it.
  final int pageSize;
```

The default is 25. The count beside the tab is the real total, so a parent with 400 children says 400 and offers the rest. An order with two lines and one with two thousand cost the same on first paint.

## Paging, and what it does not do

Every list query carries a paging window, whether you set one or not. The default is page 1 of 25 rows:

```dart title="packages/beak_core/lib/src/query/beak_pagination.dart"
  const BeakPagination({this.page = 1, this.perPage = 25})
    : assert(page >= 1, 'page is 1-based and must be >= 1'),
      assert(perPage >= 1, 'perPage must be >= 1');
```

Three properties follow from the design, and each has a consequence:

- The server serves at most 200 rows a page (`BeakPagination.maxPerPage`). A request for 100,000 rows gets `LIMIT 200` and an envelope whose `perPage` says 200, while `total` still counts the whole filtered set. The panel's query controller still accepts up to 1,000, so a list that asks for more than 200 receives 200. Ask a summary or an aggregate for totals instead of fetching rows to add up. [Security](security.md) lists it with the other limits.
- Paging is offset paging. Page 400 at 25 rows asks the database to skip 9,975 rows first. Deep pages get slower with depth, and Beak has no keyset (cursor) option. For an export or a scan, use the export route, which pages internally, and not a loop over deep pages.
- Every page runs a `COUNT` over the whole filtered set. The `total` beside the pager is exact, and an exact count on a large table is work the database repeats for each page turn and each keystroke in a search box. Keep filters selective and indexed. There is no switch to turn the count off.

## Indexes, sorting and search

A foreign key is indexed without being asked, because the panel reads through them on every list page:

```dart title="packages/beak_backend/lib/src/data/worm/beak_blueprint.dart"
    for (final key in foreignKeys) {
      table.index(<String>[key]);
    }
```

Nothing else is indexed for you. A column the table sorts or filters by, on a table that will grow, is worth declaring:

```dart title="packages/beak_core/lib/src/schema/beak_schema_annotations.dart"
    this.indexed = false,
    this.unique = false,
```

`indexed: true` puts a plain index in the generated create-table migration, and `unique: true` makes it a unique one that also enforces the constraint. Adding either to a table that already exists is a migration of its own (`beak make:migration <Name> --from-drift` writes it).

Substring search is the one place an index cannot help. `contains` and every `searchable: true` column compile to a case-insensitive match with a leading wildcard:

```dart title="packages/beak_backend/lib/src/data/worm/query_translator.dart"
BeakOperator.contains => pattern(
  Operator.ilike,
  '%${beakEscapeLike(_stringOperand(filter))}%',
),
```

A leading `%` cannot use a b-tree index, so a search reads the table. That is fine at thousands of rows and a decision at millions. Keep `searchable` to the columns people actually search, and put a selective filter (a status, a date range) beside the search term when a table gets large.

## Dashboards: one cheap statement per tile

A stat tile carries a `BeakAggregateSpec`, and the backend runs it as a `COUNT`, `SUM` or `AVG` over a filtered query. No rows cross the wire. The shop's overview has four:

```dart title="examples/clean_beak_config/lib/overview.dart"
BeakGridBlock(
  minColumnWidthInPixels: 220,
  children: [
    BeakMetricBlock(
      label: 'Products',
      icon: OiIcons.package,
      aggregate: const ProductModel().count(),
    ),
    BeakMetricBlock(
      label: 'Orders to fulfill',
      icon: OiIcons.shoppingCart,
      aggregate: const OrderModel().count(
        filter: fulfillmentQueueFilter(),
      ),
    ),
    BeakMetricBlock(
      label: 'Awaiting payment',
      icon: OiIcons.receiptText,
      aggregate: const InvoiceModel().count(
        filter: InvoiceModel.status.eq(InvoiceStatus.issued),
      ),
    ),
    BeakMetricBlock(
      label: 'Low-stock variants',
      icon: OiIcons.layers,
      aggregate: const ProductVariantModel().count(
        filter: ProductVariantModel.stock.lte(5),
      ),
    ),
  ],
),
```

Four tiles are four requests and four statements, each returning a number. A tile that shows a comparison against a `prior` period runs two. A population summary (`model.summary(groupBy: ..., measures: [...])`) runs one grouped aggregate per measure, so eight measures is the ceiling and also eight statements. It returns at most `limit` groups (default 100, at most 500) and reports overflow, but the limit trims the response and not the work: the database still groups the whole matching population.

The panel does not cache completed reads. It refetches a table, a tile or a summary after a write to the same table, and a form session coalesces identical requests that are in flight at the same moment, which keeps a form full of pickers from asking for the same catalog twice. `BeakPanel(refreshPolicy: BeakRefreshPolicy(interval: ...))` adds polling, and each tick runs every mounted surface's queries again. A page that is slow to compute is slow each time it opens.

## The server process

Three properties of the running process matter once the data is large enough that the queries are fine.

### One isolate handles all requests

`shelf_io.serve` runs on the isolate that called it, so CPU work in a handler stops every other request in that process until it finishes. The place this shows is image uploads. An image column decodes the file once, to run its transforms, in pure Dart on that isolate (the dimensions come from the header first, so a file that declares more than the column allows never gets that far). Decoding a 12-megapixel, 18 MiB JPEG stalled a test isolate for 1 - 3 seconds on the machine that wrote this page (noise compresses badly, so this is a worst case; a typical photo is faster). During that time the server answered nothing else. Set `maxSizeInBytes` on every image column, and run two or more server processes behind the proxy if uploads are common (the built-in login keeps its sessions per process, so read the note on that in [Security](security.md) first).

### Graph commits run one at a time per process

Every form save goes through `POST /api/commits`, and commits on one adapter are serialized in-process so snapshot-based transactions cannot interleave. A slow `preparePlan` hook therefore delays every other save on that process, not only its own. Keep hooks to reads the plan needs, and do slow work (email, webhooks) as a durable effect through the outbox, which runs after the transaction. Across several processes the receipt's primary key keeps a save from applying twice.

### Postgres gets a pool of ten connections

`adapterFromUrl` defaults `poolSize` to 10, and `beak_backend` does not expose it through an environment variable. SQLite runs on one connection.

```dart title="packages/beak_backend/lib/src/data/worm/worm_bootstrap.dart"
DatabaseAdapter adapterFromUrl(Uri databaseUrl, {int poolSize = 10}) {
  if (isSqliteUrl(databaseUrl)) {
    final String? path = sqliteFilePathOf(databaseUrl);
    return path == null ? SqliteAdapter.memory() : SqliteAdapter.open(path);
  }
  return _postgresAdapterFromUrl(databaseUrl, poolSize: poolSize);
}
```

The server compressed neither the JSON page nor the streamed CSV export that were checked for this page. Ask the proxy to (`gzip on;` in nginx), for the API's JSON and for the panel's static files alike. The repository's `deploy/nginx.conf` does not enable it yet, and the stock `nginx:alpine` configuration has it commented out, so the panel's JavaScript bundle is served as is.

## Rules and limits

| Limit | Where it is enforced | What to do |
| --- | --- | --- |
| `perPage` is capped at 200 | `BeakQueryAuthorizer`, on `POST /query` | Nothing; for a lower ceiling pass `maxPerPage` to `defaults.build` |
| Request body size is unbounded for JSON | Nowhere in Beak | Set `client_max_body_size` (nginx) or the equivalent at the proxy |
| Upload size is bounded only when the column sets `maxSizeInBytes` | The upload handler, before it buffers the part | Set it on every `@Image` and `@FileField` |
| Relation filters nest at most 16 levels, summaries carry 1 - 8 measures | The translator and `BeakSummarySpec` | Nothing to do, these are guards |
| Exact `total` on every list page | `WormDataSource.query` | Selective, indexed filters; keep tables you page deeply narrow |
| Search is `ILIKE '%term%'` | The query translator | Limit `searchable` columns; filter first |
| One isolate per process, ten Postgres connections | `shelf_io`, `adapterFromUrl` | Run more processes; see [Going to production](going-to-production.md) |

## Verify it

Count statements before you tune anything. A widget test can assert how many `query` calls a screen makes, with `BeakRecordingDataSource`, and an API test can assert how many statements a request runs, by wrapping the adapter in worm's `LoggingAdapter`, as the test quoted above does. [Testing](testing.md) shows both.

On a live Postgres database, log the slow statements and read their plans (as a superuser, or through your provider's setting for the same option):

```console
$ psql "$DATABASE_URL" -c "ALTER SYSTEM SET log_min_duration_statement = '200ms'"
$ psql "$DATABASE_URL" -c "SELECT pg_reload_conf()"
```

Then run `EXPLAIN ANALYZE` on the statement the log shows. When a surface feels slow, count its statements first and read plans second. A page whose statement count grows with its rows will not stay fast, however good each statement is.

## Reference

- `packages/beak_backend/lib/src/data/worm/worm_data_source.dart` and `query_translator.dart` produce every statement above.
- `packages/beak_frontend/lib/src/data/beak_relation_loads.dart` decides which relations a generated page loads.
- [The query contract](../architecture/query-contract.md) describes the spec that carries filters, sorts, loads and the paging window.
- [Graph commits](../architecture/graph-commits.md) covers the transaction and the outbox.

## Continue reading

- [Security](security.md) the limits that are about abuse, not speed.
- [Going to production](going-to-production.md) how many processes, which pool, which proxy.
- [Dashboards](../panel/dashboards.md) where aggregate specs become tiles.
