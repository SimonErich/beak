---
title: Relationships
description: Link resources by naming the other class, and get pickers, relation tabs and name columns in the panel from one field each.
---

# Relationships

After this chapter your records point at each other: a product sits in a
category, carries tags, has a roast profile, and an order lists the lines that
make it up. Each link is one field, and each one changes the form, the list
table and the show page at once.

## One field per link

A relationship is a field whose type is another schema class. Here are all four
kinds, on one product.

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

You name the other class. Beak works out the rest.

| Annotation | Field type | Where the foreign key lives |
| --- | --- | --- |
| `@BelongsTo` | `Other` or `Other?` | a column on **this** table |
| `@HasOne` | `Other?` | a column on the **other** table |
| `@HasMany` | `List<Other>` | a column on the **other** table |
| `@BelongsToMany` | `List<Other>` | a pivot table holding both ids |

Nullability is not the switch here that it is on a column. Beak writes every
foreign key as a nullable column and puts no `BeakRequired()` on it, so
`Category? category` and a non-null `User customer` produce the same column and
the same picker: one the form will submit empty. The `?` documents intent, and
the Dart view agrees with the column rather than with the field, so
`OrderRecord.customer` is a `UserRecord?` either way.

## The models on the other end

Product names four classes, so those four have to exist. Add `Tag`,
`RoastProfile`, `User`, `Order` and `OrderItem` under `lib/models/`, each with
the imports and the `part` line chapter 1 showed. Their columns are chapter 2
work: a `@Display()` name each, plus a user's `email` and `role`, a roast
profile's `level`, and an order's `reference`, `status`, `total` and
`placedAt`. These are the fields this chapter is about.

```dart title="examples/store/lib/models/order.dart"
  /// The customer who placed it.
  @BelongsTo(onDelete: BeakOnDelete.cascade)
  late final User customer;

  /// The lines on the order.
  @HasMany(onDelete: BeakOnDelete.cascade)
  late final List<OrderItem> items;
```

```dart title="examples/store/lib/models/order_item.dart"
  /// The order this line belongs to.
  @BelongsTo(onDelete: BeakOnDelete.cascade, inverse: false)
  late final Order order;

  /// The product this line sells.
  @BelongsTo(onDelete: BeakOnDelete.restrict, inverse: false)
  late final Product product;
```

Then generate.

```console
$ beak prepare
  7 models · 0 screens · 0 overrides
  generated  16 of 20 files
```

!!! note "What just happened"

    - Every schema got a fresh `*.beak.dart`: columns, relationships, model,
      typed record view.
    - Each new table got a migration under `lib/migrations/`, including one for
      a pivot table nobody declared.
    - `lib/beak/*.g.dart` picked up five new resources. You registered nothing.

## belongs-to: the child holds the key

`@BelongsTo` puts the foreign key on this table. `beak prepare` writes that
column too: `category_id`, labelled "Category" after the relationship rather
than after the table it points at, and visible on the form only.

Declaring one side declares both. `Category` says nothing about products, yet
it comes out of `beak prepare` with the matching has-many.

```dart title="examples/store/lib/models/category.beak.dart"
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
```

Pass `inverse: false` when the back-reference is noise, or when the other side
names it itself. `OrderItem` uses it twice: `Order` already calls its children
`items`, and `Product` already calls them `orderItems`.

Two more arguments are worth knowing. The label follows the field name, which is
why the order form's picker reads "Customer" and not "User", and why the
`customer_id` column is filed under "Customer" too. `label:` overrides it.
`searchOn:` widens what the picker searches, from the related model's
display column to a list of your own: `searchOn: ['name', 'email']` finds a
customer by either. Each key is checked against the related schema, so a typo is
an error naming the field.

## has-many: the parent lists the children

`@HasMany` reads the key from the child table and derives it from the parent's
own name. `Order.items` works out of the box for that reason: `OrderItem.order`
stores `order_id`, which is exactly what a has-many on `Order` looks for.

A user's orders are the awkward case. `User` looks for `user_id`, but `Order`
calls its field `customer`, which makes the key `customer_id`. When the two
names disagree, say which one you mean. Add this to `User`:

```dart
/// The orders this customer placed.
@HasMany(foreignKey: 'customer_id', onDelete: BeakOnDelete.cascade)
late final List<Order> orders;
```

You can also leave the field out. `@BelongsTo` on `Order.customer` generates
`orders` on `User` anyway, with `customer_id` already filled in.

## has-one: one child, not a list

