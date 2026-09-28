---
title: Column types reference
description: Every BeakColumn subclass, the authoring type it is declared as, its constructor parameters, defaults, value type, and render intents.
---

# Column types reference

This page lists every column Beak ships: the authoring type each one is
declared as, the shared fields that live on the base `BeakColumn`, the extra
fields each of the thirteen leaf types adds, and the value type and render
intents each resolves to. Scan the overview table, then drop into the section
for the column you are configuring.

You do not construct a column. You declare a field on an `@Resource` class, and
`beak prepare` writes the `static const` column into the part file beside it:

```dart
@Column(searchable: true, sortable: true, rules: [BeakMaxLength(120)])
late final String name;
```

[See the maintained schema examples](../models/column-types.md).

That constant is what you reference everywhere else (`CategoryColumns.name`),
and it feeds six mouths: the table cell, the form field, the detail row, the
filter control, the REST validator, and the CSV column. The base class is
`sealed`, so a new column kind cannot be added without every consumer handling
it.

Two rules decide which column you get:

- **The field's type picks the kind.** `String` is a single-line text column,
  `BeakText` a multi-line one, `double` a decimal, `BeakImageRef` an upload.
- **The field's nullability decides required-ness.** A non-nullable field gets
  `BeakRequired()`; a nullable one does not. You never write that rule yourself.

## Overview

