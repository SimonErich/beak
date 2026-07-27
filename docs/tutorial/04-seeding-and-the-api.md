---
title: Seeding and the API
description: Fill the store with a fixed catalog, then drive the REST surface Beak already generated for it with curl.
---

# Seeding and the API

An empty panel is hard to judge. In this chapter you write a seeder that fills
the store with a small, fixed catalog, then talk to the API your resources
already have: querying, writing, restoring, aggregating, searching and
exporting, all with `curl`.

## A seeder is a file under lib/seeders

Beak discovers seeders the way it discovers everything else. Put a class that
extends `Seeder` in `lib/seeders/`, and the generated host lists it. There is
no registry to update.

Start with the ids. Give every seeded row a primary key you wrote down:

```dart title="examples/store/lib/seeders/store_seeder.dart"
import 'package:beak/migrations.dart';

/// Primary keys of the seeded catalog.
///
/// Fixed and uuid-shaped, so a test or a demo can name a record instead of
/// searching for it: `StoreSeedIds.productEspresso` is the same row on every
/// machine and every run.
abstract final class StoreSeedIds {
  /// The "Coffee" category.
  static const categoryCoffee = '00000000-0000-4000-8000-000000000101';

  // ... the "Gear" category ...

  /// The "hot" tag.
  static const tagHot = '00000000-0000-4000-8000-000000000201';

  // ... the other tags, the two users ...

  /// The espresso beans product.
  static const productEspresso = '00000000-0000-4000-8000-000000000401';

  // ... the rest of the catalog, and the seeded order ...
}
```

Then the seeder itself. `run` gets the database adapter and writes rows. Here
is the shape, with one row of each kind:

```dart
final class StoreSeeder extends Seeder {
  /// Creates the seeder.
  const StoreSeeder();

  @override
  String get name => 'StoreSeeder';

  @override
  Future<void> run(DatabaseAdapter adapter) async {
    Future<void> insert(String table, Map<String, Object?> values) async {
      await adapter.insert(InsertDescriptor(table: table, values: values));
    }

    final DateTime now = DateTime.utc(2026, 6, 30, 9, 30);

    await insert('categories', {
      'id': StoreSeedIds.categoryCoffee,
      'name': 'Coffee',
      'blurb': 'Beans, ground and whole.',
    });

    await insert('tags', {'id': StoreSeedIds.tagHot, 'name': 'hot'});

    await insert('products', {
      'id': StoreSeedIds.productEspresso,
      'name': 'Espresso Beans',
      'sku': 'COF-ESP-1KG',
      'price': 12.5,
      'stock': 42,
      'featured': true,
      'status': 'published',
      'published_at': now,
      'category_id': StoreSeedIds.categoryCoffee,
      'created_at': now,
      'updated_at': now,
    });

    await insert('product_tag', {
      'product_id': StoreSeedIds.productEspresso,
      'tag_id': StoreSeedIds.tagHot,
    });
  }
}
```

The store's copy carries on in the same shape: two categories, three tags, two
users, three products, one roast profile and one order with two lines. Copy the
rest of `examples/store/lib/seeders/store_seeder.dart` into yours, ids and all.
Every count and every total below assumes the whole catalog.

Apply the schema and run it:

```console
beak prepare
dart run bin/migrate.dart migrate
dart run bin/migrate.dart db:seed
```

```console
seeded  StoreSeeder
```

!!! note "What just happened"
    - `beak prepare` found `lib/seeders/store_seeder.dart` and listed
      `StoreSeeder()` in the generated host, next to your migrations.
    - A seeder writes through the adapter, below the model layer. Validation
      rules do not run and timestamps are not filled in for you, which is why
      the product row sets `created_at` and `updated_at` itself.
    - Foreign keys are plain values. `category_id` and the two columns of the
      `product_tag` pivot are the keys `beak prepare` derived from the
      `@BelongsTo` and `@BelongsToMany` you wrote in
      [chapter 3](03-relationships.md).

!!! question "What this skipped"
    Model-backed seeders, factories and running several in order live in
    [Seeding](../backend/seeding.md). Writing and rolling back schema changes
    by hand is [Migrations](../backend/migrations.md).

`db:seed` runs the seeder every time you call it, so a second run collides with
the unique index on `sku`. To start over, drop and rebuild:

```console
dart run bin/migrate.dart migrate:fresh --seed
```

