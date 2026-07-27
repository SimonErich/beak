---
title: Columns and validation
description: Build the roastery's Product schema one column kind at a time, attach rules that hold in the form and in the API, and let beak prepare derive the table from the class.
---

# Columns and validation

Categories are a shelf. Products are what sits on it: prices, stock, a photo, a
spec sheet, a lifecycle state. After this chapter your panel has a Products page
built from one Dart class, with every column kind Beak has and validation that
holds whether the caller is the form or `curl`.

Chapter 1 left you with a `Category` resource, a running API and a panel. Keep
them; nothing here replaces them.

## Start the file

A file under `lib/models/` is a resource. Create `lib/models/product.dart`:

```dart
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'product.beak.dart';

/// A product in the catalog.
@Resource(softDeletes: true, timestamps: true)
final class Product extends BeakSchema {}
```

The two flags are covered at the end. Everything else you add is a field, and
two things decide what a field becomes: its **type** picks the column kind, its
**nullability** decides required-ness in the form validator, the API and the
database at once. `@Column` carries what the type cannot.

The fences below quote `examples/store/lib/models/product.dart`, the finished
file in the Beak repo. Add each group to your own class body in order.

## Text: three kinds, three inputs

```dart title="examples/store/lib/models/product.dart"
  /// What the product is called.
  ///
  /// Non-nullable, so it is required — the form validator, the API's
  /// validation and the column's `NOT NULL` all follow from the type.
  @Display()
  @Column(
    searchable: true,
    sortable: true,
    indexed: true,
    rules: [BeakMaxLength(255)],
  )
  late final String name;

  /// The stock-keeping unit, unique across the catalog.
  @Column(
    label: 'SKU',
    searchable: true,
    unique: true,
    rules: [BeakMaxLength(40)],
  )
  late final String sku;

  /// The short description shown in listings.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakText? summary;

  /// The long description, edited as rich text.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakRichText? description;
```

`String` is one line, `BeakText` a textarea, `BeakRichText` a rich-text editor.
Dart has no separate type for "long text", so Beak supplies one.

- `@Display()` marks the field that stands for the record everywhere else: page
  titles, links, pickers, and the label a related record shows. One per schema.
- `label: 'SKU'` because the derived label would be "Sku".
- `searchable` joins the list search and global search. `sortable` gives the
  header a sort. `indexed` and `unique` are read by the migration.
- `visibleOn` keeps the long fields off the table. Omit it and a column appears
  on all three surfaces: table, form, detail.

## Numbers and booleans

```dart title="examples/store/lib/models/product.dart"
  /// Sale price in euros.
  @Column(prefix: '€', sortable: true, filterable: true, rules: [BeakMin(0)])
  late final double price;

  /// Units in stock.
  @Column(suffix: ' pcs', min: 0, sortable: true)
  late final int stock;

  /// Whether the product is featured on the storefront.
  @Column(filterable: true)
  late final bool featured;
```

`prefix` and `suffix` travel with the value, so the cell reads `€18.50` and the
detail row `250 pcs` with no formatter anywhere. A decimal shows two fraction
digits unless `precision` says otherwise; an integer shows none. `min: 0` bounds
the number input on
`stock`; `price` cannot use it, because `min` and `max` belong to `int` fields
and a decimal states its floor as a rule. Getting that wrong is not a runtime
surprise:

```console
$ beak prepare
Cannot generate — fix these first:
  lib/models/product.dart: Product.price is a decimal column, which has no "min". Bounds belong on an `int` field; use rules otherwise.
```

## An enum, rendered as badges

```dart title="examples/store/lib/models/product.dart"
/// Lifecycle states of a product.
enum ProductStatus {
  /// Being drafted, not on sale.
  draft,

  /// Live in the catalog.
  published,

  /// Withdrawn from the catalog.
  archived,
}
```

Declare it above the class, then use it as a field type:

```dart title="examples/store/lib/models/product.dart"
  /// Lifecycle state, rendered as a coloured badge.
  @Column(filterable: true)
  @Badges({
    ProductStatus.draft: BeakColor.muted,
    ProductStatus.published: BeakColor.success,
    ProductStatus.archived: BeakColor.warning,
  })
  late final ProductStatus status;
```

The enum's values become the form's select options and the API's accepted
values. The generated column is a `BeakEnumColumn<ProductStatus>`, so a badge
key that is not a `ProductStatus` does not compile.