| You declare | Column | Value type | Render intent (table / form) | Type-specific options |
|---|---|---|---|---|
| `String` | [`BeakStringColumn`](#beakstringcolumn) | `String` | `text` / `text` | `placeholder`, `maxLength` |
| `BeakText` | [`BeakTextColumn`](#beaktextcolumn) | `String` | `text` / `text` | none |
| `int` | [`BeakIntColumn`](#beakintcolumn) | `int` | `number` / `number` | `min`, `max`, `prefix`, `suffix` |
| `double` | [`BeakDecimalColumn`](#beakdecimalcolumn) | `double` | `number` or `currency` | `precision`, `prefix`, `suffix` |
| `bool` | [`BeakBoolColumn`](#beakboolcolumn) | `bool` | `boolean` / `boolean` | `trueLabel`, `falseLabel` |
| `DateTime` | [`BeakDateTimeColumn`](#beakdatetimecolumn) | `DateTime` | `date` or `relativeDate` / `date` | `format` |
| any `enum` | [`BeakEnumColumn<T>`](#beakenumcolumnt) | `T` (an `Enum`) | `badge` / `badge` | `values`, `defaultValue`, `badgeColors`, `labelOf` |
| `BeakJson` | [`BeakJsonColumn`](#beakjsoncolumn) | `String` | `json` / `json` | none |
| `BeakRichText` | [`BeakRichTextColumn`](#beakrichtextcolumn) | `String` | `richText` / `richText` | none |
| `BeakHexColor` | [`BeakColorColumn`](#beakcolorcolumn) | `String` | `color` / `color` | none |
| `BeakImageRef` + `@Image` | [`BeakImageColumn`](#beakimagecolumn) | `String` | `thumbnail` / `image` | `storagePath`, `maxSizeInBytes`, `allowedTypes`, `maxDimensions`, `aspectRatio`, `thumbnail`, `transforms` |
| `BeakFileRef` + `@FileField` | [`BeakFileColumn`](#beakfilecolumn) | `String` | `custom` / `custom` | `storagePath`, `maxSizeInBytes`, `allowedTypes` |
| `Object?` + `@Custom` | [`BeakCustomColumn`](#beakcustomcolumn) | `Object` | `custom` / `custom` | `tag` |

The authoring types (`BeakText`, `BeakRichText`, `BeakHexColor`,
`BeakImageRef`, `BeakFileRef`) are extension types over `String` that compile
away. They exist because `String` alone cannot say whether a field is a name, a
body, rich text, a colour, or a stored file, and a `kind:` parameter on the
annotation would be exactly the stringly-typed discriminator Beak's typed
columns close.

The **render intent** is the ORM- and UI-neutral hint the column resolves to for
a surface; `beak_frontend` maps each intent to an obers_ui widget. See
[Rendering per surface](../concepts/rendering-per-surface.md) for the full list
of intents and how the mapping works.

## Shared fields (every column)

Every column carries these nine fields from the base `BeakColumn`. The per-type
sections below only document what each leaf *adds*.

| Field | `@Column` parameter | Default | Meaning |
|---|---|---|---|
| `key` | `columnName` | the snake-cased field name | Storage/DB column name. Beak wires it internally; you reference the column constant, never this string. |
| `label` | `label` | the title-cased field name | Human-readable label shown in tables, forms, and detail views. |
| `visibleOn` | `visibleOn` | `{table, form, detail}` | Surfaces this column appears on (filter is off by default). Narrow it to hide a field, e.g. `{BeakContext.form, BeakContext.detail}` for a long description. |
| `sortable` | `sortable` | `false` | Whether table views may sort by this column. |
| `searchable` | `searchable` | `false` | Whether search includes this column. |
| `filterable` | `filterable` | `false` | Whether the list page derives a filter control from it. |
| `indexed` | `indexed` | `false` | Whether the generated migration indexes it. Every belongs-to foreign key is indexed without being asked, so this is for the columns you sort or filter by often. |
| `unique` | `unique` | `false` | Whether the generated migration adds a unique index. A unique index is an index, so there is no reason to declare both. |
| `rules` | `rules` | `const []` | Declarative validation rules enforced on input, in order. See the [Validation rules reference](validation-rules.md). |

The base constructor, quoted verbatim:

```dart title="packages/beak_core/lib/src/columns/beak_column.dart"
--8<-- "packages/beak_core/lib/src/columns/beak_column.dart:BeakColumn"
```

Every column also exposes members the renderer, the backend mapper and your own
code read:

| Member | Type | Meaning |
|---|---|---|
| `renderConfig` | `BeakRenderConfig` | The per-context render intents (table, form, detail, filter). |
| `intentFor(BeakContext context)` | `BeakRenderIntent` | Shortcut for `renderConfig.intentFor(context)`. |
| `valueType` | `Type` | The Dart type this column's values take. |
| `readFrom(BeakRecord record)` | `V?` | This column's value in `record`, typed, or `null` when it carries no readable one. |
| `require(BeakRecord record)` | `V` | The same, throwing a `BeakRecordShapeException` naming the column instead of returning `null`. |

`readFrom` and `require` come from the `BeakTypedColumn<V>` mixin every leaf
carries, which is what makes `ProductColumns.price.readFrom(record)` a `double?`
at compile time. The generated record view (`record.asProduct.price`) is the
same reads with the nullability the schema declared.

### Upload columns share three more fields

`BeakImageColumn` and `BeakFileColumn` both extend the `sealed`
`BeakUploadColumn`, which adds where the file lands and how big and what type it
may be. You set them on `@Image` / `@FileField`, not `@Column`:

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

A single-line string, rendered as plain text everywhere. Declared as `String`,
and the workhorse for names, references and codes.

[See the maintained schema examples](../models/column-types.md).

```dart title="packages/beak_core/lib/src/columns/beak_string_column.dart"
--8<-- "packages/beak_core/lib/src/columns/beak_string_column.dart:BeakStringColumn"
```

| Field | Type | Default | Meaning |
|---|---|---|---|
| `placeholder` | `String` | `''` | Hint text shown in an empty form input. |
| `maxLength` | `int?` | `null` | Length cap the form input enforces while typing, if any. |

Value type `String`. Renders as `text` on every surface.

### `BeakTextColumn`

A multiline text column: a textarea in forms, truncated text in table cells, and
the full text in detail views. Declared as `BeakText`. It adds no fields of its
own.

[See the maintained schema examples](../models/column-types.md).

```dart title="packages/beak_core/lib/src/columns/beak_text_column.dart"
--8<-- "packages/beak_core/lib/src/columns/beak_text_column.dart:BeakTextColumn"
```

Value type `String`. Renders as `text` on every surface.

### `BeakRichTextColumn`

A rich-text column: a WYSIWYG editor in forms, rendered markup in tables and
detail views. Declared as `BeakRichText`. Values are stored as the raw markup
source string, not as parsed nodes. No extra fields.

[See the maintained schema examples](../models/column-types.md).

```dart title="packages/beak_core/lib/src/columns/beak_rich_text_column.dart"
--8<-- "packages/beak_core/lib/src/columns/beak_rich_text_column.dart:BeakRichTextColumn"
```

Value type `String`. Renders as `richText` on every surface.

### `BeakJsonColumn`

A structured-JSON column, declared as `BeakJson`. It carries its document as a
JSON *text* value, rendered pretty-printed and edited as multiline text; Beak
never surfaces a raw `Map<String, dynamic>`. Parse the text into a typed,
pattern-matchable tree with `BeakJson.decode` when you need structured access.
No extra fields.

[See the maintained schema examples](../models/column-types.md).

```dart title="packages/beak_core/lib/src/columns/beak_json_column.dart"
--8<-- "packages/beak_core/lib/src/columns/beak_json_column.dart:BeakJsonColumn"
```

Value type `String`. Renders as `json` on every surface.

## Number and boolean columns

### `BeakIntColumn`

An integer column, rendered as a locale-aware number. Declared as `int`.
`min`/`max` bound the form's stepper; pair them with `BeakMin`/`BeakMax` rules
to reject out-of-range values on submit as well. `prefix`/`suffix` carry a unit
into the rendering.

[See the maintained schema examples](../models/column-types.md).

```dart title="packages/beak_core/lib/src/columns/beak_int_column.dart"
--8<-- "packages/beak_core/lib/src/columns/beak_int_column.dart:BeakIntColumn"
```

| Field | Type | Default | Meaning |
|---|---|---|---|
| `min` | `int?` | `null` | Lowest value the form input offers, if bounded. |
| `max` | `int?` | `null` | Highest value the form input offers, if bounded. |
| `prefix` | `String?` | `null` | Text rendered before the number, if any. |
| `suffix` | `String?` | `null` | Text rendered after the number (e.g. ` pcs`), if any. |

Value type `int`. Renders as `number` on every surface.

### `BeakDecimalColumn`

A fractional-number column with fixed `precision`, declared as `double`. A
`prefix` or `suffix` (a currency symbol or a unit) switches its render intent
from `number` to `currency`.

[See the maintained schema examples](../models/column-types.md).

```dart title="packages/beak_core/lib/src/columns/beak_decimal_column.dart"
--8<-- "packages/beak_core/lib/src/columns/beak_decimal_column.dart:BeakDecimalColumn"
```

| Field | Type | Default | Meaning |
|---|---|---|---|
| `precision` | `int` | `2` | Fraction digits, displayed and stored. The generated migration uses it as the column's SQL scale. |
| `totalDigits` | `int` | `10` | Total stored digits, fraction digits included: the SQL precision of `NUMERIC(totalDigits, precision)`. |
| `prefix` | `String?` | `null` | Text rendered before the number (e.g. `€`), if any. |
| `suffix` | `String?` | `null` | Text rendered after the number (e.g. `kg`), if any. |

Value type `double`. Renders as `currency` when `prefix` or `suffix` is set,
otherwise `number`, on every surface.

### `BeakBoolColumn`

A boolean column, declared as `bool`: a toggle in forms, a yes/no indicator
elsewhere. `trueLabel`/`falseLabel` override the default state text.

[See the maintained schema examples](../models/column-types.md).

```dart title="packages/beak_core/lib/src/columns/beak_bool_column.dart"
--8<-- "packages/beak_core/lib/src/columns/beak_bool_column.dart:BeakBoolColumn"
```

| Field | Type | Default | Meaning |
|---|---|---|---|
| `trueLabel` | `String?` | `null` | Display label of the `true` state, if customized. |
| `falseLabel` | `String?` | `null` | Display label of the `false` state, if customized. |

Value type `bool`. Renders as `boolean` on every surface.

## Date, enum, and color columns

### `BeakDateTimeColumn`

A date/time column, declared as `DateTime`. Tables and detail views follow
`format`; forms and filters always use an absolute date picker regardless of
`format`.

[See the maintained schema examples](../models/column-types.md).

```dart title="packages/beak_core/lib/src/columns/beak_date_time_column.dart"
--8<-- "packages/beak_core/lib/src/columns/beak_date_time_column.dart:BeakDateTimeColumn"
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

`@Resource(timestamps: true)` adds `created_at` and `updated_at` as date-time
columns for you, stamped by the API.

### `BeakEnumColumn<T>`

A column over a Dart enum `T`, rendered as a coloured badge in tables and a
select control in forms. Declare the field as the enum and Beak reads its values
off the type; `@Badges` assigns a colour per value and is generic, so the map's
keys are checked against *this* field's enum.

[See the maintained schema examples](../models/column-types.md).

```dart title="packages/beak_core/lib/src/columns/beak_enum_column.dart"
--8<-- "packages/beak_core/lib/src/columns/beak_enum_column.dart:BeakEnumColumn"
```

| Field | Type | Default | Declared with |
|---|---|---|---|
| `values` | `List<T>` | required | the field's own enum type |
| `defaultValue` | `T?` | `null` | `@Column(defaultValue: ProductStatus.draft)` |
| `badgeColors` | `Map<T, BeakColor>` | `{}` | `@Badges({...})`; unmapped values use the theme default |
| `labelOf` | `String Function(T value)?` | `null` | a hand-written column only; defaults to the enum's `name` |

Value type `T`. Renders as `badge` on every surface. Helper methods:

| Method | Returns | Meaning |
|---|---|---|
| `badgeColorFor(T value)` | `BeakColor?` | The badge color configured for `value`, or `null` when unmapped. |
| `labelFor(T value)` | `String` | The display label of `value`: `labelOf` when set, else `value.name`. |
| `valueByName(String name)` | `T?` | The declared value whose `name` matches `name`, or `null`. The one way stored rows and query params decode back into typed enum values without an `as` cast. |

### `BeakColorColumn`

A color column holding hex strings (e.g. `#663399`), rendered as a swatch with a
color picker in forms. Declared as `BeakHexColor`. No extra fields.

[See the maintained schema examples](../models/column-types.md).

```dart title="packages/beak_core/lib/src/columns/beak_color_column.dart"
--8<-- "packages/beak_core/lib/src/columns/beak_color_column.dart:BeakColorColumn"
```

Value type `String` (a hex color string). Renders as `color` on every surface.

## Upload columns

Both extend `BeakUploadColumn` and inherit `storagePath`, `maxSizeInBytes`, and
`allowedTypes` (documented [above](#upload-columns-share-three-more-fields)).
They are declared with their own annotation rather than `@Column`, because the
upload rules are what there is to say about them.

### `BeakImageColumn`

An image column: a thumbnail in table cells, an image picker in forms, and the
full image in detail views. Declared as `BeakImageRef` with `@Image`. The rules
and the `transforms` pipeline run server-side on upload and are mirrored
client-side for fast feedback, so a client that skips the panel does not skip
the check.

[See the maintained schema examples](../models/column-types.md).

```dart title="packages/beak_core/lib/src/columns/beak_image_column.dart"
--8<-- "packages/beak_core/lib/src/columns/beak_image_column.dart:BeakImageColumn"
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

### `BeakFileColumn`

A generic file-attachment column, declared as `BeakFileRef` with `@FileField`.
Values are stored file keys/URLs; rendering goes through the custom escape hatch
(a download/preview widget in `beak_frontend`). Use `BeakImageColumn` instead
for images. It adds no fields beyond the shared upload three.

[See the maintained schema examples](../models/column-types.md).

```dart title="packages/beak_core/lib/src/columns/beak_file_column.dart"
--8<-- "packages/beak_core/lib/src/columns/beak_file_column.dart:BeakFileColumn"
```

Value type `String`. Renders as `custom` on every surface.

## The escape hatch

### `BeakCustomColumn`

A column rendered by a custom builder registered in the panel under a `tag`.
Declare an `Object?` field with `@Custom('tag')`. Auto-forms skip custom
columns; reach for this for bespoke cells (a sparkline, a stock bar) that no
built-in column covers. The same tag value must be registered on the frontend so
the renderer can be located.

[See the maintained schema examples](../models/column-types.md).

```dart title="packages/beak_core/lib/src/columns/beak_custom_column.dart"
--8<-- "packages/beak_core/lib/src/columns/beak_custom_column.dart:BeakCustomColumn"
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

See [Custom columns](../extending/custom-columns.md) for how to register the
matching renderer on the frontend.

## Continue reading

- [Annotations](annotations.md) `@Resource`, `@Column`, `@Display` and the rest, in one table.
- [Validation rules reference](validation-rules.md) every `BeakRule` you attach to a column's `rules` list.
- [Column types](../models/column-types.md) the guided tour of picking a column, with worked examples.
- [Rendering per surface](../concepts/rendering-per-surface.md) how a render intent becomes an obers_ui widget.
- [Files and storage columns](../models/files-and-storage-columns.md) upload rules, transforms, and storage drivers in depth.
