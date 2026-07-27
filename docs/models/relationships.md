---
title: Relationships
description: Declare belongs-to, has-one, has-many, and belongs-to-many links between models, and eager-load them with the query spec.
---

# Relationships

After this page you can wire the four relationship kinds onto a model, point
each at the right foreign key or pivot table, choose what a delete does to
dependent rows, and pull related records back with the query spec.

A relationship is declared once, like a column, and consumed everywhere: the
backend eager-loads it by name, pickers show and search the related record's
display column, and the panel picks a widget per surface. You describe the shape
of the link. Beak does the joining.

## The four kinds

Beak has four relationship types. They split along two axes: which side owns the
foreign key, and whether the link resolves to one record or many.

| Kind | Cardinality | Where the key lives | Renders as |
| --- | --- | --- | --- |
| `BeakBelongsTo` | one | `foreignKey` on **this** table | link to the related record |
| `BeakHasOne` | one | `foreignKey` on the **related** table | link to the related record |
| `BeakHasMany` | many | `foreignKey` on the **related** table | badge list of related records |
| `BeakBelongsToMany` | many | a `pivotTable` pairing both ids | badge list of related records |

They all share one sealed base. The common fields are the same wherever you
look.

```dart title="packages/beak_core/lib/src/relations/beak_relationship.dart"
@immutable
sealed class BeakRelationship {
  /// Creates a relationship named [key] pointing at [relatedTable].
  const BeakRelationship({
    required this.key,
    required this.label,
    required this.relatedTable,
    required this.displayColumnKey,
    this.searchColumnKeys = const [],
  });
```

- **`key`** is the relation name. It matches the relation name on the backing
  ORM model, and the backend eager-loads by it.
- **`relatedTable`** is the physical table on the other end.
- **`displayColumnKey`** is the related column a picker or link shows (a
  category's `name`, an order's `reference`).
- **`searchColumnKeys`** are the related columns a picker searches; it falls back
  to the display column when you leave it empty.

You declare relationships as `static const` constants next to your columns, then
list them on the model's `relationships` getter. Here is the products model's
pair.

```dart
@override
List<BeakRelationship> get relationships => const [
  ProductRelations.category,
  ProductRelations.tags,
];
```

## belongs-to: the child points up

`BeakBelongsTo` is the common case. This model's own table holds a foreign key
column that names one record in `relatedTable`. A product belongs to one
category through `products.category_id`.

```dart
/// The category a product is filed under.
static const category = BeakBelongsTo(
  key: 'category',
  label: 'Category',
  relatedTable: 'categories',
  displayColumnKey: 'name',
  foreignKey: 'category_id',
  searchColumnKeys: ['name'],
);
```

The `foreignKey` is a column on **your** table. It is a plain
[`BeakStringColumn`](column-types.md) you also declare (usually visible only in
the form), and the relationship names it. In a detail view the category shows as
a link; in a form the panel turns it into a searchable single-select that
queries `categories` by `name`.

## has-many: the parent owns a list

`BeakHasMany` is the mirror image. Records in `relatedTable` each carry a foreign
key pointing back at this model. A user has many orders, each order row carrying
`orders.user_id`.

```dart
/// The orders a user placed.
static const orders = BeakHasMany(
  key: 'orders',
  label: 'Orders',
  relatedTable: 'orders',
  displayColumnKey: 'reference',
  foreignKey: 'user_id',
);
```

It renders as a badge list on the detail view and drives a relation manager on
the detail page, where you attach, detach, and open the child rows. `BeakHasMany`
adds an `onDelete`, covered [below](#what-a-delete-does-beakondelete).

## belongs-to-many: joined through a pivot

`BeakBelongsToMany` is a many-to-many link routed through a join table. Each row
in `pivotTable` pairs one of this model's ids (`foreignPivotKey`) with one
related id (`relatedPivotKey`). Products and tags meet in `product_tag`.

```dart
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
```

Two extra knobs shape the picker: `allowCreate` (default `false`) lets the form
create a new related record inline, and `maxAllowed` caps how many may be
attached. In a form this becomes a searchable multi-select.

## has-one: a single owned row

`BeakHasOne` is the one-record cousin of `BeakHasMany`: one record in
`relatedTable` holds the foreign key back to this model. It is not part of the
reference store, so this example is from the **superdashboard** showcase,
where an order has a single settling transaction (`transactions.order_id`).

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

That same superdashboard order shows how the four kinds sit side by side on one
model: a `BeakBelongsTo` customer, a `BeakHasMany` list of items, this
`BeakHasOne` transaction, and more.

## Foreign keys are real columns

A relationship never invents a column. The `foreignKey` and the pivot key
columns are real database columns you define in a migration, and for the
owning-side foreign key, a `BeakColumn` on the model too. The relationship only
names them so Beak knows how to join. Keep the names in sync with your schema
and the panel and API line up automatically. The migrations page shows the
matching `.foreign(...)` and pivot-table definitions on the server side.

## What a delete does: BeakOnDelete

To-many relationships carry an `onDelete` that decides what happens to dependent
rows when the owning record is deleted. The enum mirrors worm's `OnDelete` one
to one, so the backend translates it mechanically.

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

The defaults are chosen to be the safe reading:

- `BeakHasMany` defaults to `BeakOnDelete.restrict`. Child rows are real data, so
  Beak refuses to delete a parent that still has children unless you opt into
  something looser.
- `BeakBelongsToMany` defaults to `BeakOnDelete.cascade`. Pivot rows are pure
  join bookkeeping, so they are removed with their owner.

Set `onDelete` explicitly when a model wants different behavior, for example
`BeakOnDelete.setNull` to orphan children rather than block the delete.

## Eager loading: no lazy reads

Beak does not lazy-load. A relation is only present on a record if you asked for
it, and reading one you did not load is a bug, not a silent extra query. You ask
by adding the relation to the [query spec](../concepts/how-data-flows.md) with
`withRelation`, which takes the typed relationship constant, never a string.

```dart title="packages/beak_core/lib/src/query/beak_query_spec.dart"
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

`withRelation` appends a `BeakRelationLoad` to the spec's `relationLoads`, and
you can pass a `constraint` filter to narrow which related rows come back. The
backend reads `relationLoads` and eager-loads exactly those relations by their
`key`. The panel builds these specs for you from a resource's declared
relationships, so you get the loads without hand-writing them; the API is there
when you compose a query yourself.

!!! note "What just happened"
    - `withRelation(author)` takes a `BeakRelationship` constant, so a typo is a
      compile error, not a runtime miss.
    - The spec is JSON-serializable end to end: the panel ships it, the backend
      rebuilds it with `fromJson`, no string field references anywhere.

## Continue reading

- [Defining models](defining-models.md) where the `relationships` getter lives
  on the model.
- [The model registry](the-registry.md) how related tables are resolved by name.
- [Detail views and dual-mode blocks](../panel/detail-and-dual-mode.md) the
  relation manager that renders a to-many link.
- [The data source seam](../backend/the-data-source-seam.md) how the backend
  translates a relation load into an ORM join.