`filterable: true` puts a control in the filter bar when a resource declares no
filters of its own: an enum becomes a select, a bool a switch, a string a
contains-search, a date a range. Numbers have no derived control yet, so
`price`'s flag waits for a filter you write in
[chapter 5](05-shaping-the-panel.md).

## Dates, colours and JSON

```dart title="examples/store/lib/models/product.dart"
  /// When the product went on sale.
  @Column(sortable: true, format: BeakDateFormat.relative)
  late final DateTime? publishedAt;

  /// The swatch shown beside the name.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakHexColor? swatch;

  /// Storefront metadata the catalog importer round-trips untouched.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakJson? metadata;
```

`BeakDateFormat.relative` renders "3d ago" instead of a timestamp, and falls
back to the plain date once the record is a month old. `BeakHexColor` gets a
swatch and a picker. `BeakJson` gets a multi-line editor and a `json` database
column: use it for the payload you carry but do not query. Beak keeps the
document as text and never hands you a `Map<String, dynamic>`;
`BeakJson.decode` turns it into a typed tree you can pattern-match. All three
are nullable, because a draft product has none of them.

## Uploads

```dart title="examples/store/lib/models/product.dart"
  /// The product photo.
  ///
  /// The rules are enforced twice from this one declaration: in the browser
  /// before the upload starts, and again in the API — a client that skips the
  /// panel does not skip the check.
  @Image(
    storagePath: 'products',
    maxSizeInBytes: 5 * 1024 * 1024,
    allowedTypes: [BeakFileType.jpeg, BeakFileType.png, BeakFileType.webp],
    thumbnail: BeakDimensions(widthInPixels: 160, heightInPixels: 160),
    transforms: [
      BeakThumbnailTransform(
        size: BeakDimensions(widthInPixels: 160, heightInPixels: 160),
      ),
      BeakFormatTransform.webp(),
    ],
  )
  late final BeakImageRef? image;

  /// The spec sheet customers download.
  @FileField(
    storagePath: 'products/specs',
    maxSizeInBytes: 10 * 1024 * 1024,
    allowedTypes: [BeakFileType.pdf],
  )
  late final BeakFileRef? specSheet;
```

`@Image` adds the image-only parts: a thumbnail rendition for the table and
transforms the server runs on the way in. `@FileField` is the same declaration
without them. Each column gets its own endpoint,
`POST /api/products/<column>/upload`.

The bytes need somewhere to land, and that is the one thing Beak takes no
default on. Point it at a folder in a `.env` beside your `pubspec.yaml`:

```bash title=".env"
BEAK_STORAGE_DRIVER=local
BEAK_LOCAL_ROOT_DIR=storage/uploads
BEAK_LOCAL_PUBLIC_BASE_URL=http://localhost:8080/uploads
```

The same server then serves what it stored, so development needs no S3, no
MinIO and no reverse proxy. `beak create` git-ignores `.env` for you. Leave the
file out and the upload endpoints are not registered at all, which is what a
project with no file columns wants.

## The escape hatch

```dart title="examples/store/lib/models/product.dart"
  /// The stock indicator, drawn by the panel's registered renderer.
  @Custom('stock_bar')
  @Column(visibleOn: {BeakContext.table})
  late final Object? stockLevel;
```

`@Custom` declares a column Beak stores and ships but does not draw. The panel
looks up a renderer registered under the tag `stock_bar`; until you register one
the cell reads `No renderer for "stock_bar"`, and forms skip custom columns
entirely. [Custom columns](../extending/custom-columns.md) covers the builder.

## Options a kind does and does not have

| Option | Kind | What it does |
| --- | --- | --- |
| `prefix`, `suffix` | `int`, `double` | Unit or currency, carried into every rendering |
| `precision` | `double` | Decimal places |
| `min`, `max` | `int` | Number-input bounds |
| `maxLength`, `placeholder` | `String` | Stored length, input hint |
| `format` | `DateTime` | `BeakDateFormat.relative` renders "3d ago" |
| `trueLabel`, `falseLabel` | `bool` | State labels |
| `defaultValue` | an enum | What a new record starts with |

Everything else (`label`, `columnName`, `visibleOn`, `searchable`, `sortable`,
`filterable`, `indexed`, `unique`, `rules`) applies to every kind, and
[Annotations](../reference/annotations.md) lists them in one table. An option on
the wrong kind is the `beak prepare` error above, reported at the field that
asked for it.

