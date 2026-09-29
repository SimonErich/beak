# Seeding and the API

> Fill the database with repeatable shop data, then call the generated API by hand to see the queries and the graph commit the panel has been sending.

The database holds whatever you typed into forms so far. This chapter replaces that with data that every teammate and every test run gets identically, and then calls the API with `curl` to show what the panel has been sending all along. Seeding is the one topic where the bird theme writes itself: the panel has to eat something.

## What you'll build

- `lib/seeders/shop_seeder.dart`, a seeder that is safe to run twice,
- a database rebuilt from nothing with one command,
- a handful of `curl` calls: a sorted page, a filter with a loaded relation, a search, a hand-written graph commit and its replay, and a commit that is rejected without leaving a trace.

## Before you start

You need chapter 3 finished. Stop `beak dev` if it is running.

One command below drops every table and recreates it, so the rows you made in chapters 1 to 3 are gone afterwards. That is fine on a development SQLite file, and Beak refuses it when `WORM_ENV=production` unless you add `--force`.

## Write the seeder

A seeder is a class with a `name` and a `run` method. The shop's checks whether a row exists before it inserts it, which is what makes a second run harmless. Create `lib/seeders/shop_seeder.dart`. This is a subset of the shop's file, four ids and the rows that use them:

```dart title="lib/seeders/shop_seeder.dart"
import 'package:beak/migrations.dart';

import '../resources/products/models/product.dart';

/// Stable identities shared by the demo and its integration tests.
abstract final class ShopSeedIds {
  /// Espresso beans, €12.50 per unit.
  static const beans = '00000000-0000-4000-8000-000000000008';

  /// A grinder, €48.00 per unit.
  static const grinder = '00000000-0000-4000-8000-000000000009';

  /// Coffee catalog category.
  static const coffeeCategory = '00000000-0000-4000-8000-000000000010';

  /// Equipment catalog category.
  static const equipmentCategory = '00000000-0000-4000-8000-000000000011';

  /// Category attribute definition for roast level.
  static const roastAttribute = '00000000-0000-4000-8000-000000000015';

  /// Category attribute definition for origin.
  static const originAttribute = '00000000-0000-4000-8000-000000000016';

  /// A new catalog product with variants and attributes.
  static const filterCoffee = '00000000-0000-4000-8000-000000000017';
}

/// The stored value of the exact [amount] for [field], such as `'12.50'`.
///
/// Amounts are written the way the API writes them, so a seeded row is
/// indistinguishable from one saved through the panel.
Object? _stored(BeakScalarField<BeakDecimal> field, String amount) =>
    field.encode(BeakDecimal.parse(amount)).raw;

/// Idempotent demonstration data. Existing rows and user edits are preserved.
final class ShopSeeder extends Seeder {
  /// Creates the deterministic demo seeder.
  const ShopSeeder();

  @override
  String get name => 'ShopSeeder';

  @override
  Future<void> run(DatabaseAdapter adapter) async {
    Future<void> insert(String table, Map<String, Object?> values) async {
      final id = values['id'];
      if (id == null) throw StateError('A seed row needs an identity.');
      if (await adapter.selectOne(
            QueryDescriptor(
              table: table,
              where: const Field<Object>('id').eq(id),
              limit: 1,
            ),
          ) !=
          null) {
        return;
      }
      await adapter.insert(InsertDescriptor(table: table, values: values));
    }

    await insert('products', {
      'id': ShopSeedIds.beans,
      'name': 'Espresso Beans',
      'price': _stored(ProductModel.price, '12.50'),
    });
    await insert('products', {
      'id': ShopSeedIds.grinder,
      'name': 'Hand Grinder',
      'price': _stored(ProductModel.price, '48.00'),
    });

    await insert('categories', {
      'id': ShopSeedIds.coffeeCategory,
      'name': 'Specialty coffee',
      'description': 'Single origin beans, blends and seasonal roasts.',
    });
    await insert('categories', {
      'id': ShopSeedIds.equipmentCategory,
      'name': 'Brewing equipment',
      'description': 'Tools for better coffee at home.',
    });

    await insert('category_attributes', {
      'id': ShopSeedIds.roastAttribute,
      'name': 'Roast level',
      'value_type': 'choice',
      'choices': 'Light, Medium, Dark',
      'required': true,
      'category_id': ShopSeedIds.coffeeCategory,
    });
    await insert('category_attributes', {
      'id': ShopSeedIds.originAttribute,
      'name': 'Origin',
      'value_type': 'text',
      'required': false,
      'category_id': ShopSeedIds.coffeeCategory,
    });

    await insert('products', {
      'id': ShopSeedIds.filterCoffee,
      'name': 'Ethiopia — Yirgacheffe',
      'sku': 'COF-ETH',
      'description':
          'Floral washed coffee with citrus notes. Prices are net of exclusive tax.',
      'price': _stored(ProductModel.price, '14.50'),
      'active': true,
      'category_id': ShopSeedIds.coffeeCategory,
    });
  }
}
```