## Why the ids are fixed

A seeder that mints random uuids gives you a different database on every run,
and a test can then only find a row by searching for it. Fixed ids let a test
name the row instead:

```dart title="examples/store/test/api_scenario.dart"
      await staff.attach(
        'products',
        StoreSeedIds.productGrinder,
        'tags',
        const [StoreSeedIds.tagNew],
      );
```

That line is from the store's own suite, which you write in
[chapter 6](06-auth-tests-and-shipping.md).

The same reasoning applies to `now`. A fixed `DateTime.utc(2026, 6, 30, 9, 30)`
keeps a chart's buckets and a "created before" filter stable, so a failing
assertion means a real regression rather than a passing hour.

## The API you already have

Start the backend and leave it running:

```console
beak dev
```

Every registered resource is mounted under `/api/{table}`.

| Method and path | What it does |
|---|---|
| `POST /api/{table}/query` | a page of records from a query spec |
| `POST /api/{table}/aggregate` | one count, sum or average |
| `POST /api/{table}/batch` | the records named by a list of ids |
| `POST /api/{table}` | create |
| `GET /api/{table}/{id}` | one record |
| `PATCH /api/{table}/{id}` | partial update |
| `DELETE /api/{table}/{id}` | soft delete, or `?force=true` for good |
| `POST /api/{table}/{id}/restore` | undo a soft delete |
| `POST /api/{table}/{id}/relations/{key}/attach` | link related ids |
| `POST /api/{table}/{id}/relations/{key}/detach` | unlink them |
| `POST /api/{table}/export` | the same query, as a CSV attachment |
| `GET /api/search?q=` | display labels across every table |
| `GET /healthz`, `GET /readyz` | liveness and readiness |

### Reading a page

```bash
curl -s http://localhost:8080/api/products/query \
  -H 'content-type: application/json' \
  -d '{"table": "products"}'
```

```json
{
  "items": [
    {"values": {"name": "Espresso Beans", "price": 12.5,
                "published_at": {"type": "dateTime",
                                 "value": "2026-06-30T09:30:00.000Z"}},
     "relations": {}}
  ],
  "total": 3, "page": 1, "perPage": 25
}
```

That is one of the three items, trimmed to three of its values; the real body
carries every column of every product on the page.

Scalars travel as themselves. Values JSON has no type for, such as a
`DateTime`, are tagged.

Sorting and paging are two more keys:

```bash
curl -s http://localhost:8080/api/products/query \
  -H 'content-type: application/json' \
  -d '{"table": "products",
       "sorts": [{"column": "price", "descending": true}],
       "pagination": {"page": 1, "perPage": 2}}'
```

Search takes the term and the columns to match it against. An eager load names
a relation, and the related records come back under `relations`, fetched with
the page rather than one query per row:

```bash
curl -s http://localhost:8080/api/products/query \
  -H 'content-type: application/json' \
  -d '{"table": "products",
       "search": {"term": "espresso", "columns": ["name", "sku"]},
       "relations": [{"relation": "category", "filter": null, "nested": []}]}'
```

!!! warning "Nested objects spell out every key"
    The spec itself is forgiving: `{"table": "products"}` is a complete body,
    and every key you leave out falls back to its default. The objects inside
    it are strict. A sort needs `column` and `descending`, a page needs `page`
    and `perPage`, and a relation load needs `relation`, `filter` and `nested`.
    Beak's own client writes all of them, so this only bites a request you type
    by hand.

### Writing

```bash
curl -s http://localhost:8080/api/products \
  -H 'content-type: application/json' \
  -d '{"name": "V60 Dripper", "sku": "GER-V60-02", "price": 24.0,
       "stock": 12, "featured": false, "status": "published"}'
```

A create answers `201` with the stored record, id and timestamps included. Send
a body your columns reject and you get `422` carrying one entry per field that
failed, from the rules the form validates against too. Two of them:

```json
{
  "code": "validation",
  "message": "Validation failed for \"products\".",
  "fieldErrors": {"name": ["This field is required."],
                  "price": ["Must be at least 0."]}
}
```

`PATCH` takes only the columns that changed:

```bash
curl -s -X PATCH http://localhost:8080/api/products/<id> \
  -H 'content-type: application/json' \
  -d '{"price": 26.0, "stock": 10}'
```

### Delete, restore, and the trash

