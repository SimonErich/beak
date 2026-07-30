---
title: Annotations
description: Every annotation a schema class can carry, what it changes, and the Dart type each one applies to.
---

# Annotations

A schema class is plain Dart plus annotations. This page lists all of them,
what each one changes, and where it applies. They come from
`package:beak/schema.dart`.

```dart
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'product.beak.dart';
```

## On the class

### `@Resource`

Declares the class a resource. Everything else is optional.

| Parameter | Default | What it does |
| --- | --- | --- |
| `table` | pluralised, snake-cased class name | The physical table name |
| `softDeletes` | `false` | Deletes write a `deleted_at` marker instead of removing the row |
| `timestamps` | `false` | Adds `created_at` and `updated_at`, stamped by the API |
| `managesSchema` | `true` | Whether Beak generates a migration for this table |

```dart
@Resource(softDeletes: true, timestamps: true)
final class Product extends BeakSchema { /* ... */ }
```

Set `managesSchema: false` when another system already migrates the table. Beak
still reads it, writes it, renders it and relates to it; it just writes no
migration, and `beak doctor` does not ask why one is missing.

## On a field

### `@Column`

Configures the column a field becomes. The field's Dart type picks the *kind*;
this carries what the type cannot express.

| Parameter | What it does |
| --- | --- |
| `columnName` | Storage column name (default: the snake-cased field name) |
| `label` | Human label (default: the title-cased field name) |
| `visibleOn` | Which of `BeakContext.table` / `form` / `detail` it appears on |
| `sortable` | Table views may order by it |
| `searchable` | Search includes it |
| `filterable` | The list page derives a filter control from it |
| `indexed` | The generated migration indexes it |
| `unique` | The generated migration adds a unique index |
| `rules` | Validation rules, enforced in the form *and* the API |
| `prefix` / `suffix` | Unit or currency carried into the rendering |
| `precision` | Decimal places, for a `double`. Displayed *and* stored: it is the SQL scale |
| `totalDigits` | Total stored digits for a `double`, fraction digits included (default `10`). Must be at least `precision`, asserted at construction |
| `min` / `max` | Bounds the form's stepper, for an `int` |
| `maxLength` | Longest accepted text, for a `String` |
| `format` | `BeakDateFormat.relative` renders "3 days ago" |
| `placeholder` | Hint text in the empty input, for a `String` |
| `trueLabel` / `falseLabel` | State labels, for a `bool` |
| `defaultValue` | The value a create form starts on, for an enum |

Every belongs-to foreign key is indexed without being asked, so `indexed` is
for the columns you sort or filter by often.

### `@Display`

Marks the field that represents a record in pickers, links and titles. One per
schema; without it Beak uses the first string field.

### `@Image` and `@FileField`

Declare an upload column, with the rules the API enforces on the way in.

```dart
@Image(
  storagePath: 'products',
  maxSizeInBytes: 5 * 1024 * 1024,
  allowedTypes: [BeakFileType.jpeg, BeakFileType.png],
  thumbnail: BeakDimensions(widthInPixels: 160, heightInPixels: 160),
  transforms: [BeakFormatTransform.webp()],
)
late final BeakImageRef? image;
```

`@FileField` is the same without the image-specific parts. The rules run twice:
in the browser before the upload starts, and again in the API, so a client that
skips the panel does not skip the check.

### `@Badges`

Assigns a colour to each value of an enum field. Generic, so the map's keys are
checked against *this* field's enum.

```dart
@Badges({
  ProductStatus.draft: BeakColor.muted,
  ProductStatus.published: BeakColor.success,
})
late final ProductStatus status;
```

### `@Custom`

Declares an opaque column drawn by a renderer the panel registers under the
given tag. Apply to an `Object?` field.

## Relationships

Each takes the related **schema class** as the field type. Beak derives the
foreign key, the pivot table and both sides of the relationship from that.

| Annotation | Field type | Where the key lives |
| --- | --- | --- |
| `@BelongsTo` | `Other?` or `Other` | this table |
| `@HasOne` | `Other?` | the other table |
| `@HasMany` | `List<Other>` | the other table |
| `@BelongsToMany` | `List<Other>` | a pivot table |

```dart
@BelongsTo(onDelete: BeakOnDelete.setNull)
late final Category? category;

@BelongsToMany(allowCreate: true)
late final List<Tag> tags;
```

Common parameters:

| Parameter | Applies to | What it does |
| --- | --- | --- |
| `label` | all | Overrides the title-cased field name |
| `foreignKey` | all but many-to-many | Overrides the derived key name |
| `searchOn` | belongs-to, many-to-many | The related columns the picker searches (default: its display column) |
| `onDelete` | all but has-one | A `BeakOnDelete` value (`cascade`, `ormCascade`, `restrict`, `setNull`, `setDefault`, `noAction`), written into the migration |
| `inverse` | belongs-to, many-to-many | `false` stops Beak generating the other side |
| `pivotTable`, `foreignPivotKey`, `relatedPivotKey` | many-to-many | Override the derived pivot names |
| `allowCreate` | many-to-many | The relation manager may create related records inline |
| `maxAllowed` | many-to-many | Caps how many may be attached |

Declare the side you think about; Beak generates the other. `inverse: false`
stops that when a lookup table should not gain a back-reference to everything
pointing at it.

## Authoring types

Types that exist only to name a column kind, since Dart has no separate type
for "long text" or "an uploaded image":

| Type | Column |
| --- | --- |
| `String` | single-line text |
| `BeakText` | multi-line text |
| `BeakRichText` | rich text |
| `int`, `double`, `bool`, `DateTime` | number, decimal, boolean, instant |
| `BeakJson` | a JSON blob |
| `BeakHexColor` | a colour swatch |
| `BeakImageRef`, `BeakFileRef` | uploads |
| any `enum` | an enum column, with its values |

## Continue reading

- [beak.yaml](beak-yaml.md) the presentation decisions that live outside the code.
- [Column types](column-types.md) every column kind and the options it takes.
- [Validation rules](validation-rules.md) the rules you attach with `rules:`.