Three details are worth knowing before you run it.

- **Fixed ids.** Every row has an id of its own, named in `ShopSeedIds`. A test can refer to the beans by name instead of searching for a label that someone might rename.
- **The `insert` helper.** It looks the id up and returns when the row exists. Run the seeder again and it fills in what is missing and leaves everything else alone, including an edit a teammate made in the panel.
- **`_stored`.** A seeder writes below the panel: nothing validates the row, nothing fills a default, nothing converts money. The price column stores integer units, so `_stored(ProductModel.price, '12.50')` encodes the amount the way the API would and writes `1250`.

The seeder lives in `lib/seeders/`, which is how `beak prepare` finds it and registers it in the generated server wiring. That is the `1 of 7 files` in the next output. There is nothing for you to register.

## Rebuild the database

```bash
beak migrate fresh --seed
```

```console
$ beak migrate fresh --seed
  3 models · 2 resource classes · screens and overrides not applicable (lib/main.dart is authored)
  generated  1 of 8 files
migrate:fresh complete (6 migration(s) applied).
seeded  ShopSeeder
```

`fresh` dropped every table, ran all six migrations from the first (including the `AddCategoryToProducts` guard from chapter 3, which finds `category_id` already there and does nothing), and `--seed` ran the seeder. Run the seeder once more:

```bash
beak seed
```

```console
$ beak seed
  3 models · 2 resource classes · screens and overrides not applicable (lib/main.dart is authored)
  generated  up to date (8 files)
seeded  ShopSeeder
```

`seeded` means the seeder ran, not that it wrote anything. Beak keeps no record of which seeders ran, so the promise that a second run adds nothing is the seeder's, and the `insert` helper keeps it.

## Run it

Start the API. The panel is optional for this chapter, but if you open it you will see two categories and three products, one of them in the `Specialty coffee` category.

```bash
beak dev
```

Every call below is a `POST` with a JSON body, even the ones that only read. A query is a value (a table, a filter, sorts, a search term, relations to load, a page), and a value fits in a body better than in a URL. Only `table` is required.

Sort by price, one product per page:

```bash
curl -s -X POST localhost:8080/api/products/query \
  -H 'content-type: application/json' \
  -d '{"table":"products","sorts":[{"column":"price","descending":false}],"pagination":{"page":1,"perPage":1}}'
```

```json
{"items":[{"values":{"id":"00000000-0000-4000-8000-000000000008","name":"Espresso Beans","price":1250,"sku":null,"description":null,"active":true,"category_id":null},"relations":{}}],"total":3,"page":1,"perPage":1}
```

`price` is `1250`: twelve euros fifty counted in cents, the stored form from chapter 2. `total` counts every match and not only this page. Note that the nested `sorts` and `pagination` objects carry all of their keys; only the top-level ones are optional.

Filter through a relation and load it in the same call: products whose category name contains `coffee`.

```bash
curl -s -X POST localhost:8080/api/products/query \
  -H 'content-type: application/json' \
  -d '{"table":"products","filter":{"type":"relation","relation":"category","filter":{"type":"field","column":"name","operator":"contains","value":"coffee"}},"relations":[{"relation":"category","filter":null,"nested":[]}]}'
```

