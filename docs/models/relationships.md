---
title: Relationships
description: Declare a relationship by naming the related schema class, and let Beak derive the foreign key, the pivot table and the other side.
---

# Relationships

After this page you can link two resources in any of the four shapes, know which
names Beak derives and which ones you can override, choose what a delete does to
dependent rows, and pull related records back with the query spec.

You declare a relationship by giving a field the type of the *related schema
class*. There is no foreign key to name, no pivot table to invent, and no second
declaration on the far side.

## The four kinds

They split along two axes: which side owns the key, and whether the link resolves
to one record or many.

| Annotation | Field type | Cardinality | Where the key lives |
| --- | --- | --- | --- |
| `@BelongsTo` | `Other?` or `Other` | one | this table |
| `@HasOne` | `Other?` | one | the other table |
| `@HasMany` | `List<Other>` | many | the other table |
| `@BelongsToMany` | `List<Other>` | many | a pivot table |

The store's product carries all four:

```dart title="examples/store/lib/models/product.dart"
/// The category this product is filed under.
@BelongsTo(onDelete: BeakOnDelete.setNull)
late final Category? category;

/// The roast profile for this product, if it is coffee.
@HasOne()
late final RoastProfile? roastProfile;

/// The tags attached to this product.
@BelongsToMany(allowCreate: true)
late final List<Tag> tags;

/// The order lines that sold this product.
@HasMany(onDelete: BeakOnDelete.restrict)
late final List<OrderItem> orderItems;
```

## What Beak derives

Everything a hand-written relationship used to spell out comes from the field's
name and the two classes involved:

| Derived | From | Example |
| --- | --- | --- |
| Foreign key (belongs-to) | the field name, plus `_id` | `category` becomes `category_id` |
| Foreign key (has-one, has-many) | this class's name, plus `_id` | `Product` becomes `product_id` |
| Pivot table | both singular table names, sorted, joined by `_` | `products` + `tags` becomes `product_tag` |
| Pivot columns | each singular table name, plus `_id` | `product_id` and `tag_id` |
| Related table | the related class's table | `Category` becomes `categories` |
| Display column | the related class's `@Display()` field | a category's `name` |
| Search columns | the display column, unless `searchOn` says otherwise | `['name']` |
| Label | the title-cased field name, unless `label` says otherwise | `roastProfile` becomes "Roast Profile" |
| The other side | this declaration | `CategoryRelations.products` |

Here is what the first and the third of those became:

```dart title="examples/store/lib/models/product.beak.dart"
/// The category this product is filed under.
static const BeakBelongsTo category = BeakBelongsTo(
  key: 'category',
  label: 'Category',
  relatedTable: 'categories',
  displayColumnKey: 'name',
  foreignKey: 'category_id',
  searchColumnKeys: ['name'],
  onDelete: BeakOnDelete.setNull,
);

// ... the has-one ...

/// The tags attached to this product.
static const BeakBelongsToMany tags = BeakBelongsToMany(
  key: 'tags',
  label: 'Tags',
  relatedTable: 'tags',
  displayColumnKey: 'name',
  pivotTable: 'product_tag',
  foreignPivotKey: 'product_id',
  relatedPivotKey: 'tag_id',
  searchColumnKeys: ['name'],
  allowCreate: true,
);
```

Every derived name has an override on the annotation, for the schema you
inherited rather than designed: `foreignKey`, `pivotTable`, `foreignPivotKey`,
`relatedPivotKey`, `label`, `searchOn`. Reach for them when a name has to match
something that already exists.

## belongs-to: the child points up

`@BelongsTo` is the common case. This table holds a foreign key naming one record
in the other table. A product belongs to one category through
`products.category_id`.

The key column is generated with the relationship, so the two cannot disagree:

```dart title="examples/store/lib/models/product.beak.dart"
/// Foreign key backing [category].
static const BeakStringColumn categoryId = BeakStringColumn(
  key: 'category_id',
  label: 'Category',
  visibleOn: {BeakContext.form},
);
```

