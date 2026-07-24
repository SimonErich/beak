---
title: Column types reference
description: Every BeakColumn subclass, its constructor parameters, defaults, value type, and render intents, in tables.
---

# Column types reference

This page lists every column Beak ships: the shared fields that live on the base
`BeakColumn`, the extra fields each of the thirteen leaf types adds, and the
value type and render intents each one resolves to. Scan the overview table,
then drop into the section for the column you are configuring.

A column is declared once, as a `static const`, and feeds six mouths: the table
cell, the form field, the detail row, the filter control, the REST validator,
and the CSV column. Pick the leaf that matches the field's Dart type. You never
construct `BeakColumn` directly; the base class is `sealed`.

## Overview

| Column | Value type | Render intent (table / form) | Type-specific options |
|---|---|---|---|
| [`BeakStringColumn`](#beakstringcolumn) | `String` | `text` / `text` | `placeholder`, `maxLength` |
| [`BeakTextColumn`](#beaktextcolumn) | `String` | `text` / `text` | none |
| [`BeakIntColumn`](#beakintcolumn) | `int` | `number` / `number` | `min`, `max` |
| [`BeakDecimalColumn`](#beakdecimalcolumn) | `double` | `number` or `currency` | `precision`, `prefix`, `suffix` |
| [`BeakBoolColumn`](#beakboolcolumn) | `bool` | `boolean` / `boolean` | `trueLabel`, `falseLabel` |
| [`BeakDateTimeColumn`](#beakdatetimecolumn) | `DateTime` | `date` or `relativeDate` / `date` | `format` |
| [`BeakEnumColumn<T>`](#beakenumcolumnt) | `T` (an `Enum`) | `badge` / `badge` | `values`, `defaultValue`, `badgeColors`, `labelOf` |
| [`BeakJsonColumn`](#beakjsoncolumn) | `String` | `json` / `json` | none |
| [`BeakRichTextColumn`](#beakrichtextcolumn) | `String` | `richText` / `richText` | none |
| [`BeakColorColumn`](#beakcolorcolumn) | `String` | `color` / `color` | none |
| [`BeakImageColumn`](#beakimagecolumn) | `String` | `thumbnail` / `image` | `storagePath`, `maxSizeInBytes`, `allowedTypes`, `maxDimensions`, `aspectRatio`, `thumbnail`, `transforms` |
| [`BeakFileColumn`](#beakfilecolumn) | `String` | `custom` / `custom` | `storagePath`, `maxSizeInBytes`, `allowedTypes` |
| [`BeakCustomColumn`](#beakcustomcolumn) | `Object` | `custom` / `custom` | `tag` |

The **render intent** is the ORM- and UI-neutral hint the column resolves to for
a surface; `beak_frontend` maps each intent to an obers_ui widget. See
[Rendering per surface](../concepts/rendering-per-surface.md) for the full list
of intents and how the mapping works.

## Shared fields (every column)

Every column carries these seven fields from the base `BeakColumn`. The
per-type sections below only document what each leaf *adds*.

| Field | Type | Default | Meaning |
|---|---|---|---|
| `key` | `String` | required | Storage/DB column name (snake_case). Beak wires it internally; you reference the column constant, never this string. |
| `label` | `String` | required | Human-readable label shown in tables, forms, and detail views. |
| `visibleOn` | `Set<BeakContext>` | `{table, form, detail}` | Surfaces this column appears on (filter is off by default). Narrow it to hide a field, e.g. `{BeakContext.detail}` for a read-only primary key. |
| `sortable` | `bool` | `false` | Whether table views may sort by this column. |
| `searchable` | `bool` | `false` | Whether search includes this column. |
| `filterable` | `bool` | `false` | Whether table views may filter by this column. |
| `rules` | `List<BeakRule>` | `const []` | Declarative validation rules enforced on input, in order. See the [Validation rules reference](validation-rules.md). |

The base constructor, quoted verbatim:

```dart title="packages/beak_core/lib/src/columns/beak_column.dart"
const BeakColumn({
  required this.key,
  required this.label,
  this.visibleOn = const {
    BeakContext.table,
    BeakContext.form,
    BeakContext.detail,
  },
  this.sortable = false,
  this.searchable = false,
  this.filterable = false,
  this.rules = const [],
});
```

Every column also exposes two read-only members the renderer and the backend
mapper switch over:

| Member | Type | Meaning |
|---|---|---|
| `renderConfig` | `BeakRenderConfig` | The per-context render intents (table, form, detail, filter). |
| `intentFor(BeakContext context)` | `BeakRenderIntent` | Shortcut for `renderConfig.intentFor(context)`. |
| `valueType` | `Type` | The Dart type this column's values take. |

### Upload columns share three more fields

`BeakImageColumn` and `BeakFileColumn` both extend the `sealed`
`BeakUploadColumn`, which adds where the file lands and how big and what type it
may be:

| Field | Type | Default | Meaning |
|---|---|---|---|
| `storagePath` | `String` | required | Storage subfolder uploads of this column land in. |
| `maxSizeInBytes` | `int?` | `null` | Highest accepted upload size in bytes, if bounded. |
| `allowedTypes` | `List<BeakFileType>` | `const []` | Accepted upload types; empty means unrestricted. |

Upload columns always have `valueType == String` (the stored file key/URL). File
rules are covered in depth in [Files and storage
columns](../models/files-and-storage-columns.md).

## Text columns

### `BeakStringColumn`

A single-line string, rendered as plain text everywhere. The workhorse for
names, references, and foreign keys.

```dart title="packages/beak_core/lib/src/columns/beak_string_column.dart"
const BeakStringColumn({
  required super.key,
  required super.label,
  super.visibleOn,
  super.sortable,
  super.searchable,
  super.filterable,
  super.rules,
  this.placeholder = '',
  this.maxLength,
});
```

| Field | Type | Default | Meaning |
|---|---|---|---|
| `placeholder` | `String` | `''` | Hint text shown in an empty form input. |
| `maxLength` | `int?` | `null` | Length cap the form input enforces while typing, if any. |

Value type `String`. Renders as `text` on every surface.

```dart title="apps/reference_admin_models/lib/src/product.dart"
static const name = BeakStringColumn(
  key: 'name',
  label: 'Name',
  searchable: true,
  sortable: true,
  rules: [BeakRequired(), BeakMaxLength(255)],
);
```

### `BeakTextColumn`

A multiline text column: a textarea in forms, truncated text in table cells, and
the full text in detail views. It adds no fields of its own.

```dart title="packages/beak_core/lib/src/columns/beak_text_column.dart"
const BeakTextColumn({
  required super.key,
  required super.label,
  super.visibleOn,
  super.sortable,
  super.searchable,
  super.filterable,
  super.rules,
});
```

Value type `String`. Renders as `text` on every surface.

### `BeakRichTextColumn`

A rich-text column: a WYSIWYG editor in forms, rendered markup in tables and
detail views. Values are stored as the raw markup source string, not as parsed
nodes. No extra fields.

```dart title="packages/beak_core/lib/src/columns/beak_rich_text_column.dart"
const BeakRichTextColumn({
  required super.key,
  required super.label,
  super.visibleOn,
  super.sortable,
  super.searchable,
  super.filterable,
  super.rules,
});
```

Value type `String`. Renders as `richText` on every surface.

### `BeakJsonColumn`

A structured-JSON column. It carries its document as a JSON *text* value,
rendered pretty-printed and edited as multiline text; Beak never surfaces a raw
`Map<String, dynamic>`. Parse the text into a typed, pattern-matchable tree with
`BeakJson.decode` when you need structured access. No extra fields.

```dart title="packages/beak_core/lib/src/columns/beak_json_column.dart"
const BeakJsonColumn({
  required super.key,
  required super.label,
  super.visibleOn,
  super.sortable,
  super.searchable,
  super.filterable,
  super.rules,
});
```

Value type `String`. Renders as `json` on every surface.

## Number and boolean columns

### `BeakIntColumn`

An integer column, rendered as a locale-aware number. `min`/`max` bound the
form's stepper; pair them with `BeakMin`/`BeakMax` rules to reject out-of-range
values on submit as well.

```dart title="packages/beak_core/lib/src/columns/beak_int_column.dart"
const BeakIntColumn({
  required super.key,
  required super.label,
  super.visibleOn,
  super.sortable,
  super.searchable,
  super.filterable,
  super.rules,
  this.min,
  this.max,
});
```

| Field | Type | Default | Meaning |
|---|---|---|---|
| `min` | `int?` | `null` | Lowest value the form input offers, if bounded. |
| `max` | `int?` | `null` | Highest value the form input offers, if bounded. |

Value type `int`. Renders as `number` on every surface.

### `BeakDecimalColumn`

A fractional-number column with fixed `precision`. A `prefix` or `suffix` (a
currency symbol or a unit) switches its render intent from `number` to
`currency`.

```dart title="packages/beak_core/lib/src/columns/beak_decimal_column.dart"
const BeakDecimalColumn({
  required super.key,
  required super.label,
  super.visibleOn,
  super.sortable,
  super.searchable,
  super.filterable,
  super.rules,
  this.precision = 2,
  this.prefix,
  this.suffix,
});
```

| Field | Type | Default | Meaning |
|---|---|---|---|
| `precision` | `int` | `2` | Number of fraction digits displayed. |
| `prefix` | `String?` | `null` | Text rendered before the number (e.g. `€`), if any. |
| `suffix` | `String?` | `null` | Text rendered after the number (e.g. `kg`), if any. |

Value type `double`. Renders as `currency` when `prefix` or `suffix` is set,
otherwise `number`, on every surface.

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

### `BeakBoolColumn`

A boolean column: a toggle in forms, a yes/no indicator elsewhere.
`trueLabel`/`falseLabel` override the default state text.

```dart title="packages/beak_core/lib/src/columns/beak_bool_column.dart"
const BeakBoolColumn({
  required super.key,
  required super.label,
  super.visibleOn,
  super.sortable,
  super.searchable,
  super.filterable,
  super.rules,
  this.trueLabel,
  this.falseLabel,
});
```

| Field | Type | Default | Meaning |
|---|---|---|---|
| `trueLabel` | `String?` | `null` | Display label of the `true` state, if customized. |
| `falseLabel` | `String?` | `null` | Display label of the `false` state, if customized. |

Value type `bool`. Renders as `boolean` on every surface.

## Date, enum, and color columns

### `BeakDateTimeColumn`

A date/time column. Tables and detail views follow `format`; forms and filters
always use an absolute date picker regardless of `format`.

```dart title="packages/beak_core/lib/src/columns/beak_date_time_column.dart"
const BeakDateTimeColumn({
  required super.key,
  required super.label,
  super.visibleOn,
  super.sortable,
  super.searchable,
  super.filterable,
  super.rules,
  this.format = BeakDateFormat.standard,
});
```

| Field | Type | Default | Meaning |
|---|---|---|---|
| `format` | `BeakDateFormat` | `BeakDateFormat.standard` | Display format used in tables and detail views. |

Value type `DateTime`. The render intent is `relativeDate` in tables and detail
views when `format` is `relative`, otherwise `date`; forms and filters are
always `date`.

It also carries one helper method:

| Method | Returns | Meaning |
|---|---|---|
| `withFormat(BeakDateFormat format)` | `BeakDateTimeColumn` | A copy displaying with `format` instead, keeping every other property (key, label, visibility, rules) unchanged. |

`BeakDateFormat` values:

| Value | Renders as |
|---|---|
| `standard` | Locale-aware absolute date and time. |
| `relative` | Humanized relative timestamp ("3 days ago"). |
| `dateOnly` | Date part only. |
| `timeOnly` | Time part only. |
| `iso` | ISO-8601 string. |

```dart title="packages/beak_core/lib/src/columns/beak_date_time_column.dart"
static const updatedAt = BeakDateTimeColumn(
  key: 'updated_at',
  label: 'Updated',
  format: BeakDateFormat.relative,
  sortable: true,
  visibleOn: {BeakContext.table, BeakContext.detail},
);
```

### `BeakEnumColumn<T>`

A column over a Dart enum `T`, rendered as a colored badge in tables and a
select control in forms. The type parameter keeps the whole column type-safe:
`values`, `defaultValue`, `badgeColors`, and `labelOf` all speak in `T`, so there
are no stringly-typed states.

```dart title="packages/beak_core/lib/src/columns/beak_enum_column.dart"
const BeakEnumColumn({
  required super.key,
  required super.label,
  required this.values,
  super.visibleOn,
  super.sortable,
  super.searchable,
  super.filterable,
  super.rules,
  this.defaultValue,
  this.badgeColors = const <Never, BeakColor>{},
  this.labelOf,
});
```

| Field | Type | Default | Meaning |
|---|---|---|---|
| `values` | `List<T>` | required | All selectable values (typically `MyEnum.values`). |
| `defaultValue` | `T?` | `null` | Pre-selected value in create forms, if any. |
| `badgeColors` | `Map<T, BeakColor>` | `{}` | Badge color per value; unmapped values use the theme default. |
| `labelOf` | `String Function(T value)?` | `null` | Custom display labeller; defaults to the enum's `name`. |

Value type `T`. Renders as `badge` on every surface. Helper methods:

| Method | Returns | Meaning |
|---|---|---|
| `badgeColorFor(T value)` | `BeakColor?` | The badge color configured for `value`, or `null` when unmapped. |
| `labelFor(T value)` | `String` | The display label of `value`: `labelOf` when set, else `value.name`. |
| `valueByName(String name)` | `T?` | The declared value whose `name` matches `name`, or `null`. The one way stored rows and query params decode back into typed enum values without an `as` cast. |

```dart title="apps/reference_admin_models/lib/src/product.dart"
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

### `BeakColorColumn`

A color column holding hex strings (e.g. `#663399`), rendered as a swatch with a
color picker in forms. No extra fields.

```dart title="packages/beak_core/lib/src/columns/beak_color_column.dart"
const BeakColorColumn({
  required super.key,
  required super.label,
  super.visibleOn,
  super.sortable,
  super.searchable,
  super.filterable,
  super.rules,
});
```

Value type `String` (a hex color string). Renders as `color` on every surface.

## Upload columns

Both extend `BeakUploadColumn` and inherit `storagePath`, `maxSizeInBytes`, and
`allowedTypes` (documented [above](#upload-columns-share-three-more-fields)).

### `BeakImageColumn`

An image column: a thumbnail in table cells, an image picker in forms, and the
full image in detail views. Upload rules and the `transforms` pipeline run
server-side on upload and are mirrored client-side for fast feedback.

```dart title="packages/beak_core/lib/src/columns/beak_image_column.dart"
const BeakImageColumn({
  required super.key,
  required super.label,
  required super.storagePath,
  super.visibleOn,
  super.sortable,
  super.searchable,
  super.filterable,
  super.rules,
  super.maxSizeInBytes,
  super.allowedTypes = BeakFileType.images,
  this.maxDimensions,
  this.aspectRatio,
  this.thumbnail,
  this.transforms = const [],
});
```

| Field | Type | Default | Meaning |
|---|---|---|---|
| `allowedTypes` | `List<BeakFileType>` | `BeakFileType.images` | Overridden default: raster images (`jpeg`, `png`, `webp`, `gif`; `svg` excluded). |
| `maxDimensions` | `BeakDimensions?` | `null` | Largest accepted source dimensions, if bounded. |
| `aspectRatio` | `double?` | `null` | Enforced width/height ratio, if any. |
| `thumbnail` | `BeakDimensions?` | `null` | Dimensions of the auto-generated thumbnail rendition, if any. |
| `transforms` | `List<BeakImageTransform>` | `const []` | Transform pipeline run on upload, in order. |

Value type `String`. Render intents: `thumbnail` in tables, `image` in forms and
detail, `custom` in filters (there is no built-in image filter).

```dart title="packages/beak_core/lib/src/columns/beak_image_column.dart"
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

### `BeakFileColumn`

A generic file-attachment column. Values are stored file keys/URLs; rendering
goes through the custom escape hatch (a download/preview widget in
`beak_frontend`). Use `BeakImageColumn` instead for images. It adds no fields
beyond the shared upload three.

```dart title="packages/beak_core/lib/src/columns/beak_file_column.dart"
const BeakFileColumn({
  required super.key,
  required super.label,
  required super.storagePath,
  super.visibleOn,
  super.sortable,
  super.searchable,
  super.filterable,
  super.rules,
  super.maxSizeInBytes,
  super.allowedTypes,
});
```

Value type `String`. Renders as `custom` on every surface.

```dart title="packages/beak_core/lib/src/columns/beak_file_column.dart"
static const attachment = BeakFileColumn(
  key: 'attachment',
  label: 'Attachment',
  storagePath: 'articles/files',
  maxSizeInBytes: 10 * 1024 * 1024,
  allowedTypes: [BeakFileType.pdf],
);
```

## The escape hatch

### `BeakCustomColumn`

A column rendered by a custom builder registered in `beak_frontend` under a
`tag`. Auto-forms skip custom columns; reach for this for bespoke cells (a
sparkline, a status pill) that no built-in column covers. The same tag value
must be registered on the frontend so the renderer can be located.

```dart title="packages/beak_core/lib/src/columns/beak_custom_column.dart"
const BeakCustomColumn({
  required super.key,
  required super.label,
  required this.tag,
  super.visibleOn,
  super.sortable,
  super.searchable,
  super.filterable,
  super.rules,
});
```

| Field | Type | Default | Meaning |
|---|---|---|---|
| `tag` | `BeakColumnTag` | required | Identifies the registered custom renderer. |

Value type `Object` (the registered builder decides). Renders as `custom` on
every surface.

`BeakColumnTag` is an opaque identifier linking the column to its renderer:

```dart title="packages/beak_core/lib/src/columns/beak_custom_column.dart"
const BeakColumnTag(this.value);
```

| Field | Type | Meaning |
|---|---|---|
| `value` | `String` | Unique identity of the custom renderer. |

```dart title="packages/beak_core/lib/src/columns/beak_custom_column.dart"
static const badge = BeakCustomColumn(
  key: 'badge',
  label: 'Badge',
  tag: BeakColumnTag('badge'),
);
```

See [Custom columns](../extending/custom-columns.md) for how to register the
matching renderer on the frontend.

## Continue reading

- [Validation rules reference](validation-rules.md) every `BeakRule` you attach to a column's `rules` list.
- [Column types](../models/column-types.md) the guided tour of picking a column, with worked examples.
- [Rendering per surface](../concepts/rendering-per-surface.md) how a render intent becomes an obers_ui widget.
- [Files and storage columns](../models/files-and-storage-columns.md) upload rules, transforms, and storage drivers in depth.
