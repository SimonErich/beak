---
title: Column types
description: A tour of all thirteen built-in Beak column types, each with a real snippet, its value type, and how it renders.
---

# Column types

Beak ships thirteen column types. Each one is a `const` leaf of the sealed
`BeakColumn` family: pick the leaf that matches the field's Dart type and it
brings the right form input, table cell, detail entry, and validation for free.
This page tours all thirteen with a real snippet for each. For the parameter-by-
parameter reference, see the [column types reference](../reference/column-types.md).

Every type also carries the shared config (`key`, `label`, `visibleOn`, and
friends) from [Column basics](column-basics.md); the snippets below highlight
what each type *adds*.

## The thirteen at a glance

| Column | Dart value | Renders as (table) |
| --- | --- | --- |
| `BeakStringColumn` | `String` | plain text |
| `BeakTextColumn` | `String` | truncated text |
| `BeakIntColumn` | `int` | number |
| `BeakDecimalColumn` | `double` | number, or currency with a prefix/suffix |
| `BeakBoolColumn` | `bool` | yes/no indicator |
| `BeakDateTimeColumn` | `DateTime` | absolute or relative date |
| `BeakEnumColumn<T>` | `T extends Enum` | colored badge |
| `BeakJsonColumn` | `String` | pretty-printed JSON |
| `BeakRichTextColumn` | `String` | rendered markup |
| `BeakColorColumn` | `String` | color swatch |
| `BeakImageColumn` | `String` | thumbnail |
| `BeakFileColumn` | `String` | custom download cell |
| `BeakCustomColumn` | `Object` | your registered renderer |

## Text and numbers

### BeakStringColumn

The workhorse: a single-line string, plain text everywhere. `maxLength` caps the
form input and `placeholder` hints an empty one.

```dart title="apps/reference_admin_models/lib/src/product.dart"
static const name = BeakStringColumn(
  key: 'name',
  label: 'Name',
  searchable: true,
  sortable: true,
  rules: [BeakRequired(), BeakMaxLength(255)],
);
```

### BeakTextColumn

Multiline text: a textarea in forms, truncated in table cells, and the full text
in detail views.

```dart title="apps/reference_admin_models/lib/src/product.dart"
static const description = BeakTextColumn(
  key: 'description',
  label: 'Description',
  searchable: true,
  visibleOn: {BeakContext.form, BeakContext.detail},
);
```

### BeakIntColumn

A whole number, rendered locale-aware. `min` and `max` bound the form's stepper;
pair them with `BeakMin`/`BeakMax` rules to reject out-of-range values on submit
too.

```dart title="apps/reference_admin_models/lib/src/product.dart"
static const stock = BeakIntColumn(
  key: 'stock',
  label: 'Stock',
  min: 0,
  sortable: true,
  rules: [BeakMin(0)],
);
```

### BeakDecimalColumn

A fractional number with fixed `precision` (default `2`). Add a `prefix` or
`suffix` and the render intent flips from a plain number to a currency-style
amount: `€19.99`, or `1.50 kg`.

```dart title="apps/reference_admin_models/lib/src/product.dart"
static const price = BeakDecimalColumn(
  key: 'price',
  label: 'Price',
  prefix: '€',
  sortable: true,
  filterable: true,
  rules: [BeakRequired(), BeakMin(0)],
);
```

## Choices and states

### BeakBoolColumn

A boolean: a toggle in forms, a yes/no indicator elsewhere. `trueLabel` and
`falseLabel` override the default state text. This example is from the showcase
app's email model:

```dart title="apps/beak_superdashboard/lib/models/email/email.dart"
static const isRead = BeakBoolColumn(
  key: 'is_read',
  label: 'Read',
  filterable: true,
  trueLabel: 'Read',
  falseLabel: 'Unread',
);
```

### BeakEnumColumn&lt;T&gt;

A column over a Dart enum, rendered as a colored badge in tables and a select in
forms. The generic keeps the whole thing type-safe: `values`, `defaultValue`,
and `badgeColors` all speak in `T`, so there are no stringly-typed states.

