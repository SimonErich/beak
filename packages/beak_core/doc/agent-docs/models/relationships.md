# Relationships

> Declare belongs-to, has-many, has-one and many-to-many links between schemas, and see what each key, delete rule, inverse and ownership flag does.

Two schemas point at each other, and you want the table to show the name instead of an id, the form to offer a picker, and the database to refuse a dangling row. After this page you can pick the annotation for each kind of link, tell which side owns the key, and know what `onDelete`, `inverse`, `owned` and `searchOn` change.

You write a field whose type is another schema class. Beak works out the foreign key, the pivot table, the index and the other side of the link, so no column name and no join appears in your code.

## At a glance

| Kind | Annotate | Field type | The key lives in | In the examples |
| --- | --- | --- | --- | --- |
| Belongs to | `@BelongsTo` | `Category?` or `Category` | This table, as `category_id` | `Product.category` |
| Has many | `@HasMany` | `List<ProductVariant>` | The other table, as `product_id` | `Product.variants` |
| Has one | `@HasOne` | `KeeperProfile?` | The other table | `Keeper.profile` (showcase) |
| Belongs to many | `@BelongsToMany` | `List<Habitat>` | A pivot table | `Keeper.habitats` (showcase) |

A link has two ends, and the shop declares both ends of every owned one. A product owns its variants, and a variant belongs to its product:

```dart title="examples/clean_beak_config/lib/resources/products/models/product.dart"
/// Sellable variants with separate prices and stock.
@HasMany(owned: true, onDelete: BeakOnDelete.cascade)
late final List<ProductVariant> variants;
```

```dart title="examples/clean_beak_config/lib/resources/products/models/product_variant.dart"
/// Catalog product this variant belongs to.
@BelongsTo(onDelete: BeakOnDelete.cascade)
late final Product product;
```

The related class has to be a `@Resource` under `lib/`. A schema that points at anything else is an error from `beak prepare`, at the field.

## Belongs to: the side with the key

`@BelongsTo` is the one that adds a column. `late final Author author;` on `Book` adds `author_id` to `books`, indexes it, and adds the foreign-key constraint. You never declare that column. The field's nullability is the requirement: `Author author` is required, `Author? author` is optional.

This is the table a `Book` with a required author, a tag link and a cover gets, read from SQLite in a scratch project:

```text
CREATE TABLE IF NOT EXISTS "books" ("id" TEXT PRIMARY KEY, "title" TEXT NOT NULL, "author_id" TEXT, FOREIGN KEY ("author_id") REFERENCES "authors" ("id") ON DELETE CASCADE);
CREATE INDEX "books_author_id_idx" ON "books" ("author_id");
```

The column is nullable even though the field is not. Required means the form and the API refuse a book without an author. The constraint keeps the reference honest, and `NOT NULL` is not part of it:

```json
{"code":"validation","message":"Validation failed for \"books\".","fieldErrors":{"author_id":["This field is required."]},"requestId":"245f73bc78350fa5"}
```

Errors on a to-one link are keyed by the foreign key (`author_id`), because that is the column that failed.

## Has many and has one: the side without

`@HasMany` and `@HasOne` add nothing to their own table. They describe the key that lives in the other table, so that table has to have it, which means the child declares its own `@BelongsTo`. The shop does this for every owned collection.

Two defaults matter here. The foreign key of a has-many is the owner's class name in snake case plus `_id` (`Product` gives `product_id`). It has to equal the column the child's `@BelongsTo` produces, and that column is named after the child's field. When the two names differ you say so on the has-many:

```dart title="examples/clean_beak_config/lib/resources/products/models/product_variant.dart"
/// Values distinguishing this choice from the parent product.
@HasMany(
  foreignKey: 'variant_id',
  owned: true,
  onDelete: BeakOnDelete.cascade,
)
late final List<VariantAttribute> attributes;
```

`VariantAttribute` calls its field `variant`, so its column is `variant_id`, and the owner class would have suggested `product_variant_id`.

`@HasOne` is a has-many that reads the first row. The database does not enforce "only one": the showcase's `KeeperProfile` has a plain `keeper_id`. Add `BeakUnique(KeeperProfileModel.keeperId)` to the child's `validationRules` when the guarantee matters, see [Validation](validation.md).

## Belongs to many: a pivot table

`@BelongsToMany` links two schemas through a table of pairs. Neither side gets a column. The pivot is named after both singular table names, sorted (`book_tag`), with one column per side (`book_id`, `tag_id`):

```text
CREATE TABLE IF NOT EXISTS "book_tag" ("book_id" TEXT NOT NULL, "tag_id" TEXT NOT NULL, CONSTRAINT "book_tag_book_id_tag_id_idx" UNIQUE ("book_id", "tag_id"), FOREIGN KEY ("book_id") REFERENCES "books" ("id") ON DELETE CASCADE, FOREIGN KEY ("tag_id") REFERENCES "tags" ("id") ON DELETE CASCADE);
CREATE INDEX "book_tag_tag_id_idx" ON "book_tag" ("tag_id");
```

