---
title: Field types
description: Every column Beak ships, the Dart type that selects it, its options and defaults, plus the semantic kinds and exact value types.
type: reference
audience: [expert, agent]
status: stable
search: {boost: 2}
---

# Field types

A field's Dart type selects its column. This page lists the thirteen column classes, the Dart type behind each, the options and defaults they take, and the semantic kinds and value types (`BeakDate`, `BeakTime`, `BeakDecimal`) that change what a column stores.

## Import

```dart
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';
```

The column classes, `BeakSemantic` and the value types come from `package:beak/beak.dart`. The authoring types (`BeakText`, `BeakRichText`, `BeakHexColor`, `BeakImageRef`, `BeakFileRef`) come from `package:beak/schema.dart`.

You do not construct a column. You declare a field on a `@Resource` class and `beak prepare` writes the `static const` column into `XColumns`, see [Annotations](annotations.md) and [Generated files and symbols](generated-files.md). The constructors below are what the generated code calls.

## Summary

Two rules decide which column you get. The field's Dart type picks the kind, and its nullability decides required-ness: a non-nullable field gets `BeakRequired()` in front of its rules, a nullable one does not.

| Dart type | Column | Value type (`XFields`, `XRecord`) | Stored as | Render intent (table / form) |
| --- | --- | --- | --- | --- |
| `String` | [`BeakStringColumn`](#beakstringcolumn) | `String` | text | `text` / `text` |
| `BeakText` | [`BeakTextColumn`](#beaktextcolumn) | `String` | text | `text` / `text` |
| `BeakRichText` | [`BeakRichTextColumn`](#beakrichtextcolumn) | `String` | markup source text | `richText` / `richText` |
| `BeakHexColor` | [`BeakColorColumn`](#beakcolorcolumn) | `String` | `#rrggbb` text | `color` / `color` |
| `BeakJson` | [`BeakJsonColumn`](#beakjsoncolumn) | `BeakJson` | JSON text | `json` / `json` |
| `int` | [`BeakIntColumn`](#beakintcolumn) | `int` | integer | `number` or `currency` |
| `double` | [`BeakDecimalColumn`](#beakdecimalcolumn) | `double` | `NUMERIC(totalDigits, precision)` | `number` or `currency` |
| `bool` | [`BeakBoolColumn`](#beakboolcolumn) | `bool` | boolean | `boolean` / `boolean` |
| `DateTime` | [`BeakDateTimeColumn`](#beakdatetimecolumn) | `DateTime` | timestamp | `date` or `relativeDate` / `date` |
| any project `enum` | [`BeakEnumColumn<T>`](#beakenumcolumn) | `T` | enum name as text | `badge` / `badge` |
| `BeakImageRef` | [`BeakImageColumn`](#beakimagecolumn) | `String` | storage key | `thumbnail` / `image` |
| `BeakFileRef` | [`BeakFileColumn`](#beakfilecolumn) | `String` | storage key | `custom` / `custom` |
| `Object` with `@Custom` | [`BeakCustomColumn`](#beakcustomcolumn) | `Object` | as the renderer decides | `custom` / `custom` |
| `BeakDate` | `BeakStringColumn` with `calendarDate` | `BeakDate` | `YYYY-MM-DD` text | `text` / `text` |
| `BeakTime` | `BeakStringColumn` with `time` | `BeakTime` | `HH:mm:ss` text | `text` / `text` |
| `Duration` | `BeakIntColumn` with `duration` | `Duration` | integer microseconds | `number` / `number` |
| `BeakDecimal` | `BeakIntColumn` with `exactDecimal` or `money` | `BeakDecimal` | integer units | `number` / `number` |
| `BeakJsonObject` | `BeakJsonColumn` with `object` | `BeakJsonObject` | JSON text | `json` / `json` |
| `List<String>`, `List<int>`, `List<double>`, `List<bool>` | `BeakJsonColumn` with `list` | the list | JSON text | `json` / `json` |

The mapping comes from this function, which `beak prepare` uses:

```dart
--8<-- "packages/beak_cli/lib/src/schema/beak_schema_ir.dart:beakColumnKindOfType"
```

The last six rows show that some Dart types share a physical column with another and differ in their [semantic kind](#semantic-kinds). The semantic is inferred from the type, so you write nothing.

The authoring types are extension types over `String` (`BeakImageRef` and `BeakFileRef` wrap a storage key). They compile away. They exist because `String` alone cannot say whether a field is a name, a body, a colour or a stored file, and a `kind:` parameter on the annotation would be the string-typed discriminator Beak's typed columns close.

A field type Beak cannot map is an error from `beak prepare`, listed on [Annotations](annotations.md#errors-from-beak-prepare).

## Shared by every column

`BeakColumn` is `sealed`: the thirteen leaf classes above are the whole hierarchy, so a `switch` over a column is exhaustive. Its constructor:

```dart
--8<-- "packages/beak_core/lib/src/columns/beak_column.dart:BeakColumn"
```

| Field | Type | Default | `@Column` parameter | Meaning |
| --- | --- | --- | --- | --- |
| `key` | `String` | required | `columnName` | Storage column name, snake case. Code references the column constant, not this string. |
| `label` | `String` | required | `label` | Label in tables, forms and detail views. |
| `visibleOn` | `Set<BeakContext>` | `{table, form, detail}` | `visibleOn` | Surfaces the column appears on. `filter` is off by default. |
| `sortable` | `bool` | `false` | `sortable` | Table views may order by it. |
| `searchable` | `bool` | `false` | `searchable` | Search includes it. Reads `false` for a password semantic whatever was passed. |
| `filterable` | `bool` | `false` | `filterable` | The list derives a filter control from it. |
| `indexed` | `bool` | `false` | `indexed` | The generated migration adds an index. |
| `unique` | `bool` | `false` | `unique` | A unique index. The server also preflights it. |
| `rules` | `List<BeakRule>` | `const []` | `rules` | [Validation rules](validation-rules.md), in order. |
| `semantic` | `BeakSemantic` | `BeakSemantic()` | `semantic` | Domain meaning and lossless codec, see [Semantic kinds](#semantic-kinds). |
| `defaultValue` | `Object?` | `null` | `defaultValue` | Initial value for a new record when none is supplied. |

Members every column exposes:

| Member | Type | Meaning |
| --- | --- | --- |
| `renderConfig` | `BeakRenderConfig` | The render intent per context, see [Render intents](#render-intents). |
| `intentFor(BeakContext context)` | `BeakRenderIntent` | Shortcut for `renderConfig.intentFor(context)`. |
| `valueType` | `Type` | The Dart type the column's values take. |
| `readValue(BeakValue? value)` | `V?` | Reads a wire value as `V`, or `null` when it cannot be represented. Accepts the wire shapes a source may produce (Postgres returns numerics and timestamps as strings, SQLite booleans as `0` and `1`). |
| `readFrom(BeakRecord record)` | `V?` | This column's value in `record`, or `null`. |
| `require(BeakRecord record)` | `V` | The same, throwing a `BeakRecordShapeException` that names the column. Used for `BeakRequired` columns. |

`readValue`, `readFrom` and `require` come from the `BeakTypedColumn<V>` mixin every leaf carries. It is declared without an `on BeakColumn` clause so that it does not become a subtype of the sealed class and break exhaustiveness. The generated `record.asProduct.price` is the same read with the nullability the schema declared.

## Text columns

### BeakStringColumn

A single-line string. Declared as `String`. Also backs `BeakDate`, `BeakTime` and every string semantic (`email`, `url`, `phone`, `slug`, `uuid`, `password`).

```dart
--8<-- "packages/beak_core/lib/src/columns/beak_string_column.dart:BeakStringColumn"
```

| Field | Type | Default | Declared with | Meaning |
| --- | --- | --- | --- | --- |
| `placeholder` | `String` | `''` | `@Column(placeholder:)` | Hint text in the empty input. |
| `maxLength` | `int?` | `null` | `rules: [BeakMaxLength(n)]` | Length cap the form input enforces while typing. Derived from the rule. |

### BeakTextColumn

A multi-line string: a text area in forms, truncated text in table cells, the full text in detail views. Declared as `BeakText`. Adds no fields.

```dart
--8<-- "packages/beak_core/lib/src/columns/beak_text_column.dart:BeakTextColumn"
```

### BeakRichTextColumn

A rich-text column: an editor in forms, rendered markup in tables and detail views. Declared as `BeakRichText`. The value is the raw markup source, not parsed nodes. Adds no fields.

```dart
--8<-- "packages/beak_core/lib/src/columns/beak_rich_text_column.dart:BeakRichTextColumn"
```

### BeakJsonColumn

A JSON column, declared as `BeakJson`. The stored value is JSON text, rendered pretty-printed and edited as multi-line text. Beak never surfaces a `Map<String, dynamic>`: parse the text into a typed tree with `BeakJson.decode`. Adds no fields.

```dart
--8<-- "packages/beak_core/lib/src/columns/beak_json_column.dart:BeakJsonColumn"
```

| Member | Returns | Meaning |
| --- | --- | --- |
| `readDocument(BeakValue? value)` | `BeakJson?` | The value as a typed tree, `null` when it is missing or not valid JSON. |

`BeakJson` is sealed: `BeakJsonObject(entries)`, `BeakJsonArray(items)`, `BeakJsonString(value)`, `BeakJsonNumber(value)`, `BeakJsonBool(value)` and `BeakJsonNull()`. `BeakJson.decode(String)` parses, `BeakJson.fromEncodable(Object?)` converts decoded JSON, and `encode()` and `toEncodable()` go back.

## Number and boolean columns

### BeakIntColumn

An integer column, rendered as a locale-aware number. Declared as `int`. Also backs `Duration` and `BeakDecimal` through their semantic.

```dart
--8<-- "packages/beak_core/lib/src/columns/beak_int_column.dart:BeakIntColumn"
```

| Field | Type | Default | Declared with | Meaning |
| --- | --- | --- | --- | --- |
| `min` | `int?` | `null` | `rules: [BeakMin(n)]` | Lowest value the form stepper offers. Derived from the rule. |
| `max` | `int?` | `null` | `rules: [BeakMax(n)]` | Highest value the form stepper offers. Derived from the rule. |
| `prefix` | `String?` | `null` | `@Column(prefix:)` | Text before the number. |
| `suffix` | `String?` | `null` | `@Column(suffix:)` | Text after the number. |

A prefix or suffix changes the render intent from `number` to `currency`.

### BeakDecimalColumn

A fractional-number column with fixed `precision`. Declared as `double`.

```dart
--8<-- "packages/beak_core/lib/src/columns/beak_decimal_column.dart:BeakDecimalColumn"
```

| Field | Type | Default | Declared with | Meaning |
| --- | --- | --- | --- | --- |
| `precision` | `int` | `2` | `@Column(precision:)` | Fraction digits, displayed and stored. The generated migration uses it as the SQL scale. Must not be negative. |
| `totalDigits` | `int` | `10` | `@Column(totalDigits:)` | Total stored digits: `NUMERIC(totalDigits, precision)`. `precision` may not exceed it (asserted at construction). |
| `prefix` | `String?` | `null` | `@Column(prefix:)` | Text before the number, for example `€`. |
| `suffix` | `String?` | `null` | `@Column(suffix:)` | Text after the number, for example `kg`. |

The Dart value is an IEEE `double`. The default leaves eight digits before the point, which suits money and not a scientific quantity. Use `BeakDecimal` when the value has to stay exact, see [Exact decimals](#beakdecimal).

### BeakBoolColumn

A boolean: a switch in forms, a yes or no indicator elsewhere. Declared as `bool`.

```dart
--8<-- "packages/beak_core/lib/src/columns/beak_bool_column.dart:BeakBoolColumn"
```

| Field | Type | Default | Declared with | Meaning |
| --- | --- | --- | --- | --- |
| `tristate` | `bool` | `false` | a nullable `bool` field | `null` is a selectable state instead of `false`. |
| `trueLabel` | `String?` | `null` | `@Column(trueLabel:)` | Label of the `true` state. |
| `falseLabel` | `String?` | `null` | `@Column(falseLabel:)` | Label of the `false` state. |

## Date, enum and colour columns

### BeakDateTimeColumn

A timestamp column, declared as `DateTime`. Tables and detail views follow `format`. Forms and filters always use an absolute date picker.

```dart
--8<-- "packages/beak_core/lib/src/columns/beak_date_time_column.dart:BeakDateTimeColumn"
```

| Field | Type | Default | Declared with | Meaning |
| --- | --- | --- | --- | --- |
| `format` | `BeakDateFormat` | `BeakDateFormat.standard` | `@Column(format:)` | Display format in tables and detail views. |

`withFormat(BeakDateFormat format)` returns a copy with another format and every other property kept.

```dart title="packages/beak_core/lib/src/columns/beak_date_time_column.dart"
enum BeakDateFormat {
  /// Locale-aware absolute date and time.
  standard,

  /// Humanized relative timestamp ("3 days ago").
  relative,

  /// Date part only.
  dateOnly,

  /// Time part only.
  timeOnly,

  /// ISO-8601 string.
  iso,
}
```

`@Resource(timestamps: true)` adds `createdAt` and `updatedAt` columns of this kind.

### BeakEnumColumn

`BeakEnumColumn<T>` is a column over a Dart enum `T`: a badge in tables, a select in forms. The field's own enum supplies `values`.

```dart
--8<-- "packages/beak_core/lib/src/columns/beak_enum_column.dart:BeakEnumColumn"
```

| Field | Type | Default | Declared with | Meaning |
| --- | --- | --- | --- | --- |
| `values` | `List<T>` | required | the field's enum type | Selectable values. |
| `defaultValue` | `T?` | `null` | `@Column(defaultValue:)` | Value a create form starts on. |
| `badgeColors` | `Map<T, BeakColor>` | `{}` | `@Badges` | Colour per value. Unmapped values use the theme default. |
| `labelOf` | `String Function(T value)?` | `null` | hand-written column only | Custom labeller. |
| `labels` | `Map<T, String>` | `{}` | `@EnumLabels` | Display labels. Omitted values keep their enum name. |

| Method | Returns | Meaning |
| --- | --- | --- |
| `badgeColorFor(T value)` | `BeakColor?` | The configured colour, `null` when unmapped. |
| `labelFor(T value)` | `String` | `labelOf`, then `labels`, then the enum name. |
| `valueByName(String name)` | `T?` | The declared value with that `name`, `null` when none. The way stored strings decode into typed values without an `as` cast. |

A stored name that is no longer declared reads as `null` instead of throwing, so a row written before a value was removed degrades instead of crashing.

### BeakColorColumn

A colour stored as a hex string such as `#663399`: a swatch in tables, a picker in forms. Declared as `BeakHexColor`. Adds no fields. The value must match `#` plus 3, 4, 6 or 8 hexadecimal digits.

```dart
--8<-- "packages/beak_core/lib/src/columns/beak_color_column.dart:BeakColorColumn"
```

## Upload columns

`BeakImageColumn` and `BeakFileColumn` extend the sealed `BeakUploadColumn`, which adds where a file lands and how big and of what type it may be. The value is the stored file's key. Declare them with `@Image` and `@FileField`, or leave the annotation off and get `storagePath` set to the table name.

```dart
--8<-- "packages/beak_core/lib/src/columns/beak_column.dart:BeakUploadColumn"
```

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `storagePath` | `String` | required | Storage subfolder uploads land in. |
| `maxSizeInBytes` | `int?` | `null` | Highest accepted size. |
| `allowedTypes` | `List<BeakFileType>` | `[]` | Accepted types. Empty means unrestricted. |

### BeakImageColumn

A thumbnail in tables, a picker in forms, the full image in detail views. The rules and the `transforms` pipeline run on the server at upload and are mirrored in the panel for fast feedback.

```dart
--8<-- "packages/beak_core/lib/src/columns/beak_image_column.dart:BeakImageColumn"
```

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `allowedTypes` | `List<BeakFileType>` | `BeakFileType.images` | Overridden default: `jpeg`, `png`, `webp`, `gif`. `svg` is excluded on purpose. |
| `maxDimensions` | `BeakDimensions?` | `null` | Largest accepted source size. |
| `aspectRatio` | `double?` | `null` | Enforced width to height ratio. |
| `thumbnail` | `BeakDimensions?` | `null` | Size of the generated thumbnail rendition. |
| `transforms` | `List<BeakImageTransform>` | `const []` | Run on upload, in order. |

### BeakFileColumn

A file attachment, drawn by the custom renderer (a download or preview widget). Use `BeakImageColumn` for images. Adds nothing to the three shared upload fields.

```dart
--8<-- "packages/beak_core/lib/src/columns/beak_file_column.dart:BeakFileColumn"
```

## BeakCustomColumn

The escape hatch: a column drawn by a builder registered on the frontend under a tag. Auto forms skip it.

```dart
--8<-- "packages/beak_core/lib/src/columns/beak_custom_column.dart:BeakCustomColumn"
```

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `tag` | `BeakColumnTag` | required | Identifies the registered renderer. |

`BeakColumnTag(String value)` compares by `value`. See [Custom columns](../extending/custom-columns.md) for the renderer side.

## Semantic kinds

A `BeakSemantic` gives a column domain meaning and a lossless codec without changing its physical column. It is inferred for `BeakDate`, `BeakTime`, `Duration`, `BeakDecimal`, `BeakJsonObject` and primitive lists, and set with `@Column(semantic: ...)` for the rest.

```dart title="packages/beak_core/lib/src/columns/beak_semantic.dart"
const BeakSemantic.email() : this(kind: BeakSemanticKind.email);
const BeakSemantic.url() : this(kind: BeakSemanticKind.url);
const BeakSemantic.phone() : this(kind: BeakSemanticKind.phone);
const BeakSemantic.slug() : this(kind: BeakSemanticKind.slug);
const BeakSemantic.uuid() : this(kind: BeakSemanticKind.uuid);
const BeakSemantic.password() : this(kind: BeakSemanticKind.password);
const BeakSemantic.calendarDate() : this(kind: BeakSemanticKind.calendarDate);
const BeakSemantic.time() : this(kind: BeakSemanticKind.time);
const BeakSemantic.duration() : this(kind: BeakSemanticKind.duration);
const BeakSemantic.exactDecimal({int scale = 2})
  : this(kind: BeakSemanticKind.exactDecimal, scale: scale);
const BeakSemantic.money({
  int scale = 2,
  String? currency,
  BeakColumn? currencyColumn,
}) : this(
       kind: BeakSemanticKind.money,
       scale: scale,
       currency: currency,
       currencyColumn: currencyColumn,
     );
const BeakSemantic.percentage({num scale = 100})
  : this(kind: BeakSemanticKind.percentage, percentageScale: scale);
const BeakSemantic.quantity({String? unit})
  : this(kind: BeakSemanticKind.quantity, unit: unit);
const BeakSemantic.fileSize() : this(kind: BeakSemanticKind.fileSize);
```

The list and object semantics take a schema argument:

```dart title="packages/beak_core/lib/src/columns/beak_semantic.dart"
const BeakSemantic.list(
  BeakPrimitiveType itemType, {
  int? minItems,
  int? maxItems,
  bool distinctItems = false,
  List<BeakRule> itemRules = const [],
}) : this(
       kind: BeakSemanticKind.primitiveList,
       listItemType: itemType,
       minItems: minItems,
       maxItems: maxItems,
       distinctItems: distinctItems,
       itemRules: itemRules,
     );
const BeakSemantic.object(BeakObjectSchema schema)
  : this(kind: BeakSemanticKind.object, objectSchema: schema);
```

| Kind | Dart type | Stored as | Checked by |
| --- | --- | --- | --- |
| `none` | the column's own | as the column | nothing extra |
| `email` | `String` | text | `BeakEmail` |
| `url` | `String` | text | `BeakUrl` |
| `phone` | `String` | text | `+` optional, 5 to 25 characters of digits, spaces, `()` and `-`, at least 5 digits |
| `slug` | `String` | text | lowercase letters and digits with single hyphens |
| `uuid` | `String` | text | canonical hyphenated form |
| `password` | `String` | text | nothing extra. Input is obscured, cells show bullets, it is form-only by default, and it cannot be searchable or `@Display` |
| `calendarDate` | `BeakDate` | `YYYY-MM-DD` text | a valid Gregorian date |
| `time` | `BeakTime` | `HH:mm:ss[.ffffff]` text | a valid time of day |
| `duration` | `Duration` | integer microseconds | an integer within ±(2^53-1) |
| `exactDecimal` | `BeakDecimal` | integer units at `scale` | an integer within ±(2^53-1) |
| `money` | `BeakDecimal` | integer units at `scale` | as `exactDecimal`; currency from `currency` or from the record's `currencyColumn` |
| `percentage` | `int` or `double` | as the column | `percentageScale` is the stored value that means 100% |
| `quantity` | `int` or `double` | as the column | `unit` is a display label |
| `fileSize` | `int` | integer bytes | a non-negative integer |
| `primitiveList` | `List<String>`, `List<int>`, `List<double>` or `List<bool>` | JSON text | `minItems`, `maxItems`, `distinctItems`, `itemRules` per item |
| `object` | `BeakJsonObject` | JSON text | the declared child columns, and unknown properties unless `allowUnknown` |

`beak prepare` checks that the semantic fits the Dart type and names the field when it does not. `scale` is 0 to 12, and `BeakSemantic` asserts it.

`@Column(currencyFrom: #currency)` on a `BeakDecimal` money field names the `String` schema field that holds the currency. The generator turns the symbol into `currencyColumn: XColumns.currency`.

### BeakDate and BeakTime

Both are value classes without a timezone. Neither converts an instant: `BeakDate.fromDateTime` reads the calendar components as they are.

| Member | Meaning |
| --- | --- |
| `BeakDate(year, month, day)` | A Gregorian date. Asserts year 1 to 9999 and a real day of the month. |
| `BeakDate.parse(String)` | Exactly `YYYY-MM-DD`. Throws a `FormatException` for anything else, including `2026-02-30`. |
| `BeakDate.tryParse(String)` | The same, returning `null`. |
| `BeakDate.fromDateTime(DateTime)` | Takes year, month and day and drops the rest. |
| `toDateTime()` | A local midnight for calendar widgets. |
| `BeakTime(hour, minute, {second, microsecond})` | A wall-clock time. |
| `BeakTime.parse(String)`, `tryParse` | `HH:mm`, `HH:mm:ss` or up to six fractional digits. No offsets. |
| `microsecondsSinceMidnight` | Exact ordering value. |

Both are `Comparable` and compare by value.

### BeakDecimal

An exact fixed-scale decimal, stored and sent as an integer count of units. The coefficient is limited to ±9007199254740991 (`BeakDecimal.maxUnits`), which native Dart, JavaScript, JSON and SQL integer columns all represent exactly. Arithmetic uses integers and never converts to floating point.

| Member | Meaning |
| --- | --- |
| `BeakDecimal(int units, {int scale = 2})` | `units` times 10^-`scale`. Scale is 0 to 12. |
| `BeakDecimal.parse(String, {int scale = 2})` | Rejects excess precision and overflow with a `FormatException`. Trailing zeros beyond the scale are accepted. |
| `BeakDecimal.tryParse(String, {int scale = 2})` | The same, returning `null`. |
| `rescale(int targetScale)` | Changes scale without rounding. Throws when reducing scale would lose digits. |
| `+`, `-` | Result at the greater scale. |
| `*` | Multiplies by an `int` quantity only. |
| `compareTo`, `==` | Compare by value across scales. `1.5` equals `1.50`. |

Parsed with the default scale of 2:

```text
BeakDecimal.parse('19.99')             units 1999, scale 2
BeakDecimal.tryParse('19.999')         null   (a third digit is not zero)
BeakDecimal.tryParse('19.990')         19.99
BeakDecimal.parse('19.99') * 3         59.97
BeakDecimal.tryParse('9007199254740992', scale: 0)   null   (over maxUnits)
```

## Render intents

`BeakRenderIntent` is the UI-neutral hint a column resolves to per surface. `beak_core` never imports Flutter, and the frontend maps each intent to an obers_ui widget.

| Intent | Meaning |
| --- | --- |
| `text` | Plain single-line text |
| `number` | Locale-aware number |
| `currency` | Amount with prefix or suffix |
| `badge` | Coloured chip |
| `image` | Full image |
| `thumbnail` | Small preview |
| `boolean` | Toggle, checkmark or yes/no |
| `date` | Absolute date or timestamp |
| `relativeDate` | "3 days ago" |
| `relationLink` | Link to one related record |
| `relationBadges` | Badge list of related records |
| `richText` | Rendered markup |
| `color` | Swatch |
| `json` | Pretty-printed JSON |
| `custom` | A registered renderer |

`BeakRenderConfig(table:, form:, detail:, filter:)` holds one intent per `BeakContext`. `BeakRenderConfig.uniform(intent)` uses the same one everywhere. `BeakDateTimeColumn` differs by surface (relative in tables and detail views, an absolute picker in forms and filters), and `BeakImageColumn` renders `thumbnail` in tables, `image` in forms and detail views and `custom` in filters, because there is no built-in image filter.

## Rules and limits

- The hierarchy is sealed. A new column kind is a framework change, not an extension. For a cell Beak does not draw, use `BeakCustomColumn`.
- `BeakDate`, `BeakTime`, `Duration` and `BeakDecimal` fields share a physical text or integer column. The migration creates that column, and raw SQL sees the stored form: `YYYY-MM-DD`, `HH:mm:ss`, microseconds, units.
- `precision` and `totalDigits` belong to `double`. On a `BeakDecimal`, the scale lives in the semantic.
- A `double` column with a currency prefix is still a `double`. Money that must add up belongs in `BeakDecimal` with `BeakSemantic.money`.
- `List` fields hold primitives only, and are stored as JSON text. A list of schema objects is a relationship.
- An enum must be declared under `lib/` of the same package so `beak prepare` can find it.
- Wire values are read leniently and written strictly: `readValue` returns `null` for a value it cannot represent, while `BeakSemantic.decode` throws a `FormatException` for malformed data so validation cannot mistake it for an absent field.

## Source

- `packages/beak_core/lib/src/columns/beak_column.dart` holds `BeakColumn`, `BeakTypedColumn` and `BeakUploadColumn`, and one file per leaf column beside it.
- `packages/beak_core/lib/src/columns/beak_semantic.dart` holds `BeakSemantic`, `BeakSemanticKind`, `BeakPrimitiveType` and `BeakObjectSchema`.
- `packages/beak_core/lib/src/columns/beak_semantic_values.dart` holds `BeakDate`, `BeakTime` and `BeakDecimal`.
- `packages/beak_core/lib/src/columns/beak_json.dart` holds the `BeakJson` tree.
- `packages/beak_core/lib/src/columns/beak_render_config.dart` and `packages/beak_core/lib/src/context/beak_render_intent.dart` hold the render intents.
- `packages/beak_cli/lib/src/schema/beak_schema_ir.dart` holds the type to column mapping (`BeakColumnKind.ofType`).

## Continue reading

- [Annotations](annotations.md) lists the `@Column` parameters that fill these constructors.
- [Validation rules](validation-rules.md) covers the rules a column's `rules` list takes and the checks each column kind makes itself.
- [Semantic fields](../models/semantic-fields.md) shows the semantic kinds in a worked model.
- [Files and storage columns](../models/files-and-storage-columns.md) covers upload rules, transforms and storage drivers.
