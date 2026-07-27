---
title: 4. Relationships and rich columns
description: Add tags and the rich product model (enum badges, a currency column, image uploads) plus belongs-to and belongs-to-many relationships.
---

# 4. Relationships and rich columns

Categories were the warm-up. By the end of this chapter your store has a real
catalog: a `Product` with a status badge, a euro price, a photo, a category it
belongs to, and a set of tags. The products page will show the category as a
link and the tags as badges, all from one set of typed column definitions.

You already met `BeakStringColumn` on `Category`. A product needs more kinds of
column, so this is where the one-definition promise starts to pay off: each
`const` column you declare below feeds the table cell, the form field, the
detail row, the filter, and the API validator at once.

## A second lookup table: tags

Tags are the simplest model in the store, even simpler than categories: an id
and a name. They exist to be attached to products, so define them first.

```dart
import 'package:beak_core/beak_core.dart';

/// Typed column constants of the tags resource.
abstract final class TagColumns {
  static const id = BeakStringColumn(
    key: 'id',
    label: 'Id',
    visibleOn: {BeakContext.detail},
  );

  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakMaxLength(60)],
  );

  static const List<BeakColumn> values = [id, name];
}

/// The tags resource: free-form labels attached to products.
final class TagModel extends BeakModel {
  const TagModel();

  @override
  String get table => 'tags';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => TagColumns.values;
}
```

The `displayColumnKey` is the field Beak shows whenever it needs to name a tag
in one line: a badge on a product, an option in a picker, a link target. Point
it at `name` and every surface that references a tag shows the tag's name.

## The product model

`Product` is the showcase. Its columns cover every major kind at once, so read
`ProductColumns` in groups rather than top to bottom.

### The columns you already know

Strings, text, and integers work exactly as they did on `Category`. The `id` is
detail-only, the `name` is required and searchable, the `description` is a
longer `BeakTextColumn`, and `stock` is a whole number that cannot go negative.

```dart
import 'package:beak_core/beak_core.dart';

abstract final class ProductColumns {
  static const id = BeakStringColumn(
    key: 'id',
    label: 'Id',
    visibleOn: {BeakContext.detail},
  );

  static const name = BeakStringColumn(
    key: 'name',
    label: 'Name',
    searchable: true,
    sortable: true,
    rules: [BeakRequired(), BeakMaxLength(255)],
  );

  static const description = BeakTextColumn(
    key: 'description',
    label: 'Description',
    searchable: true,
    visibleOn: {BeakContext.form, BeakContext.detail},
  );

  static const stock = BeakIntColumn(
    key: 'stock',
    label: 'Stock',
    min: 0,
    sortable: true,
    rules: [BeakMin(0)],
  );
```

### A status badge: the enum column

A product moves through `draft`, `published`, and `archived`. Model that set as
a real Dart enum, then hand it to a `BeakEnumColumn`. The generic keeps the
whole column type-safe: `values`, `defaultValue`, and `badgeColors` all speak in
`ProductStatus`, so there is no place for a stray string state to creep in.

```dart
enum ProductStatus {
  draft,
  published,
  archived,
}

  static const status = BeakEnumColumn<ProductStatus>(
    key: 'status',
    label: 'Status',
    values: ProductStatus.values,
    defaultValue: ProductStatus.draft,
    filterable: true,
    badgeColors: {
      ProductStatus.draft: BeakColor.muted,
      ProductStatus.published: BeakColor.success,
      ProductStatus.archived: BeakColor.warning,
    },
  );
```

`badgeColors` maps each value to a semantic `BeakColor`. In the table the status
renders as a colored pill; in the form it becomes a select bound to the same
three values. You will reach for `filterable: true` again in chapter 6.

### A price with a currency prefix: the decimal column

`BeakDecimalColumn` is a fractional number. Give it a `prefix` and its rendering
switches from a plain number to a currency-style amount, so `12.5` shows as
`€12.50`.

```dart
  static const price = BeakDecimalColumn(
    key: 'price',
    label: 'Price',
    prefix: '€',
    sortable: true,
    filterable: true,
    rules: [BeakRequired(), BeakMin(0)],
  );
```

### A product photo: the image column and its transform pipeline

`BeakImageColumn` is a thumbnail in table cells, an image picker in forms, and
the full image on the detail page. The upload rules (max size, allowed types)
and the `transforms` pipeline run server-side on upload, and Beak mirrors them
on the client for fast feedback before the file ever leaves the browser.

```dart
  static const image = BeakImageColumn(
    key: 'image',
    label: 'Image',
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
  );
```

The `transforms` run in order: generate a 160×160 thumbnail, then re-encode the
upload as WebP. The stored value is a file key, not the bytes; where those bytes
live (memory, local disk, S3, MinIO) is a storage-driver decision covered in
[Files and storage columns](../models/files-and-storage-columns.md).