The pair is unique, both lookups have an index, and both keys cascade. `beak prepare` writes a `create_book_tag_table.dart` migration for it once, like any other table. The showcase links keepers and habitats this way, and declares both ends so each side can say how it looks. The keeper side also shows a has-one, its `KeeperProfile`:

```dart title="examples/showcase/lib/resources/keepers/models/keeper.dart"
/// The keeper's certification details (has-one relationship).
@HasOne(owned: true)
late final KeeperProfile? profile;

/// The habitats the keeper looks after (many-to-many, through a pivot table).
@BelongsToMany(pivotTable: 'habitat_keeper', searchOn: [#name])
late final List<Habitat> habitats;
```

```dart title="examples/showcase/lib/resources/habitats/models/habitat.dart"
/// The keepers who look after it (many-to-many, through a pivot table).
@BelongsToMany(pivotTable: 'habitat_keeper', inverse: false)
late final List<Keeper> keepers;
```

`searchOn` names the fields of the related schema that the picker searches, as symbols (`[#name]`), and `beak prepare` checks them against that schema. The pivot has no columns of its own. A link that carries data (a quantity per line, a note per customer and profile) is not a pivot: give it a schema with two `@BelongsTo`, like the shop's `UserProfileConnection`.

## The other side, for free

Declare the side you think about and Beak generates the other. The rules:

- A `@BelongsTo` on `Book` gives `Author` a has-many named after the plural table of the class that declared it (`Author.books`).
- A `@HasMany` or `@HasOne` on `Author` gives `Book` a belongs-to named after the singular table of the declaring class (`Book.author`), as a relationship constant only. It carries no column, so it does not replace the child's own `@BelongsTo`.
- A `@BelongsToMany` is mirrored on the other class.
- Nothing is generated when the far class already declares any relationship to the owner, or when the annotation says `inverse: false`.

The generated side is a constant like any other. This is what `beak prepare` wrote for `Tag`, after `Book` declared `tags` and `Tag` declared nothing:

```dart
/// The books on the other side of [BookRelations.tags].
static const BeakBelongsToMany books = BeakBelongsToMany(
  key: 'books',
  label: 'Books',
  relatedTable: 'books',
  displayColumnKey: 'title',
  pivotTable: 'book_tag',
  foreignPivotKey: 'tag_id',
  relatedPivotKey: 'book_id',
  searchColumnKeys: ['title'],
);
```

Turn the inverse off for a lookup table that should not know everything pointing at it. The shop does so on its lookups: a product's `taxRate` is `@BelongsTo(inverse: false, ...)`, and `TaxRate` never lists its products.

## What happens on delete

`onDelete` is the foreign-key rule, and it belongs to the belongs-to side because that is where the constraint lives.

| Value | The database does |
| --- | --- |
| `BeakOnDelete.cascade` | Deletes the child rows with the parent |
| `BeakOnDelete.restrict` | Refuses to delete a parent that still has children |
| `BeakOnDelete.setNull` | Keeps the children and clears their key |
| `ormCascade`, `setDefault`, `noAction` | Passed to the migration builder as worm defines them |

Left out, it is `restrict` for a non-nullable field and `setNull` for a nullable one. The shop states it on both ends of a link (`cascade` on the has-many and on the belongs-to) so either class reads the same. Only the belongs-to is executed. `onDelete` on `@HasMany` and `@BelongsToMany` is stored on the relationship constant and read by nothing, and a pivot always cascades.

A `restrict` refusal is enforced by the database, and Beak reports it as a conflict. Nothing is deleted. A direct `DELETE` answers `409` with `This "shelves" record is still referenced by other records.`, and a delete inside a graph commit comes back as an `unapplied` outcome with the reason `rejected` and the same `conflict` error, so the form stays editable. SQLite, PostgreSQL and MySQL all map to this. Use `restrict` where a hard stop is worth a refusal message, `cascade` for owned children and `setNull` for optional links.

## Owned or shared

`owned: true` says the children belong to this parent alone: a variant means nothing without its product, and an order line means nothing without its order. It is a promise about how the record is edited, and it changes four things:

- The form may delete an owned child when its row is removed (`removeBehavior: BeakRemoveBehavior.deleteOwned`). For a shared relationship removing a row only detaches it, and asking for `deleteOwned` there throws a `BeakConfigurationException` naming the relationship as soon as the form is built.
- `galleryForm` needs an owned has-many, see [Files and storage columns](files-and-storage-columns.md).
- Duplicating a record copies its owned collections and keeps shared links as they are.
- When the owner declares `editableWhen`, its owned children are written only through a save of the owner, so the guard cannot be bypassed by editing a child by itself. The shop's `invoice_vouchers` answers a direct `POST` with `422 This resource must be saved through a graph commit.`, and `product_images` accepts it.