```dart title="apps/reference_admin_models/lib/src/product.dart"
enum ProductStatus { draft, published, archived }

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

!!! tip "Prettier labels than the enum name"
    Pass a `labelOf` callback to display something other than the enum's
    `name`. Without it, `BeakEnumColumn` falls back to `value.name`. It also
    exposes `valueByName`, the one place a wire string decodes back into a typed
    value without an `as` cast.

## Time

### BeakDateTimeColumn

A date/time value. `format` controls how tables and detail views render it
(`standard`, `relative`, `dateOnly`, `timeOnly`, or `iso`); forms and filters
always use an absolute date picker.

```dart title="apps/reference_admin_models/lib/src/product.dart"
static const updatedAt = BeakDateTimeColumn(
  key: 'updated_at',
  label: 'Updated',
  format: BeakDateFormat.relative,
  sortable: true,
  visibleOn: {BeakContext.table, BeakContext.detail},
);
```

`withFormat` returns a copy with a different `format`, keeping every other
property, when you want the same column shown two ways.

## Rich values

### BeakRichTextColumn

A WYSIWYG editor in forms, rendered markup in tables and detail views. Values are
stored as the raw markup source string. From the showcase email model:

```dart title="apps/beak_superdashboard/lib/models/email/email.dart"
static const body = BeakRichTextColumn(
  key: 'body',
  label: 'Body',
  visibleOn: {BeakContext.form, BeakContext.detail},
);
```

### BeakColorColumn

Holds a hex string such as `#663399`, rendered as a swatch with a color picker in
forms. From the showcase calendar model:

```dart title="apps/beak_superdashboard/lib/models/calendar/calendar_event.dart"
static const color = BeakColorColumn(
  key: 'color',
  label: 'Color',
  visibleOn: {BeakContext.form, BeakContext.detail},
);
```

### BeakJsonColumn

A structured-JSON column. Beak carries the document as a JSON *text* value and
never surfaces a raw `Map<String, dynamic>`: it renders pretty-printed and edits
as multiline text. Parse it into a typed, pattern-matchable tree with
`BeakJson.decode` when you need structured access.

```dart title="packages/beak_core/lib/src/columns/beak_json_column.dart"
const column = BeakJsonColumn(key: 'meta', label: 'Metadata');
final BeakValue? value = record[column.key];
final tree = switch (value?.raw) {
  final String json => BeakJson.decode(json),
  _ => const BeakJsonNull(),
};
```

## Files

Image and file columns carry upload rules (size, type, dimensions) that run on
both client and server. They get a page of their own; here is the shape.

### BeakImageColumn

A thumbnail in table cells, an image picker in forms, the full image in detail
views. Bound the upload and attach a transform pipeline that runs on upload.

```dart title="apps/reference_admin_models/lib/src/product.dart"
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

### BeakFileColumn

A generic file attachment. Same upload rules, but rendered through the custom
download/preview cell instead of an image. From the showcase file manager:

```dart title="apps/beak_superdashboard/lib/models/files/managed_file.dart"
static const file = BeakFileColumn(
  key: 'file',
  label: 'File',
  storagePath: 'files/store',
);
```

See [Files and storage columns](files-and-storage-columns.md) for upload
validation, dimensions, transforms, and the storage drivers behind `storagePath`.

## The escape hatch

### BeakCustomColumn

When no built-in type fits (a sparkline, a bespoke status pill), a custom column
defers rendering to a builder you register in `beak_frontend` under a `tag`. The
same `tag` value must exist on both sides so the renderer can be located, and
auto-forms skip these columns.

```dart title="packages/beak_core/lib/src/columns/beak_custom_column.dart"
static const badge = BeakCustomColumn(
  key: 'badge',
  label: 'Badge',
  tag: BeakColumnTag('badge'),
);
```

See [Custom columns](../extending/custom-columns.md) for registering the builder.

## Continue reading

- [Column basics](column-basics.md) the config every one of these shares.
- [Validation rules](validation-rules.md) the `rules` you attach to any column.
- [Files and storage columns](files-and-storage-columns.md) the image and file
  columns in depth.
- [Column types reference](../reference/column-types.md) every parameter of
  every type, in tables.