```json
{"items":[{"values":{"id":"00000000-0000-4000-8000-000000000017","name":"Ethiopia — Yirgacheffe","price":1450,"sku":"COF-ETH","description":"Floral washed coffee with citrus notes. Prices are net of exclusive tax.","active":true,"category_id":"00000000-0000-4000-8000-000000000010"},"relations":{"category":[{"values":{"id":"00000000-0000-4000-8000-000000000010","name":"Specialty coffee","description":"Single origin beans, blends and seasonal roasts."},"relations":{}}]}}],"total":1,"page":1,"perPage":25}
```

Search, which is a filter that ORs a term over several columns:

```bash
curl -s -X POST localhost:8080/api/products/query \
  -H 'content-type: application/json' \
  -d '{"table":"products","search":{"term":"grind","columns":["name","sku"]}}'
```

```json
{"items":[{"values":{"id":"00000000-0000-4000-8000-000000000009","name":"Hand Grinder","price":4800,"sku":null,"description":null,"active":true,"category_id":null},"relations":{}}],"total":1,"page":1,"perPage":25}
```

Together those are what a list page sends: its sort, its filter chips and its search fill in the body. Writes are different. Every save in the panel goes through one route, `POST /api/commits`, which takes a plan: a list of operations and the order to run them in. Here is one by hand. It creates a category and a product that points at it, using draft ids (`category`, `product`) for records that do not exist yet. Save it as `plan.json` next to `pubspec.yaml`:

```json title="plan.json"
{
  "saveId": "tutorial-grinder-1",
  "root": {"table": "products", "draftId": "product"},
  "operations": [
    {
      "id": "category", "kind": "create",
      "target": {"table": "categories", "draftId": "category"},
      "values": {"values": {"name": "Grinders"}, "relations": {}},
      "references": {}, "dependsOn": []
    },
    {
      "id": "product", "kind": "create",
      "target": {"table": "products", "draftId": "product"},
      "values": {"values": {"name": "Burr Grinder", "price": 6900}, "relations": {}},
      "references": {"category_id": {"table": "categories", "draftId": "category"}},
      "dependsOn": ["category"]
    }
  ]
}
```

`references` says that the product's `category_id` is whatever id the category operation ends up with. Send it:

```bash
curl -s -X POST localhost:8080/api/commits \
  -H 'content-type: application/json' -d @plan.json
```

```json
{"saveId":"tutorial-grinder-1","mode":"atomic","outcomes":[{"id":"category","status":"applied","draftId":"category","resolvedId":"59407a18-8b45-437d-a957-87846e702081","table":"categories","record":{"values":{"id":"59407a18-8b45-437d-a957-87846e702081","name":"Grinders","description":null},"relations":{}}},{"id":"product","status":"applied","draftId":"product","resolvedId":"bd9d9320-f98b-4981-ab62-8d752d26a487","table":"products","record":{"values":{"id":"bd9d9320-f98b-4981-ab62-8d752d26a487","name":"Burr Grinder","price":6900,"sku":null,"description":null,"active":true,"category_id":"59407a18-8b45-437d-a957-87846e702081"},"relations":{}}}],"rootOperationId":"product"}
```

The reply is a receipt with one outcome per operation, and the draft ids have turned into real ones. Send the very same request again and you get the same receipt back with nothing written, because `saveId` is an idempotency key. That is what lets a client retry after a dropped connection without creating two grinders. Change the plan but keep the id and the server says so:

```bash
sed 's/6900/7900/' plan.json | curl -s -i -X POST localhost:8080/api/commits \
  -H 'content-type: application/json' -d @-
```

```text
HTTP/1.1 409 Conflict
{"code":"conflict","message":"Save identity was reused with different content.","requestId":"bc8b34cb521241d5"}
```

Last, a plan that fails halfway. The category is valid and the product has a negative price:

```bash
sed 's/tutorial-grinder-1/tutorial-grinder-2/; s/6900/-6900/; s/"Grinders"/"Hand Mills"/' plan.json \
  | curl -s -X POST localhost:8080/api/commits -H 'content-type: application/json' -d @-
```