### The foreign key and timestamps

`category_id` is the raw foreign key the belongs-to relationship reads. It is
form-only because the relationship (next section) is what appears on the table
and detail pages. The two timestamps are stamped by the backend.

```dart
  static const categoryId = BeakStringColumn(
    key: 'category_id',
    label: 'Category',
    visibleOn: {BeakContext.form},
  );

  static const createdAt = BeakDateTimeColumn(
    key: 'created_at',
    label: 'Created',
    sortable: true,
    visibleOn: {BeakContext.detail},
  );

  static const updatedAt = BeakDateTimeColumn(
    key: 'updated_at',
    label: 'Updated',
    format: BeakDateFormat.relative,
    sortable: true,
    visibleOn: {BeakContext.table, BeakContext.detail},
  );

  static const List<BeakColumn> values = [
    id,
    name,
    description,
    price,
    stock,
    status,
    image,
    categoryId,
    createdAt,
    updatedAt,
  ];
}
```

The `values` list is the display order Beak uses across every surface. Add a
column here and it appears everywhere; leave it out and it exists nowhere.

## Relationships: category and tags

Columns describe a single row. Relationships connect rows across tables. A
product belongs to one category and carries many tags, so it declares one of
each.

```dart
abstract final class ProductRelations {
  /// The category a product is filed under.
  static const category = BeakBelongsTo(
    key: 'category',
    label: 'Category',
    relatedTable: 'categories',
    displayColumnKey: 'name',
    foreignKey: 'category_id',
    searchColumnKeys: ['name'],
  );

  /// The tags attached to a product.
  static const tags = BeakBelongsToMany(
    key: 'tags',
    label: 'Tags',
    relatedTable: 'tags',
    displayColumnKey: 'name',
    pivotTable: 'product_tag',
    foreignPivotKey: 'product_id',
    relatedPivotKey: 'tag_id',
    searchColumnKeys: ['name'],
  );
}
```

`BeakBelongsTo` is the child side of a to-one link: the `products` table holds
`category_id`, and the relationship renders as a link to that category. In the
create form it becomes a searchable single-select over the `searchColumnKeys`.

`BeakBelongsToMany` joins two tables through a pivot. Here `product_tag` pairs a
`product_id` with a `tag_id`; the relationship renders as a badge list on the
detail page and a searchable multi-select in the form. You never write a join
query. You declare the pivot's three names once and Beak reads and writes it.

Both relationships hang off the model through the `relationships` override,
alongside the columns:

```dart
final class ProductModel extends BeakModel {
  const ProductModel();

  @override
  String get table => 'products';

  @override
  String get displayColumnKey => 'name';

  @override
  List<BeakColumn> get columns => ProductColumns.values;

  @override
  List<BeakRelationship> get relationships => const [
    ProductRelations.category,
    ProductRelations.tags,
  ];

  @override
  bool get softDeletes => true;
}
```

`softDeletes` means a deleted product is flagged, not erased, so an order that
references it keeps a valid link. Beak filters soft-deleted rows out of every
list automatically.

!!! note "The other side of the link"
    A relationship is declared from one side, but both resources feel it. Back
    in chapter 2 `Category` already declared a `BeakHasMany` for its products.
    Now that `Product` exists, a category's detail page can list every product
    filed under it. Declaring one relationship, not two, keeps the pair honest.

### The fourth kind: BeakHasOne

