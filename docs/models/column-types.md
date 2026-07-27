---
title: Column types
description: All thirteen Beak column kinds, the field type that picks each one, and what @Column adds on top.
---

# Column types

Beak has thirteen column kinds. You never name one: you declare a field, and its
Dart type picks the kind, which brings the right form input, table cell, detail
entry and validation with it. This page walks all thirteen with a real field for
each. For the parameter-by-parameter reference of the constants they generate,
see the [column types reference](../reference/column-types.md).

Every kind also carries the shared `@Column` options (`visibleOn`, `sortable`,
`searchable`, `filterable`, `indexed`, `unique`, `rules`) from
[Column basics](column-basics.md). The snippets below highlight what each kind
*adds*.

## The thirteen at a glance

| Field type | Column it becomes | Renders as (table) | Its own `@Column` options |
| --- | --- | --- | --- |
| `String` | `BeakStringColumn` | plain text | `maxLength`, `placeholder` |
| `BeakText` | `BeakTextColumn` | truncated text | none |
| `int` | `BeakIntColumn` | number | `min`, `max`, `prefix`, `suffix` |
| `double` | `BeakDecimalColumn` | number, or currency with a prefix | `precision`, `prefix`, `suffix` |
| `bool` | `BeakBoolColumn` | yes/no indicator | `trueLabel`, `falseLabel` |
| `DateTime` | `BeakDateTimeColumn` | absolute or relative date | `format` |
| any `enum` | `BeakEnumColumn<T>` | coloured badge | `defaultValue`, plus `@Badges` |
| `BeakJson` | `BeakJsonColumn` | pretty-printed JSON | none |
| `BeakRichText` | `BeakRichTextColumn` | rendered markup | none |
| `BeakHexColor` | `BeakColorColumn` | colour swatch | none |
| `BeakImageRef` | `BeakImageColumn` | thumbnail | via `@Image` |
| `BeakFileRef` | `BeakFileColumn` | download cell | via `@FileField` |
| `Object?` with `@Custom` | `BeakCustomColumn` | your registered renderer | none |

`BeakText`, `BeakRichText`, `BeakHexColor`, `BeakImageRef` and `BeakFileRef` are
extension types over `String`. They exist so a field's type can say "multi-line"
or "an uploaded image", which `String` alone cannot, and they compile away to the
`String` they wrap.

## Text and numbers

### BeakStringColumn

The workhorse: a single-line string, plain text everywhere. `maxLength` caps what
the form input accepts while typing; pair it with a `BeakMaxLength` rule to
reject an over-long value on submit as well.

```dart title="examples/store/lib/models/product.dart"
/// What the product is called.
@Display()
@Column(
  searchable: true,
  sortable: true,
  indexed: true,
  rules: [BeakMaxLength(255)],
)
late final String name;
```

### BeakTextColumn

Multi-line plain text: a textarea in forms, truncated in table cells, the full
text in detail views. Declare it with `BeakText`.

```dart title="examples/store/lib/models/product.dart"
/// The short description shown in listings.
@Column(visibleOn: {BeakContext.form, BeakContext.detail})
late final BeakText? summary;
```

### BeakIntColumn

A whole number, rendered locale-aware. `min` and `max` bound the form's stepper,
and `prefix`/`suffix` carry the unit into every surface that renders the value.

```dart title="examples/store/lib/models/product.dart"
/// Units in stock.
@Column(suffix: ' pcs', min: 0, sortable: true)
late final int stock;
```

Bounds on the stepper are a convenience, not a check. Add `BeakMin`/`BeakMax` to
`rules` when the value must be rejected rather than nudged.

### BeakDecimalColumn

A fractional number with fixed `precision` (default `2`). Add a `prefix` or a
`suffix` and the render intent flips from a plain number to a currency-style
amount: `€19.99`, or `1.50 kg`.

```dart title="examples/store/lib/models/product.dart"
/// Sale price in euros.
@Column(prefix: '€', sortable: true, filterable: true, rules: [BeakMin(0)])
late final double price;
```

## Choices and states

### BeakBoolColumn

A boolean: a toggle in forms, a yes/no indicator elsewhere.

```dart title="examples/store/lib/models/product.dart"
/// Whether the product is featured on the storefront.
@Column(filterable: true)
late final bool featured;
```

`trueLabel` and `falseLabel` override the default state text. From the
superdashboard showcase, where an email is "Read" or "Unread" rather than yes or
no:

```dart title="examples/superdashboard/lib/models/email/email.dart"
/// Whether the email has been read.
@Column(
  label: 'Read',
  filterable: true,
  trueLabel: 'Read',
  falseLabel: 'Unread',
)
late final bool? isRead;
```

### BeakEnumColumn&lt;T&gt;

Declare a Dart enum and use it as the field's type. Beak renders it as a badge in
tables and a select in forms, and carries the enum's values through the API and
into the database default. `@Badges` colours each value, and its map is checked
against *this* field's enum, so a stray value is a compile error.

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

The generated constant is generic over the enum, which is what keeps the whole
thing free of stringly-typed states:

```dart title="examples/store/lib/models/product.beak.dart"
/// Lifecycle state, rendered as a coloured badge.
static const BeakEnumColumn<ProductStatus> status =
    BeakEnumColumn<ProductStatus>(
      key: 'status',
      label: 'Status',
      rules: [BeakRequired()],
      filterable: true,
      badgeColors: {
        ProductStatus.draft: BeakColor.muted,
        ProductStatus.published: BeakColor.success,
        ProductStatus.archived: BeakColor.warning,
      },
      values: ProductStatus.values,
    );
```

`defaultValue` pre-selects a value in create forms, and the migration takes it as
the column's schema default, so the two cannot disagree:

```dart title="examples/superdashboard/lib/models/files/managed_file.dart"
/// File kind.
@Column(filterable: true, defaultValue: AttachmentKind.document)
@Badges({
  AttachmentKind.image: BeakColor.success,
  // ...
})
late final AttachmentKind? kind;
```

!!! tip "Labels come from the enum"
    A value displays as its `name`. When you need prettier text than the enum
    gives, the generated column's `labelOf` callback does it, which means a
    hand-written model ([Escape hatches](escape-hatches.md)). The column also
    exposes `valueByName`, the one place a wire string decodes back into a typed
    value without an `as` cast.

## Time

### BeakDateTimeColumn

A `DateTime` field. `format` controls how tables and detail views render it
(`standard`, `relative`, `dateOnly`, `timeOnly`, or `iso`); forms and filters
always use an absolute date picker.

```dart title="examples/store/lib/models/product.dart"
/// When the product went on sale.
@Column(sortable: true, format: BeakDateFormat.relative)
late final DateTime? publishedAt;
```

On the generated constant, `withFormat` returns a copy with a different `format`
and every other property unchanged, for when you want the same column shown two
ways.

## Rich values

### BeakRichTextColumn

A WYSIWYG editor in forms, rendered markup in tables and detail views. Values are
stored as the raw markup source. Declare it with `BeakRichText`.

```dart title="examples/store/lib/models/product.dart"
/// The long description, edited as rich text.
@Column(visibleOn: {BeakContext.form, BeakContext.detail})
late final BeakRichText? description;
```

### BeakColorColumn

A `#rrggbb` string, rendered as a swatch with a colour picker in forms. Declare
it with `BeakHexColor`.

```dart title="examples/store/lib/models/product.dart"
/// The swatch shown beside the name.
@Column(visibleOn: {BeakContext.form, BeakContext.detail})
late final BeakHexColor? swatch;
```

### BeakJsonColumn

A structured-JSON column, declared with `BeakJson`. Beak carries the document as
JSON *text* and never surfaces a raw `Map<String, dynamic>`: it renders
pretty-printed and edits as multi-line text.

```dart title="examples/store/lib/models/product.dart"
/// Storefront metadata the catalog importer round-trips untouched.
@Column(visibleOn: {BeakContext.form, BeakContext.detail})
late final BeakJson? metadata;
```

Parse that text into a typed, pattern-matchable tree with `BeakJson.decode` when
you need structured access:

```dart
const column = BeakJsonColumn(key: 'meta', label: 'Metadata');
final BeakValue? value = record[column.key];
final tree = switch (value?.raw) {
  final String json => BeakJson.decode(json),
  _ => const BeakJsonNull(),
};
```

## Files

Upload columns are declared by their own annotation rather than by `@Column`
alone, because they carry rules a plain column has no use for: where the bytes
land, how large they may be, which types are accepted. They get a page of their
own; here is the shape.

### BeakImageColumn

A thumbnail in table cells, an image picker in forms, the full image in detail
views. `@Image` on a `BeakImageRef` field bounds the upload and attaches a
transform pipeline that runs when it lands.

```dart title="examples/store/lib/models/product.dart"
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
```

### BeakFileColumn

A generic attachment: a PDF, a CSV, an archive. Same upload rules, rendered
through a download/preview cell instead of an image. `@FileField` on a
`BeakFileRef` field.

```dart title="examples/store/lib/models/product.dart"
/// The spec sheet customers download.
@FileField(
  storagePath: 'products/specs',
  maxSizeInBytes: 10 * 1024 * 1024,
  allowedTypes: [BeakFileType.pdf],
)
late final BeakFileRef? specSheet;
```

See [Files and storage columns](files-and-storage-columns.md) for upload
validation, dimensions, transforms, and where `storagePath` actually points.

## The escape hatch

### BeakCustomColumn

When no built-in kind fits (a sparkline, a stock bar, a bespoke status pill),
annotate an `Object?` field with `@Custom` and a tag. Rendering defers to a
builder the panel registers under that same tag, and auto-forms skip the column.

```dart title="examples/store/lib/models/product.dart"
/// The stock indicator, drawn by the panel's registered renderer.
@Custom('stock_bar')
@Column(visibleOn: {BeakContext.table})
late final Object? stockLevel;
```

The tag becomes a `BeakColumnTag` on the generated constant, and the same value
must exist on both sides so the renderer can be found. See
[Custom columns](../extending/custom-columns.md) for registering the builder.

## Continue reading

- [Column basics](column-basics.md) the options every one of these shares.
- [Validation rules](validation-rules.md) the `rules` you attach to any field.
- [Files and storage columns](files-and-storage-columns.md) the image and file
  columns in depth.
- [Column types reference](../reference/column-types.md) every parameter of
  every generated column, in tables.