```json
{"saveId":"tutorial-grinder-2","mode":"atomic","outcomes":[{"id":"category","status":"unapplied","reason":"rolledBack"},{"id":"product","status":"unapplied","error":{"code":"validation","message":"Validation failed for \"products\".","fieldErrors":{"price":["Must be at least 0."]}},"reason":"rejected"}],"rootOperationId":"product"}
```

The HTTP status is `200`, because the status describes the request and the receipt describes the save. Read `status` on each outcome before you call a save successful. The product was rejected, so the category that came before it was rolled back: no `Hand Mills` exists. Ask for it and the list is empty:

```bash
curl -s -X POST localhost:8080/api/categories/query \
  -H 'content-type: application/json' \
  -d '{"table":"categories","filter":{"type":"field","column":"name","operator":"eq","value":"Hand Mills"}}'
```

```json
{"items":[],"total":0,"page":1,"perPage":25}
```

Back to the seeder's promise. Rename a seeded product, run the seeder again, and look:

```bash
curl -s -o /dev/null -X PATCH localhost:8080/api/products/00000000-0000-4000-8000-000000000009 \
  -H 'content-type: application/json' -d '{"name":"Hand Grinder (ceramic)"}'
beak seed
curl -s -X POST localhost:8080/api/products/query \
  -H 'content-type: application/json' \
  -d '{"table":"products","search":{"term":"ceramic","columns":["name"]}}'
```

```console
  3 models · 2 resource classes · screens and overrides not applicable (lib/main.dart is authored)
  generated  up to date (8 files)
seeded  ShopSeeder
```

```json
{"items":[{"values":{"id":"00000000-0000-4000-8000-000000000009","name":"Hand Grinder (ceramic)","price":4800,"sku":null,"description":null,"active":true,"category_id":null},"relations":{}}],"total":1,"page":1,"perPage":25}
```

The seeder ran and the product is still called `Hand Grinder (ceramic)`. It found the row by its id and left it alone.

> **Note: What just happened**
>
> - Reading is a `POST` to `/api/{table}/query` with a query value, and writing is a `POST` to `/api/commits` with a plan. Those two routes, plus a few for uploads, validation and capabilities, are the surface the panel is built on. It has no private API.
> - A plan is atomic. Its operations run in one transaction in dependency order, and a failure anywhere leaves the database as it was, with a receipt that says which operation failed and which were rolled back.
> - A retry with the same `saveId` and the same plan returns the stored receipt. That is what makes a form safe to submit twice over a bad connection.

> **Question: What this skipped**
>
> - Every route, status code and error shape: [REST API](../reference/rest-api.md).
> - Filters, sorts, searches and relation loads in full: [Queries](../reference/queries.md).
> - How a plan is ordered, checked and recovered: [Graph commits](../architecture/graph-commits.md).
> - Seeder patterns for production, environments and larger datasets: [Seeding](../backend/seeding.md).

## Checkpoint

```bash
beak migrate status
```

```console
$ beak migrate status
  3 models · 2 resource classes · screens and overrides not applicable (lib/main.dart is authored)
  generated  up to date (8 files)
Migration                                        | Batch | Status
-----------------------------------------------------------------
[x] 20260926_000000_beak_commit_receipts             | 1     | applied
[x] 20260927_000000_beak_outbox                      | 1     | applied
[x] 20260929_174129_create_categories_table          | 1     | applied
[x] 20260929_174339_create_products_table            | 1     | applied
[x] 20260929_174548_create_category_attributes_table | 1     | applied
[x] 20260929_174611_add_category_to_products         | 1     | applied
```

Six applied, all in batch 1 because `fresh` ran them together. Your timestamps differ. Your project now has data you can rebuild in seconds and an API you have called with nothing but `curl`. Next the panel gets shaped: better columns, filters, search and an overview page.

## Continue reading

- [Shaping the panel](05-shaping-the-panel.md): choose table columns, filters and search sources, and add an overview page.
- [REST API](../reference/rest-api.md): the routes and receipts you called by hand.
- [Seeding](../backend/seeding.md): environments, production seeds and updating reference data.