Beak has four relationship kinds. Your store uses three: `BeakHasMany` (a
category's products), `BeakBelongsTo` (a product's category), and
`BeakBelongsToMany` (a product's tags). The fourth, `BeakHasOne`, is the
parent side of a to-one link: one row over in the related table points back at
this one.

Your reference store has no natural has-one, so here is the labeled example from
the **showcase app** (`superdashboard`), where an order has exactly one
settling transaction. Do not paste this into your store; it names the
showcase's `transactions` table, which your store does not have.

```dart title="examples/superdashboard/lib/models/commerce/order.dart"
  /// The settling transaction.
  static const transaction = BeakHasOne(
    key: 'transaction',
    label: 'Transaction',
    relatedTable: 'transactions',
    displayColumnKey: 'reference',
    foreignKey: 'order_id',
  );
```

The difference from `BeakBelongsTo` is which table holds the foreign key. In
`BeakBelongsTo` this model's table holds it; in `BeakHasOne` the related table
does. Both render as a link to the single related record.

## The migrations

Models describe the shape; migrations create the tables. Add three migration
classes next to the categories migration you wrote in chapter 2: tags, products,
and the pivot that joins them.

```dart
/// Creates the tags lookup table.
final class CreateTagsTable extends Migration {
  const CreateTagsTable();

  @override
  String get name => '20260701_000200_create_tags_table';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create('tags', (table) {
      table.idUuid();
      table.string('name', length: 60);
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('tags', ifExists: true);
}

/// Creates the products table (soft-deleting, timestamped).
final class CreateProductsTable extends Migration {
  const CreateProductsTable();

  @override
  String get name => '20260701_000400_create_products_table';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create('products', (table) {
      table.idUuid();
      table.string('name');
      table.text('description').makeNullable();
      table.decimal('price');
      table.integer('stock').withDefault(0);
      table.string('status', length: 20).withDefault('draft');
      table.string('image').makeNullable();
      table.uuid('category_id').makeNullable();
      table.timestamps();
      table.softDeletes();
      table.index(['status']);
      table.foreign(
        column: 'category_id',
        references: 'id',
        onTable: 'categories',
        onDelete: OnDelete.setNull,
      );
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('products', ifExists: true);
}

/// Creates the product/tag pivot table.
final class CreateProductTagTable extends Migration {
  const CreateProductTagTable();

  @override
  String get name => '20260701_000500_create_product_tag_table';

  @override
  Future<void> upSchema(Schema schema) async {
    await schema.create('product_tag', (table) {
      table.uuid('product_id');
      table.uuid('tag_id');
      table.unique(['product_id', 'tag_id']);
      table.foreign(
        column: 'product_id',
        references: 'id',
        onTable: 'products',
        onDelete: OnDelete.cascade,
      );
      table.foreign(
        column: 'tag_id',
        references: 'id',
        onTable: 'tags',
        onDelete: OnDelete.cascade,
      );
    });
  }

  @override
  Future<void> downSchema(Schema schema) async =>
      schema.drop('product_tag', ifExists: true);
}
```

The pivot has no id of its own: the `product_id` / `tag_id` pair is its identity,
kept unique so a tag cannot be attached twice. Both foreign keys cascade, so
detaching a product cleans up its pivot rows.

Register the three new migrations in `the generated migration list`, after the categories
migration. Your store's remaining tables (users, orders, order items) join this
list in the next chapter.

```dart
const List<Migration> the generated migration list = [
  CreateCategoriesTable(),
  CreateTagsTable(),
  CreateProductsTable(),
  CreateProductTagTable(),
];
```

## Register the models

The migrations build the tables; the model registry tells Beak what those tables
mean. Add `ProductModel` and `TagModel` to the shared `beakModels` list
that both the server and the panel read.

```dart
const List<BeakModel> beakModels = [
  ProductModel(),
  CategoryModel(),
  TagModel(),
];
```

Then surface products and tags in the panel by adding a `BeakResource` for each.
Filters and actions come in chapter 6, so keep these plain for now.

```dart
  resources: const [
    BeakResource(
      model: ProductModel(),
      icon: BeakIconToken(OiIcons.package),
    ),
    BeakResource(
      model: CategoryModel(),
      icon: BeakIconToken(OiIcons.folderTree),
    ),
    BeakResource(model: TagModel(), icon: BeakIconToken(OiIcons.tag)),
  ],
```

## Run it

Apply the new migrations from the server package, exactly as you did for
categories.

```bash
cd examples/store
dart run bin/migrate.dart migrate
```

You should see the three pending migrations applied in order:

```text
migrated  20260701_000200_create_tags_table
migrated  20260701_000400_create_products_table
migrated  20260701_000500_create_product_tag_table
```

Restart the server so it picks up the new models, then hot-restart the Flutter
panel. The sidebar now lists Products and Tags. Open a product and its detail
page shows the category as a link and the tags as badges; open the create form
and the category is a searchable single-select, the tags a multi-select, the
status a colored dropdown.

!!! note "What just happened"
    - You declared every major column kind on one model: string, text, int,
      decimal, enum, image, and datetime.
    - One `const BeakEnumColumn<ProductStatus>` drives the table badge, the form
      select, and the filter, with no stringly-typed status anywhere.
    - Two relationships (`BeakBelongsTo`, `BeakBelongsToMany`) turned two tables
      and a pivot into a category link and a tag badge list, with no join query
      in sight.
    - Three migrations created the tables; adding the models to `beakModels`
      wired them into both the API and the panel.

!!! question "What this skipped"
    - Where uploaded images physically live, and how storage drivers resolve a
      file key to a URL: [Files and storage columns](../models/files-and-storage-columns.md).
    - The full set of validation rules you can attach to a column
      (`BeakRequired`, `BeakMin`, `BeakMaxLength`, and more):
      [Validation rules](../models/validation-rules.md).

## Continue reading

- [5. Seeding a flock of data](05-seeding-a-flock-of-data.md) fill your new
  tables with a deterministic catalog so the panel has something to show.
- [Relationships](../models/relationships.md) all four relationship kinds and
  their form and detail behavior.
- [Column types](../models/column-types.md) every built-in column and its
  options, in one reference.
