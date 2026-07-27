---
title: Defining a resource
description: Declare a schema class, let beak prepare generate the columns, the model, the relationships and the migration, and know what each part decides.
---

# Defining a resource

After this page you can declare any resource your app needs: its columns, its
relationships, and the behaviour that follows from them. We build up the store
example's products resource, the one that touches every column kind Beak has.

## One class

A resource is a class annotated `@Resource`, extending `BeakSchema`, with a
`part` directive beside it:

```dart title="examples/store/lib/models/category.dart"
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'category.beak.dart';

/// A shelf of the catalog.
@Resource()
final class Category extends BeakSchema {
  /// What the category is called.
  @Display()
  @Column(searchable: true, sortable: true, rules: [BeakMaxLength(120)])
  late final String name;

  /// The one-line blurb shown above the product list.
  @Column(visibleOn: {BeakContext.form, BeakContext.detail})
  late final BeakText? blurb;
}
```

`beak prepare` reads that and writes `category.beak.dart` next to it:
`CategoryColumns`, `CategoryRelations`, `CategoryModel`, and a typed record
view. It also writes the migration that creates the table. You register
nothing: a file under `lib/models/` is a resource.

!!! note "Why `late final` and no constructor"
    A schema class is a *description*, never an instance. Its fields are never
    read at runtime; only the generator reads them, from the source. `late
    final` with no initialiser is how Dart lets you write a field that is a
    type, a name and some annotations, and nothing else.

## The type picks the column

There is no `kind:` parameter. The field's Dart type decides:

| Field type | Column |
| --- | --- |
| `String` | single-line text |
| `BeakText` | multi-line text |
| `BeakRichText` | rich text editor |
| `int` | integer |
| `double` | decimal |
| `bool` | boolean |
| `DateTime` | instant |
| any `enum` | enum, with its values and a badge per value |
| `BeakJson` | a JSON blob |
| `BeakHexColor` | a colour swatch |
| `BeakImageRef` / `BeakFileRef` | an upload |
| `Object?` with `@Custom` | whatever your renderer draws |

## Nullability picks required-ness

`String name` is required. `BeakText? blurb` is not. That one fact drives the
form validator, the API's validation and the column's `NOT NULL` together, so
there is no way for the three to disagree.

## What `@Column` adds

Everything the type cannot express:

```dart title="examples/store/lib/models/product.dart"
/// Sale price in euros.
@Column(prefix: '€', sortable: true, filterable: true, rules: [BeakMin(0)])
late final double price;

/// Units in stock.
@Column(suffix: ' pcs', min: 0, sortable: true)
late final int stock;
```

`sortable`, `searchable` and `filterable` are what the list page reads: a
sortable column gets a sortable header, a searchable one joins the search, and
a filterable one contributes a filter control matched to its type. `indexed`
and `unique` are what the migration reads. `rules` run in the form and again in
the API. [Annotations](../reference/annotations.md) has the full table.

## Relationships name the other class

```dart title="examples/store/lib/models/product.dart"
/// The category this product is filed under.
@BelongsTo(onDelete: BeakOnDelete.setNull)
late final Category? category;

/// The tags attached to this product.
@BelongsToMany(allowCreate: true)
late final List<Tag> tags;
```

No foreign key, no pivot table, no key columns. Beak derives `category_id` from
the field name, `product_tag` from the two table names, and generates the
matching has-many on `Category`, so both sides exist without either being
written twice. [Relationships](relationships.md) covers the four kinds and what
you can override.

## What the class decides

| On `@Resource` | Effect |
| --- | --- |
| `table:` | the physical table name (default: the pluralised class name) |
| `softDeletes: true` | deletes write `deleted_at`; the panel gains restore and a trashed view |
| `timestamps: true` | `created_at` and `updated_at`, stamped by the API |
| `managesSchema: false` | another system migrates this table; Beak writes no migration |

`@Display()` on a field marks what a record is *called*: in a picker, a link, a
page title, a search result. Exactly one per schema; without it Beak uses the
first string field.

## The primary key

Beak adds an `id` column to every resource and reads a record's identity
through it. You do not declare it, and a schema class cannot rename it. A table
whose key column is named something else is a job for a hand-written model
([Escape hatches](escape-hatches.md)).

## Scaffolding one

```bash
beak make:resource Product --fields name:string!,price:decimal!
```

writes `lib/models/product.dart` with those fields and runs `beak prepare`. A
trailing `!` means required, mirroring Dart's nullability.

## Continue reading

- [Generated code](generated-code.md) what `beak prepare` writes, and how to read it.
- [Column types](column-types.md) every column kind and its options.
- [Relationships](relationships.md) the four kinds, and what Beak derives.
- [Escape hatches](escape-hatches.md) for what a schema class cannot express.
