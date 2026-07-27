---
title: Quickstart
description: From an empty folder to a running admin panel with a real REST API, in about a minute.
---

# Quickstart

After this page you have your own panel: a Shelf backend serving a generated
REST API, a Flutter admin talking to it, and a resource you declared yourself.
No Docker, no `.env`, no configuration.

This page assumes you finished [Installation](installation.md).

## 1. Create the project

```bash
beak create acme_admin
cd acme_admin && flutter pub get
```

## 2. Declare a resource

Replace `lib/models/note.dart` with the thing your app is actually about. One
file, one class:

```dart title="lib/models/product.dart"
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'product.beak.dart';

/// Something the shop sells.
@Resource(softDeletes: true, timestamps: true)
final class Product extends BeakSchema {
  /// What the product is called.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(120)])
  late final String name;

  /// The long description shown on the detail page.
  @Column(searchable: true)
  late final BeakText? description;

  /// Shelf price, in the store's currency.
  @Column(sortable: true)
  late final double price;

  /// How many are in stock right now.
  @Column(sortable: true)
  late final int? stock;

  /// The hero image.
  @Image()
  late final BeakImageRef? photo;
}
```

The **field's type picks the column**: `String` is a single-line text column,
`BeakText` is a multi-line one, `double` is a decimal, `BeakImageRef` is an
upload. **Nullability decides required-ness**: `String name` is required and
`int? stock` is not — one rule that covers the form validator, the API's
validation and the database's `NOT NULL` at once.

## 3. Generate

```bash
beak prepare
```

That reads `lib/models/`, `lib/screens/` and `beak.yaml`, and writes:

- `lib/models/product.beak.dart` — typed column constants, the `BeakModel`, the
  relationship constants on both sides, and a typed record view. Committed.
- `lib/beak/{registry,panel,app,server}.g.dart` — the wiring. Committed.
- `lib/migrations/create_products_table.dart` — the migration this resource
  needs and does not have. Written once, then yours: Beak never rewrites a
  migration it has written.
- `lib/main.dart`, `bin/serve.dart`, `bin/migrate.dart` — the entrypoints, at
  the paths Flutter and Dart expect. Git-ignored, because nothing about them is
  a decision worth reviewing. `beak eject main` changes that.

You never register anything. A file under `lib/models/` is a resource.

## 4. Create the table

```bash
beak migrate
```

The migration Beak wrote reads the model rather than repeating it, so the table
and the API cannot drift:

```dart title="examples/store/lib/migrations/create_products_table.dart"
final class CreateProductsTable extends Migration {
  /// Creates the migration.
  const CreateProductsTable();

  @override
  String get name => '20260727_152057_create_products_table';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create('products', (table) {
      BeakBlueprint.defineColumns(table, const ProductModel());
      BeakBlueprint.defineForeignKeys(table, const ProductModel());
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('products', ifExists: true);
}
```

Applying it is still a decision you make. Beak never alters a database on
boot.

## 5. Run it

```bash
beak dev
```

The API is on `http://localhost:8080` and the panel opens against it. You have
a list with search, sort, filters and pagination; a detail page; create and edit
forms validated by the same rules the server enforces; soft-delete with restore;
and CSV export.

Try the API directly:

```bash
curl -X POST localhost:8080/api/products \
  -H 'content-type: application/json' \
  -d '{"name":"Hammer","price":19.5,"stock":7}'

curl -X POST localhost:8080/api/products/query \
  -H 'content-type: application/json' -d '{"table":"products"}'
```

Only `table` is required — every other key of a query spec falls back to its
default, so a request sends just what it means.

## What you did not write

| You wrote | Beak generated |
| --- | --- |
| One 28-line class | Column constants, the model, both sides of every relationship, a typed record view |
| Nothing | 13 REST routes, validated and policy-gated, plus global search |
| Nothing | The panel: list, detail, create, edit, filters, sort, pagination |
| Nothing | The registry, the router, the server host, three entrypoints |

## Continue reading

- [Project structure](project-structure.md) — what each folder is for, and the
  optional files that override a default.
- [Tutorial: First Flight](../tutorial/index.md) — the same ideas at length,
  building a coffee-roastery store one concept at a time.
- [CLI commands](../reference/cli-commands.md) — `create`, `prepare`, `dev`,
  `introspect`, `eject`, `doctor` and the rest.
- [Already have a database?](installation.md) — `beak introspect` writes the
  models from it.