It is form-only on purpose. In a form the panel turns it into a searchable
single-select that queries `categories` by `name`. In a list or a detail view the
*relationship* is shown instead, because a uuid tells the reader nothing.

`searchOn` widens what that picker searches, for a record people look up by more
than its name:

```dart title="examples/superdashboard/lib/models/email/email.dart"
/// The sender user, when internal.
@BelongsTo(searchOn: ['name', 'email'])
late final User? sender;
```

Each key is checked against the related schema, so a typo is an error naming the
field rather than a picker that quietly finds nothing.

## has-many: the parent owns a list

`@HasMany` is the mirror image: records in the other table each carry a key
pointing back here. An order has many lines, each line row carrying
`order_items.order_id`.

```dart title="examples/store/lib/models/order.dart"
/// The lines on the order.
@HasMany(onDelete: BeakOnDelete.cascade)
late final List<OrderItem> items;
```

The key name comes from *this* class (`Order` becomes `order_id`), not from the
field name. When the far side's belongs-to field is named after something else,
the two derivations differ and you say so once:

```dart
/// The orders this customer placed. `Order.customer` holds `customer_id`,
/// which is not what `User` alone would derive.
@HasMany(foreignKey: 'customer_id')
late final List<Order> orders;
```

A has-many renders as a tab on the show page with a relation manager inside it,
where you attach, detach and open the child rows.

## belongs-to-many: joined through a pivot

`@BelongsToMany` is a many-to-many routed through a join table. Each pivot row
pairs one of this table's ids with one related id. Products and tags meet in
`product_tag`, which Beak names, keys and migrates:

```dart title="examples/store/lib/migrations/create_product_tag_table.dart"
@override
Future<void> upSchema(Schema schema) => BeakBlueprint.createPivot(
  schema,
  ProductRelations.tags,
  ownerTable: 'products',
);
```

Two knobs shape the picker. `allowCreate` (default `false`) lets the relation
manager create a related record inline, and `maxAllowed` caps how many may be
attached. In a form it becomes a searchable multi-select.

## has-one: a single owned row

`@HasOne` is the one-record cousin of `@HasMany`: exactly one record in the other
table holds the key back to this one. The store's coffee products have at most one
roast profile, and the key lives on `roast_profiles`:

```dart title="examples/store/lib/models/roast_profile.dart"
/// The product this profile roasts.
@BelongsTo(onDelete: BeakOnDelete.cascade, inverse: false)
late final Product product;
```

`Product` declares the parent side with `@HasOne()`, so `RoastProfile` says
`inverse: false` to stop Beak generating a second one. Only the belongs-to side
carries `onDelete`, because only that side owns the constraint.

## Both sides, one declaration

Declare the side you think about. Beak writes the other into the far schema's
part file:

```dart title="examples/store/lib/models/category.beak.dart"
/// Typed relationship constants of the categories resource.
abstract final class CategoryRelations {
  /// The products on the other side of [ProductRelations.category].
  static const BeakHasMany products = BeakHasMany(
    key: 'products',
    label: 'Products',
    relatedTable: 'products',
    displayColumnKey: 'name',
    foreignKey: 'category_id',
    searchColumnKeys: ['name'],
    onDelete: BeakOnDelete.setNull,
  );
}
```

`Category` never mentions products, and it gets a products tab, a relation
manager and an eager-loadable relation anyway. Two rules govern this:

- **An explicit declaration always wins.** Declare the far side yourself and
  Beak emits no second constant for it.
- **`inverse: false` turns generation off.** Use it on `@BelongsTo` and
  `@BelongsToMany` for a lookup table that should not gain a back-reference to
  everything pointing at it.

## Foreign keys are real columns

A relationship never invents storage. The belongs-to key is a real column (the
generated `categoryId` above), the pivot is a real table, and the migration
writes the constraint from the relationship:

```dart title="examples/store/lib/migrations/create_products_table.dart"
await schema.create('products', (table) {
  BeakBlueprint.defineColumns(table, const ProductModel());
  BeakBlueprint.defineForeignKeys(table, const ProductModel());
});
```

`defineForeignKeys` reads each belongs-to and constrains its key against the
related table's `id`, with that relationship's `onDelete`. Every belongs-to key
is indexed without being asked, since the panel joins on it to draw a list page.

## What a delete does: BeakOnDelete

`onDelete` decides what happens to dependent rows when a record goes away. The
enum mirrors worm's `OnDelete` one to one, so the backend translates it
mechanically.

```dart title="packages/beak_core/lib/src/relations/beak_on_delete.dart"
enum BeakOnDelete {
  cascade,
  ormCascade,
  restrict,
  setNull,
  setDefault,
  noAction,
}
```

The defaults are the safe reading of each shape:

| Annotation | Default | Why |
| --- | --- | --- |
| `@BelongsTo` | `setNull` | matches the nullable key column the migration writes |
| `@HasMany` | `restrict` | child rows are real data, so a parent with children refuses to go |
| `@BelongsToMany` | `cascade` | pivot rows are join bookkeeping and leave with their owner |
| `@HasOne` | none | the key lives on the other side, so that side's belongs-to decides |

Set it explicitly when a resource wants something else, as the store's order does
for its lines (`cascade`: deleting the order deletes what was on it).

## Where relationships show up

One declaration, four surfaces, none of which you wire:

- **The list page** renders a column per to-one relationship showing the related
  record's display value rather than its foreign key, loaded with the page in one
  query rather than one per row.
- **The show page** puts a tab per to-many relationship in a "Related" card, each
  holding a relation manager.
- **A form** turns the belongs-to key into a searchable single-select, and offers
  the to-many managers once the record exists.
- **The typed record view** gives you the loaded rows as records, not maps:

```dart title="examples/store/lib/models/product.beak.dart"
/// The eager-loaded category, or null when unloaded or unset.
CategoryRecord? get category => switch (record.relations['category']) {
  [final BeakRecord first, ...] => CategoryRecord.of(first),
  _ => null,
};
```

## Eager loading: no lazy reads

Beak does not lazy-load. A relation is present on a record only if it was asked
for, and reading one that was not loaded gives you nothing rather than a silent
extra query. The panel asks for every to-one relationship when it loads a list
page, and for the relations a show page renders. Compose a spec yourself and you
ask with `withRelation`, which takes the typed relationship constant, never a
string:

```dart
final spec = const BeakQuerySpec(table: 'posts')
    .withRelation(author)
    .withFilter(BeakFieldFilter(
      column: status,
      operator: BeakOperator.eq,
      value: BeakValue.of('published'),
    ))
    .orderBy(createdAt, descending: true)
    .paginate(page: 2, perPage: 50);
```

`withRelation` appends a `BeakRelationLoad` to the spec's `relationLoads`, and it
takes a `constraint` filter when you want to narrow which related rows come back.
The backend reads `relationLoads` and eager-loads exactly those relations by
their `key`.

!!! note "What just happened"
    - `withRelation(author)` takes a `BeakRelationship` constant, so a typo is a
      compile error, not a runtime miss.
    - The spec is JSON-serializable end to end: the panel ships it, the backend
      rebuilds it with `fromJson`, no string field references anywhere.

## Continue reading

- [Defining a resource](defining-models.md) the class these fields live on.
- [Generated code](generated-code.md) the relationship constants in the part file.
- [Detail views and dual-mode blocks](../panel/detail-and-dual-mode.md) the
  relation manager that renders a to-many link.
- [Migrations](../backend/migrations.md) the constraints and pivots on disk.
- [The data source seam](../backend/the-data-source-seam.md) how the backend
  translates a relation load into an ORM join.