`@HasOne` is a has-many with the list taken away: at most one record on the
other table points back. The key and the delete behaviour live over there, on
the belongs-to. `@HasOne()` takes two arguments, `label:` and `foreignKey:`, and
the product side needs neither: the key it looks for is `product_id`, which is
exactly what `RoastProfile.product` stores.

```dart title="examples/store/lib/models/roast_profile.dart"
  /// The product this profile roasts.
  @BelongsTo(onDelete: BeakOnDelete.cascade, inverse: false)
  late final Product product;
```

## belongs-to-many: the pivot Beak writes

`@BelongsToMany` needs a join table. Beak names it from the two singular table
names, sorted and joined with an underscore, so `products` and `tags` give
`product_tag`, and it writes the migration.

```dart title="examples/store/lib/migrations/create_product_tag_table.dart"
  @override
  Future<void> upSchema(Schema schema) => BeakBlueprint.createPivot(
    schema,
    ProductRelations.tags,
    ownerTable: 'products',
  );
```

The pivot holds `product_id` and `tag_id`, a unique constraint on the pair, an
index on the second column so a tag can list its products without a full scan,
and a cascading foreign key on each side. It has no `id`: the pair is the key.
`allowCreate: true` records that a tag may be created from the picker rather
than on the tags page, and `maxAllowed:` caps how many may be attached. `Tag`
gains `products` the way `Category` gained its list.

## What a delete does

`onDelete` answers "someone deleted the record on the other end".

| Value | Effect |
| --- | --- |
| `cascade` | delete the dependent rows too |
| `restrict` | refuse the delete while dependents exist |
| `setNull` | keep them, clear the foreign key |
| `ormCascade` | delete them one by one, firing model hooks |
| `setDefault`, `noAction` | leave it to the database |

Deleting a category unfiles its products (`setNull`). Deleting an order takes
its lines with it (`cascade`). Deleting a product that was ever sold fails
(`restrict`): an invoice line pointing at nothing is worse than a refused
delete.

## What you get in the panel

None of this is configured. It follows from the fields.

| Surface | What a relationship adds |
| --- | --- |
| Form | a picker per belongs-to: searches the related table as you type, shows the display column, stores the id. A to-many needs a saved record to attach to, so its manager appears on the edit form and not on create |
| List table | the related record's name in place of the foreign key it owns, never both, eager loaded with the page in one query |
| Show page | one tab per to-many, in a "Related" card under the fields |
| Relation tab | the related records, a badge carrying the true total rather than the page size, "Load more", and delete (has-many) or attach and detach (belongs-to-many) |
| Dart | `ProductRecord.category` as a `CategoryRecord?`, `.tags` as a `List<TagRecord>` |

## Keep a table out of the sidebar

Order lines are always reached through their order. They still need an API, a
model and their relationships, so deleting the resource is the wrong tool. Hide
it with one entry under `resources:` in `beak.yaml`.

```yaml title="examples/store/beak.yaml"
  order_items:
    hidden: true
```

Only the sidebar entry goes. The API still answers, the relationships still
load, and the Items tab on an order still lists the rows.

## Run it

The new tables need creating, and `products` needs the `category_id` column it
did not have when you first migrated. That migration has already run and will
not run again, and its DDL is read from the model, so rebuilding the database
from scratch is what picks the new column up. Nothing in it is worth keeping.

```console
$ dart run bin/migrate.dart migrate:fresh
$ beak dev
```

Open the panel. Products, categories, tags, roast profiles, users and orders are
in the sidebar; order items are not. Create a category, then a product: the
create form has a Category picker. Save it and edit it again, and a Tags
multi-select and an Order Items list are waiting below the fields, because
attaching a row takes a row to attach it to. The show page carries a "Related"
card with a Tags tab and an Order Items tab, and back on the list the Category
column reads the category's name rather than a uuid.

!!! question "What this skipped"

    - The tables are empty, so the pickers have little to find.
      [Seeding and the API](04-seeding-and-the-api.md) fills them and shows what
      a relationship looks like over HTTP.
    - Icons, sections and layouts for the new resources are
      [Shaping the panel](05-shaping-the-panel.md).
    - Adding a column to a table that already exists deserves its own migration
      rather than a `migrate:fresh`. See [Migrations](../backend/migrations.md).

## Continue reading

- [Seeding and the API](04-seeding-and-the-api.md) put data behind the
  relationships, then read it back over REST.
- [Columns and validation](02-columns-and-validation.md) the chapter these
  fields were added to.
- [Relationships](../models/relationships.md) the reference: every argument of
  all four kinds, and how eager loading is expressed in a query spec.