`Product` declares `softDeletes: true`, so a delete answers `204`, stamps
`deleted_at`, and the row stops showing up. `GET` on it is then a `404`. It is
still there. Take the id the create above returned and put it through the whole
lifecycle:

```bash
curl -s -X DELETE http://localhost:8080/api/products/<id>

curl -s http://localhost:8080/api/products/query \
  -H 'content-type: application/json' \
  -d '{"table": "products", "withTrashed": true}'

curl -s -X POST http://localhost:8080/api/products/<id>/restore

curl -s -X DELETE 'http://localhost:8080/api/products/<id>?force=true'
```

`restore` clears the marker and returns the record. `?force=true` deletes it
for good, and even `withTrashed` will not find it again. The catalog is back to
the three seeded products.

### Batch, aggregate, search, export

`batch` fetches known ids in one query, which is what the panel does after a
bulk selection:

```bash
curl -s http://localhost:8080/api/products/batch \
  -H 'content-type: application/json' \
  -d '{"ids": ["00000000-0000-4000-8000-000000000401"]}'
```

`aggregate` computes one number and answers `{"value": 49}`. `count` takes no
column; `sum` and `avg` do:

```bash
curl -s http://localhost:8080/api/products/aggregate \
  -H 'content-type: application/json' \
  -d '{"table": "products", "function": "sum", "column": "stock"}'
```

`GET /api/search` runs one term across every searchable column of every table
and groups the hits by table:

```bash
curl -s 'http://localhost:8080/api/search?q=espresso&perModel=3'
```

```json
{"results": {
  "order_items": [
    {"table": "order_items", "id": "00000000-0000-4000-8000-000000000701",
     "displayLabel": "2× Espresso Beans", "matchedColumnKey": "label"}
  ],
  "products": [
    {"table": "products", "id": "00000000-0000-4000-8000-000000000401",
     "displayLabel": "Espresso Beans", "matchedColumnKey": "name"}
  ]
}}
```

The order line is in there because its `label` is `searchable: true`. Search
covers every resource the caller is allowed to view, which for now is all of
them.

`export` takes the same query spec and answers CSV, headed with your column
labels rather than their keys:

```bash
curl -s http://localhost:8080/api/products/export \
  -H 'content-type: application/json' \
  -d '{"table": "products"}'
```

The header, then a row per product. Here are the first two lines:

```csv
Name,SKU,Price,Stock,Featured,Status,Published At,Image,Spec Sheet,Stock Level,Updated
Espresso Beans,COF-ESP-1KG,12.50,42,true,published,2026-06-30T09:30:00.000Z,,,,2026-06-30T09:30:00.000Z
```

One column per table-context column, in declaration order. `summary`,
`description`, `swatch` and `metadata` are missing because they asked for
`visibleOn: {BeakContext.form, BeakContext.detail}` back in
[chapter 2](02-columns-and-validation.md).

### Probes

Two endpoints sit outside `/api`, so a platform's health checks do not depend
on your auth.

```bash
curl -s http://localhost:8080/healthz   # {"status":"ok"} while the process serves
curl -s http://localhost:8080/readyz    # {"status":"ok"}, or 503 with a reason
```

`/healthz` never touches the database, so an outage cannot put your process in
a restart loop. `/readyz` asks the data source a question, so an outage moves
traffic away instead. That distinction is what keeps a rolling deploy honest.

!!! note "What just happened"
    - You wrote no endpoint. Every route above exists because a class under
      `lib/models/` carries `@Resource()`.
    - The panel is a client of exactly this API. Anything `curl` can do here,
      the panel does the same way.
    - Every call you made was anonymous and allowed, because you have not
      configured auth yet.

!!! question "What this skipped"
    Filters, nested eager loads and optimistic concurrency are in
    [The generated API](../backend/the-generated-api.md); every request and
    response shape is listed in the [REST API](../reference/rest-api.md)
    reference. Locking these routes down is
    [chapter 6](06-auth-tests-and-shipping.md).

## Continue reading

- [Relationships](03-relationships.md) the chapter that produced the foreign
  keys and the pivot this seeder writes to.
- [Shaping the panel](05-shaping-the-panel.md) next: icons, filters, actions,
  layouts and the dashboard.
- [Seeding](../backend/seeding.md) factories, model-backed seeders, and running
  several in order.
- [The generated API](../backend/the-generated-api.md) the full surface and how
  a posted spec becomes a query.