## Rules run twice

`rules:` takes `const` rules. There are eleven: `BeakRequired`, `BeakMinLength`,
`BeakMaxLength`, `BeakMin`, `BeakMax`, `BeakEmail`, `BeakUrl`, `BeakPattern` (a
regex plus your own message), `BeakInList`, `BeakAllowedFileTypes` and
`BeakMaxFileSize`.

You never write `BeakRequired()` yourself. A non-nullable field gets it from its
type, which is why `name` declares one rule and its generated column carries
two:

```dart title="examples/store/lib/models/product.beak.dart"
  static const BeakStringColumn name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    rules: [BeakRequired(), BeakMaxLength(255)],
    searchable: true,
    sortable: true,
    indexed: true,
  );
```

That list is read by the form, which blocks the save and marks the field, and by
the API, which answers `422` with the offending column keys:

```json
{
  "code": "validation",
  "message": "Validation failed for \"products\".",
  "fieldErrors": { "sku": ["Must be at most 40 characters."] }
}
```

Same rule, same message, two enforcement points, one declaration.

## What the class annotation turns on

`softDeletes: true` adds a `deleted_at` marker. A `DELETE` writes the marker
instead of removing the row, list queries hide marked rows, and
`POST /api/products/<id>/restore` brings one back.

`timestamps: true` adds `created_at` and `updated_at`, stamped by the API on
every write. `updated_at` also lets a caller make an edit conditional: send the
`updated_at` you read back as an `If-Unmodified-Since` header and a row that
moved on in the meantime answers `409` instead of being quietly overwritten. A
request without the header still writes unconditionally, which is what a script
wants.

Both are per resource. `Category` declares neither and pays for neither.

## Generate and migrate

```console
$ beak prepare
  2 models · 0 screens · 0 overrides
  generated  5 of 9 files
```

Five files: the typed columns and record view in `lib/models/product.beak.dart`,
a migration under `lib/migrations/`, and the three wiring files that now know
about a second resource. Open the migration:

```dart title="examples/store/lib/migrations/create_products_table.dart"
  @override
  Future<void> upSchema(Schema schema) async {
    // Read from the model, so the table and the resource cannot drift:
    // adding a column to the schema class changes the DDL with no second
    // edit here.
    await schema.create('products', (table) {
      BeakBlueprint.defineColumns(table, const ProductModel());
      BeakBlueprint.defineForeignKeys(table, const ProductModel());
    });
  }
```

There is no column list in it. `BeakBlueprint` reads the same model the API and
the panel read and derives the DDL: a type per column kind, `NOT NULL` for every
non-nullable field, the indexes and unique indexes you asked for, and
`deleted_at` because the resource soft-deletes. The table cannot drift from the
class, because it is not a second statement of it.

Run it. Your migration's timestamp is the moment `prepare` wrote it:

```console
$ dart run bin/migrate.dart migrate
migrated  20260727_152057_create_products_table
```

Restart `beak dev`, then hot restart the panel with `R` in the `flutter run`
terminal. Products is in the sidebar, the form has an input per field in
declaration order (the custom column excepted), and the table shows the columns
that opted in.

!!! note "What just happened"
    - One class became a typed column set, a model, a record view, a migration
      and a page. You wrote no SQL and registered nothing.
    - Non-nullable fields became required in the form, in the API, and
      `NOT NULL` in the database.
    - `beak prepare` writes a migration only for a resource that has none, and
      never rewrites one. The file is yours from here.

!!! question "What this skipped"
    - Presentation. Products has a default icon and sits outside the **Catalog**
      section, because `beak.yaml` has no entry for it yet:
      [chapter 5](05-shaping-the-panel.md).
    - Changing a column later. `prepare` will not touch the create-table
      migration, so you write an alter migration:
      [Migrations](../backend/migrations.md).
    - Where uploaded files go in production:
      [Files and storage columns](../models/files-and-storage-columns.md).

A product with no category is a product nobody can find. Next: relationships.

## Continue reading

- [3. Relationships](03-relationships.md) connect Product to categories, tags
  and order lines, and get both sides from one declaration.
- [1. Your first resource](01-your-first-resource.md) the chapter this one builds
  on.
- [Column types](../models/column-types.md) every column kind and its options.
- [Validation rules](../models/validation-rules.md) the eleven rules in full,
  with the exact message each one produces.
- [Annotations](../reference/annotations.md) the complete annotation reference.