`owned` does not delete anything by itself. What the database does when the parent goes is the belongs-to's `onDelete`, which is why owned collections in the shop come with `cascade` on both ends. A shared collection (an order's customer, a product's tax rate) has no `owned` and no cascade.

## Which records may be linked

By default a picker offers every record of the related table, searched by its display column. Two things narrow that.

`searchOn` widens what the picker searches. A person looks a customer up by email as readily as by name:

```dart title="examples/clean_beak_config/lib/resources/orders/models/order.dart"
/// The customer placing the order.
@BelongsTo(
  searchOn: [#email, #firstName, #lastName],
  inverse: false,
  onDelete: BeakOnDelete.restrict,
)
late final User customer;
```

Eligibility narrows which records qualify. A record rule says the profile of an order has to belong to the order's customer:

```dart
/// Shared delivery eligibility and complete-order validation.
static List<BeakRecordRule> get validationRules => [
  BeakCount(OrderModel.items, min: 1),
  BeakExists(
    OrderModel.profileId,
    UserProfileConnectionModel.id,
    matching: [
      BeakFieldMatch(
        target: UserProfileConnectionModel.userId,
        source: OrderModel.customerId,
      ),
    ],
  ),
];
```

The picker reads `BeakExists` rules on its foreign key. It filters its options by each `matching:` pair, stays closed until the field the pair reads is filled in, and copies the matching values into a record created inline. The server evaluates the same rule on the graph it is about to save, so a script cannot link a profile of another customer. The mechanics are on [Validation](validation.md), the picker side on [Related records in forms](../forms/related-records.md).

## Reading related records

Beak never lazy-loads. A relationship you did not load reads as `null` (to-one) or an empty list (to-many) and never fetches. Tables and forms load what their fields name, so `OrderModel.customer.email` in a table brings the customer along. In your own queries you ask with `relationLoads`, see [Generated code](generated-code.md#productdraft-and-productrecord-typed-reads).

## Rules and limits

- Declare the child's `@BelongsTo` for every has-many and has-one. The parent side alone generates a relationship constant without a column. `beak prepare` and `dart analyze` accept it, and `beak migrate` fails with `unknown column "team_id" in foreign key definition`.
- A has-many key defaults to the owner class name, not to the column the child's field produces. Set `foreignKey:` when they differ.
- A has-one is not unique unless you make it so.
- Only `@BelongsTo(onDelete:)` is executed. The other two are stored and unread, and a pivot always cascades.
- `restrict` and `cascade` are database rules. The engine applies them, so they hold for a script and for the panel alike.
- A pivot has no columns of its own. Data on a link means a schema with two belongs-to.
- `deleteOwned` needs an owned has-many. It is checked when the form is built, so a misconfigured table fails on first open and not when someone removes a row.
- `searchOn` takes symbols. Strings are an error that prints the symbols to write instead.
- Relations come from the schema, not from the query. An unloaded relation is empty, so an "empty" collection can also mean "not asked for".

## Verify it

```bash
beak prepare
beak doctor
```

`beak prepare` stops on a link it cannot resolve, listing every problem at the declaration:

```text
  lib/models/product.dart: Product.category searches #nme, which is not a field of Category. Its fields are: id, name.
```

`beak doctor` compares the schema to the database and reports a missing table or column. To see what a link really did, read the table: `sqlite3 beak.db ".schema books"` shows the key, the index and the delete rule, and `dart analyze` confirms the generated constants compile.

## Reference

| Symbol | Kind | Purpose |
| --- | --- | --- |
| `@BelongsTo` | annotation | `label`, `foreignKey`, `searchOn`, `onDelete`, `inverse` |
| `@HasMany` | annotation | `label`, `foreignKey`, `onDelete`, `owned` |
| `@HasOne` | annotation | `label`, `foreignKey`, `owned` |
| `@BelongsToMany` | annotation | `label`, `pivotTable`, `foreignPivotKey`, `relatedPivotKey`, `searchOn`, `allowCreate`, `maxAllowed`, `onDelete`, `inverse` |
| `BeakBelongsTo`, `BeakHasMany`, `BeakHasOne`, `BeakBelongsToMany` | `beak_core` | The generated constants in `XRelations` |
| `BeakOnDelete` | enum | `cascade`, `ormCascade`, `restrict`, `setNull`, `setDefault`, `noAction` |
| `BeakToOneField`, `BeakToManyField` | `beak_core` | The typed references in `XFields` |
| `tableForm`, `inputCombobox`, `galleryForm` | `beak_frontend` | Editing a link in a configured form |

Every parameter with its default is on [Annotations](../reference/annotations.md#relationships), and the generated constants on [Generated files and symbols](../reference/generated-files.md).

## Continue reading

- [Related records in forms](../forms/related-records.md) pickers, inline creation and owned rows in one save.
- [Validation](validation.md) eligibility, uniqueness and collection rules across a link.
- [Model behavior](behavior.md) guards on an owner and the children they protect.
