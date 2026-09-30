---
title: Annotations
description: Every annotation and authoring type a schema class uses, with each parameter, its default and the errors beak prepare reports for a misuse.
type: reference
audience: [expert, agent]
status: stable
search: {boost: 2}
---

# Annotations

A schema class is plain Dart plus annotations. `beak prepare` reads the class and writes the typed columns, relationships, model and record view next to it. This page lists every annotation and authoring type with its parameters, its defaults and the errors `beak prepare` reports when one is misused.

## Import

```dart title="examples/quickstart/lib/resources/notes/models/note.dart"
import 'package:beak/beak.dart';
import 'package:beak/schema.dart';

part 'note.beak.dart';
```

`package:beak/schema.dart` holds the annotations and the authoring types. It is separate from `package:beak/beak.dart` because `Column` and `Image` are also Flutter widget names, and `beak.dart` is the library the generated part file needs (`BeakContext`, `BeakOnDelete`, `BeakSemantic`, every rule, every column). A package that holds schema classes only imports `package:beak_core/beak_core.dart` and `package:beak_core/schema.dart` instead.

## Summary

| Annotation | Goes on | Declares |
| --- | --- | --- |
| [`@Resource`](#resource) | class | The class is a resource: table name, soft deletes, timestamps, schema ownership |
| [`@Column`](#column) | field | Everything a column needs that its Dart type does not say |
| [`@Display`](#display) | field | The field that stands for a record in pickers, links and titles |
| [`@Image`](#image-and-filefield), [`@FileField`](#image-and-filefield) | field | An upload column and its storage and file rules |
| [`@Badges`](#badges-and-enumlabels), [`@EnumLabels`](#badges-and-enumlabels) | enum field | Badge colour and display label per enum value |
| [`@Custom`](#custom) | `Object` field | An opaque column drawn by a registered renderer |
| [`@BelongsTo`](#belongsto) | schema-typed field | To-one relationship, this table holds the key |
| [`@HasOne`](#hasone) | schema-typed field | To-one relationship, the other table holds the key |
| [`@HasMany`](#hasmany) | `List<Schema>` field | To-many relationship, the other table holds the key |
| [`@BelongsToMany`](#belongstomany) | `List<Schema>` field | To-many relationship through a pivot table |

A field with no annotation is a valid column: its Dart type picks the column kind and its nullability decides whether it is required. [Field types](field-types.md) has the type to column table.

## BeakSchema

Every schema class is a `final class X extends BeakSchema`. The base class only marks the class as a description: its fields are `late final` and no constructor runs, so nothing ever instantiates one.

```dart title="packages/beak_core/lib/src/schema/beak_schema_annotations.dart"
@immutable
abstract base class BeakSchema {
  /// Enables `const` construction by subclasses. Never actually construct one.
  const BeakSchema();
}
```

A schema class can also declare four `static` getters. `beak prepare` looks for these exact names, and only as `static` getters (a `static final` field is not found). The generated model forwards each one to the matching `BeakModel` member.

| Getter | Type | Forwarded to | Page |
| --- | --- | --- | --- |
| `validationRules` | `List<BeakRecordRule>` | `BeakModel.validationRules` | [Validation rules](validation-rules.md) |
| `behavior` | `BeakModelBehavior` | `BeakModel.behavior` | [Behavior and actions](behavior-and-actions.md) |
| `permissions` | `BeakPermissions` | `BeakModel.permissions` | [Model-owned transports](../extending/model-transports.md) |
| `capabilities` | `Set<BeakOperation>` | `BeakModel.capabilities` | [Model-owned transports](../extending/model-transports.md) |

`BeakPermissions` only hides UI. The server enforces access through its own policies.

## Resource

Declares the class a resource. The class name drives the defaults: `Product` becomes the `products` table and the `ProductModel`, `ProductColumns` and `ProductFields` symbols.

```dart title="packages/beak_core/lib/src/schema/beak_schema_annotations.dart"
const Resource({
  this.table,
  this.softDeletes = false,
  this.timestamps = false,
  this.managesSchema = true,
});
```

| Parameter | Type | Default | Effect |
| --- | --- | --- | --- |
| `table` | `String?` | class name, snake-cased and pluralised | Physical table name: letters, digits and underscores, and one schema class per table (`beak prepare` refuses a dash, and two classes on one table). The pluraliser is small, see the rules below. |
| `softDeletes` | `bool` | `false` | Adds a `deletedAt` column (`deleted_at`). Deletes write it instead of removing the row, and the model reports `softDeletes => true`. |
| `timestamps` | `bool` | `false` | Adds `createdAt` and `updatedAt` (`created_at`, `updated_at`), stamped by the API. |
| `managesSchema` | `bool` | `true` | `false` when another system migrates the table (a Serverpod model, a database Beak was pointed at). `beak prepare` writes no migration for it. |

```dart title="examples/serverpod/bookshop_beak/lib/models/book.dart"
@Resource(table: 'book', managesSchema: false)
final class Book extends BeakSchema {
```

### Columns the resource adds

| Column | Added when | Kind | Visible on |
| --- | --- | --- | --- |
| `id` | The class declares no field named `id` | `BeakStringColumn` | detail |
| `<field>Id` | A `@BelongsTo` field has no column with its foreign key name | The related `id` column's kind | form |
| `createdAt` | `timestamps: true` | `BeakDateTimeColumn`, sortable | detail |
| `updatedAt` | `timestamps: true` | `BeakDateTimeColumn`, sortable, `BeakDateFormat.relative` | table, detail |
| `deletedAt` | `softDeletes: true` | `BeakDateTimeColumn` | detail |

A class that declares its own `id` (the Serverpod models declare `int? id`) keeps it, and `beak prepare` adds no `id` column. Declaring `createdAt` or `updatedAt` next to `timestamps: true`, or `deletedAt` next to `softDeletes: true`, would declare the column twice, so `beak prepare` refuses it.

## Column

Configures the column a field becomes. The field's Dart type selects the column kind, `@Column` carries what the type cannot say.

```dart title="packages/beak_core/lib/src/schema/beak_schema_annotations.dart"
const Column({
  this.columnName,
  this.label,
  this.visibleOn,
  this.sortable = false,
  this.searchable = false,
  this.filterable = false,
  this.indexed = false,
  this.unique = false,
  this.rules = const [],
  this.prefix,
  this.suffix,
  this.precision,
  this.totalDigits,
  this.format,
  this.placeholder,
  this.trueLabel,
  this.falseLabel,
  this.defaultValue,
  this.semantic,
  this.currencyFrom,
});
```

### Parameters on every kind

| Parameter | Type | Default | Effect |
| --- | --- | --- | --- |
| `columnName` | `String?` | field name, snake-cased | Storage column name (the column's `key`). |
| `label` | `String?` | field name, title-cased | Label in tables, forms and detail views. |
| `visibleOn` | `Set<BeakContext>?` | `{table, form, detail}` | Surfaces the column appears on. `BeakContext` has `table`, `form`, `detail` and `filter`. |
| `sortable` | `bool` | `false` | Table views may order by it. |
| `searchable` | `bool` | `false` | Search includes it. A password column is never searchable. |
| `filterable` | `bool` | `false` | The list page derives a filter control from it. |
| `indexed` | `bool` | `false` | The generated migration adds an index. Every belongs-to foreign key is indexed already. |
| `unique` | `bool` | `false` | A unique index, so `indexed` is redundant. The server also checks it before the write and answers `This value is already in use.` |
| `rules` | `List<BeakRule>` | `const []` | [Validation rules](validation-rules.md), enforced in the form and in the API. |
| `defaultValue` | `Object?` | `null` | Value used for a new record when the field is omitted. Must be a constant of the field's type (an enum value for an enum field). |
| `semantic` | `BeakSemantic?` | inferred from the Dart type | Domain meaning of the value, see [Field types](field-types.md#semantic-kinds). |

### Parameters that belong to one kind

`beak prepare` rejects one of these on a field of another kind or type, naming the field. A `Duration` is stored as an integer and a `BeakDate` or `BeakTime` as a string, but `prefix`, `suffix` and `placeholder` are refused on them too: the message reads `is a Duration field, which has no "prefix".`

| Parameter | Type | Applies to | Effect |
| --- | --- | --- | --- |
| `prefix`, `suffix` | `String?` | `int`, `double`, `BeakDecimal` | Text before or after the number. Switches the render intent from `number` to `currency`. |
| `precision` | `int?` | `double` | Fraction digits, displayed and stored (the SQL scale). The column default is `2`. |
| `totalDigits` | `int?` | `double` | Total stored digits, fraction digits included: `NUMERIC(totalDigits, precision)`. The column default is `10`, and `precision` may not exceed it. |
| `format` | `BeakDateFormat?` | `DateTime` | Table and detail rendering: `standard`, `relative`, `dateOnly`, `timeOnly`, `iso`. |
| `placeholder` | `String?` | `String` | Hint text in the empty input. |
| `trueLabel`, `falseLabel` | `String?` | `bool` | State labels. |
| `currencyFrom` | `Symbol?` | `BeakDecimal` with `BeakSemantic.money(...)` | Names the `String` schema field that holds the currency, for example `#currency`. |

`currencyFrom` is a `Symbol`, so a typo is a compile-time lookup error in `beak prepare` instead of a string that silently matches nothing. A `BeakDecimal` takes its scale from `BeakSemantic`, not from `precision`.

### Bounds are rules

`maxLength`, `min` and `max` are not `@Column` parameters any more. A bound is written once as a rule, and `beak prepare` derives the column sizing from it:

| Rule on the field | Also sets |
| --- | --- |
| `BeakMaxLength(n)` on a `String` | The column's `maxLength`, which caps typing in the form input |
| `BeakMin(n)` and `BeakMax(n)` on an `int` | The column's `min` and `max`, which bound the form stepper |

When a rule list repeats a bound, the tightest wins. A bound that is not an integer literal validates but sizes nothing.

### Rules added for you

A non-nullable field gets `BeakRequired()` at the front of its `rules`. A `List` field and a `BeakJsonObject` field get `BeakRequired(allowEmpty: true)`, because an empty list is a value. A nullable `bool` becomes a tri-state column. A password field is visible on `{BeakContext.form}` only, unless you pass `visibleOn`.

```dart title="examples/serverpod/bookshop_beak/lib/models/book.dart"
  /// Shelf price in cents.
  @Column(
    columnName: 'priceInCents',
    label: 'Price in cents',
    sortable: true,
    rules: [BeakMin(0)],
  )
  late final int priceInCents;
```

## Display

Marks the field that represents a record in pickers, links and titles.

```dart title="packages/beak_core/lib/src/schema/beak_schema_annotations.dart"
const Display();
```

Without one, Beak uses the first single-line text field that is not a password, and the `id` when there is none. A password field cannot be `@Display`. Put it on one field per class: `beak prepare` reports a class that marks two, naming both.

## Image and FileField

Declare an upload column. `@Image` applies to a `BeakImageRef` field, `@FileField` to a `BeakFileRef` field. The rules run in the panel before the upload starts and again in the API.

```dart title="packages/beak_core/lib/src/schema/beak_schema_annotations.dart"
const Image({
  required this.storagePath,
  this.maxSizeInBytes,
  this.allowedTypes = const [],
  this.maxDimensions,
  this.aspectRatio,
  this.transforms = const [],
});
```

```dart title="packages/beak_core/lib/src/schema/beak_schema_annotations.dart"
const FileField({
  required this.storagePath,
  this.maxSizeInBytes,
  this.allowedTypes = const [],
});
```

| Parameter | Type | Default | On | Effect |
| --- | --- | --- | --- | --- |
| `storagePath` | `String` | required | both | Storage subfolder uploads land in. |
| `maxSizeInBytes` | `int?` | `null` | both | Highest accepted upload size. `null` means the server's 100 MiB ceiling. |
| `allowedTypes` | `List<BeakFileType>` | `@Image`: `jpeg`, `png`, `webp`, `gif`. `@FileField`: `[]`, unrestricted | both | Accepted types: `jpeg`, `png`, `webp`, `gif`, `svg`, `pdf`, `csv`, `json`, `zip`, `mp4`, `mp3`. |
| `maxDimensions` | `BeakDimensions?` | `null` | `@Image` | Largest accepted source size. |
| `aspectRatio` | `double?` | `null` | `@Image` | Required width to height ratio. |
| `transforms` | `List<BeakImageTransform>` | `[]` | `@Image` | Transforms run on upload, in order: `BeakResizeTransform`, `BeakFormatTransform` (`.webp()`), `BeakThumbnailTransform`. |

A `BeakImageRef` or `BeakFileRef` field with no annotation is still an upload column, and its `storagePath` is the table name. The annotation constructors require `storagePath`, so `beak prepare` reports an `@Image()` or `@FileField()` that does not pass one. Uploads are covered on [Files and storage columns](../models/files-and-storage-columns.md).

## Badges and EnumLabels

Both apply to an enum field and are generic in that enum, so the map keys are checked against the field's own type.

```dart title="packages/beak_core/lib/src/schema/beak_schema_annotations.dart"
const Badges(this.colors);
```

```dart title="packages/beak_core/lib/src/schema/beak_schema_annotations.dart"
const EnumLabels(this.labels);
```

| Annotation | Type | Effect |
| --- | --- | --- |
| `@Badges<T>(Map<T, BeakColor>)` | `T extends Enum` | Badge colour per value. Unmapped values use the theme default. `BeakColor` has `primary`, `secondary`, `success`, `warning`, `error`, `info`, `muted`. |
| `@EnumLabels<T>(Map<T, String>)` | `T extends Enum` | Display label per value. The stored value stays the enum name, and an unmapped value shows its name. |

Illustration, from the annotation's own doc comment:

```dart
@EnumLabels<OrderStatus>({OrderStatus.inKitchen: 'In kitchen'})
late final OrderStatus status;
```

The enum must be declared somewhere under `lib/` of the same package. `beak prepare` cannot tell an enum from any other type by name, so it collects the enums it finds and rejects a type imported from elsewhere.

## Custom

Declares an opaque column that a renderer registered on the frontend draws. It applies to an `Object` field, and auto forms skip it.

```dart title="packages/beak_core/lib/src/schema/beak_schema_annotations.dart"
const Custom(this.tag);
```

| Parameter | Type | Effect |
| --- | --- | --- |
| `tag` | `String` | The key the frontend's cell-renderer registry looks up. Emitted as `BeakColumnTag(tag)`. |

See [Custom columns](../extending/custom-columns.md).

## Relationships

A relationship annotation goes on a field whose type is another schema class, or a `List` of one. Beak derives the foreign key, the pivot table and the other side of the relationship. The related class must be a `@Resource` under `lib/`.

| Annotation | Field type | Where the key lives | Nullable field means |
| --- | --- | --- | --- |
| `@BelongsTo` | `Other` or `Other?` | This table, as `<field>_id` | Optional relationship |
| `@HasOne` | `Other?` | The other table, as `<this class>_id` | Not required |
| `@HasMany` | `List<Other>` | The other table, as `<this class>_id` | Not required |
| `@BelongsToMany` | `List<Other>` | A pivot table | Not required |

A to-many field must be declared as `List<Other>`. A non-nullable to-one field is required. The generated constants are `XRelations.<field>` and `XFields.<field>`, see [Generated files and symbols](generated-files.md).

### BelongsTo

```dart title="packages/beak_core/lib/src/schema/beak_schema_annotations.dart"
const BelongsTo({
  this.label,
  this.foreignKey,
  this.searchOn = const <Symbol>[],
  this.onDelete = BeakOnDelete.setNull,
  this.inverse = true,
});
```

| Parameter | Type | Default | Effect |
| --- | --- | --- | --- |
| `label` | `String?` | field name, title-cased | Label of the relationship and of the foreign key column it owns. |
| `foreignKey` | `String?` | field name, snake-cased, plus `_id` | Foreign key column name. |
| `searchOn` | `List<Symbol>` | `[]` (the related display column) | Fields of the related schema the picker searches, for example `[#email, #lastName]`. |
| `onDelete` | `BeakOnDelete` | see below | What happens to this row when the related record is deleted. |
| `inverse` | `bool` | `true` | `false` stops Beak generating the has-many on the other side. |

`onDelete` is `BeakOnDelete.restrict` for a non-nullable field and `BeakOnDelete.setNull` for a nullable one, unless you pass a value. `BeakOnDelete` has `cascade`, `ormCascade`, `restrict`, `setNull`, `setDefault` and `noAction`.

```dart title="examples/serverpod/bookshop_beak/lib/models/book.dart"
  /// Who wrote it.
  @BelongsTo(
    foreignKey: 'authorId',
    onDelete: BeakOnDelete.cascade,
    inverse: false,
  )
  late final Author author;
```

### HasOne

```dart title="packages/beak_core/lib/src/schema/beak_schema_annotations.dart"
const HasOne({this.label, this.foreignKey, this.owned = false});
```

| Parameter | Type | Default | Effect |
| --- | --- | --- | --- |
| `label` | `String?` | field name, title-cased | Label of the relationship. |
| `foreignKey` | `String?` | owner class name, snake-cased, plus `_id` | Foreign key column on the related table. |
| `owned` | `bool` | `false` | The related record belongs exclusively to this one. |

### HasMany

```dart title="packages/beak_core/lib/src/schema/beak_schema_annotations.dart"
const HasMany({
  this.label,
  this.foreignKey,
  this.onDelete = BeakOnDelete.restrict,
  this.owned = false,
});
```

| Parameter | Type | Default | Effect |
| --- | --- | --- | --- |
| `label` | `String?` | field name, title-cased | Label of the relationship. |
| `foreignKey` | `String?` | owner class name, snake-cased, plus `_id` | Foreign key column on the related table. |
| `onDelete` | `BeakOnDelete` | `BeakOnDelete.restrict` | What happens to the children when this row is deleted. |
| `owned` | `bool` | `false` | The children belong exclusively to this record. An explicitly configured relationship editor may delete them. |

```dart title="examples/serverpod/bookshop_beak/lib/models/author.dart"
  /// Every book this author wrote.
  @HasMany(foreignKey: 'authorId', onDelete: BeakOnDelete.cascade)
  late final List<Book>? books;
```

### BelongsToMany

```dart title="packages/beak_core/lib/src/schema/beak_schema_annotations.dart"
const BelongsToMany({
  this.label,
  this.pivotTable,
  this.foreignPivotKey,
  this.relatedPivotKey,
  this.searchOn = const <Symbol>[],
  this.allowCreate = false,
  this.maxAllowed,
  this.onDelete = BeakOnDelete.cascade,
  this.inverse = true,
});
```

| Parameter | Type | Default | Effect |
| --- | --- | --- | --- |
| `label` | `String?` | field name, title-cased | Label of the relationship. |
| `pivotTable` | `String?` | both singular table names, sorted, joined by `_` | Join table. |
| `foreignPivotKey` | `String?` | singular owner table plus `_id` | Pivot column pointing at this table. |
| `relatedPivotKey` | `String?` | singular related table plus `_id` | Pivot column pointing at the related table. |
| `searchOn` | `List<Symbol>` | `[]` (the related display column) | Fields the picker searches. Checked like `BelongsTo.searchOn`. |
| `allowCreate` | `bool` | `false` | The relation manager may create related records inline. |
| `maxAllowed` | `int?` | `null` | Highest number of related records. |
| `onDelete` | `BeakOnDelete` | `BeakOnDelete.cascade` | What happens to the pivot rows when this row is deleted. |
| `inverse` | `bool` | `true` | `false` stops Beak generating the mirrored relationship. |

### Inverse sides

Declare the side you think about and Beak generates the other. A `@BelongsTo` on `Book` makes `Author` gain a has-many named after the plural table (`books`). A `@HasMany` or `@HasOne` makes the far side gain a belongs-to named after the singular table. A `@BelongsToMany` is mirrored. Beak skips the inverse when the far class already declares any relationship to the owner, so an explicit declaration always wins over a generated one.

## Authoring types

Dart has no separate type for long text or an uploaded image, so `package:beak/schema.dart` declares extension types over `String`. They compile away and exist to name a column kind.

| Type | Wraps | Column |
| --- | --- | --- |
| `BeakText` | `String` | `BeakTextColumn`, multi-line text |
| `BeakRichText` | `String` | `BeakRichTextColumn`, HTML or Markdown |
| `BeakHexColor` | `String` (`hex`) | `BeakColorColumn`, a `#rrggbb` colour |
| `BeakImageRef` | `String` (`storageKey`) | `BeakImageColumn` |
| `BeakFileRef` | `String` (`storageKey`) | `BeakFileColumn` |

```dart title="packages/beak_core/lib/src/schema/beak_schema_types.dart"
extension type const BeakText(String value) implements String {}
extension type const BeakRichText(String value) implements String {}
extension type const BeakHexColor(String hex) implements String {}
extension type const BeakImageRef(String storageKey) implements String {}
extension type const BeakFileRef(String storageKey) implements String {}
```

The plain Dart types `String`, `int`, `double`, `bool`, `DateTime`, any project `enum`, `BeakJson`, `BeakDate`, `BeakTime`, `Duration`, `BeakDecimal`, `BeakJsonObject` and `List` of a primitive need no annotation either. [Field types](field-types.md#summary) has the complete table.

## Errors from beak prepare

`beak prepare` reads the class without resolving it, so it reports these by field before it writes anything, all at once. Each line starts with `lib/<file>.dart:` and the class and field.

| Message | Cause | Fix |
| --- | --- | --- |
| `@Column(maxLength:) was removed. Declare the bound as a rule instead: rules: [BeakMaxLength(30)].` | `maxLength`, `min` or `max` passed to `@Column` | Use the rule the message names |
| `is a Uri, which Beak cannot map to a column.` | A field type Beak has no column for | Use a supported type, a relationship annotation or `@Custom` |
| `is a string column, which has no "precision".` | A kind-specific parameter on the wrong kind | Move it to a field of the kind in [the table above](#parameters-that-belong-to-one-kind) |
| `BeakSemantic.email is incompatible with int. Use its semantic Dart value type.` | A semantic on a Dart type it does not accept | Change the type, or see [Field types](field-types.md#semantic-kinds) |
| `is a password and cannot be @Display or searchable.` | `BeakSemantic.password()` with `@Display` or `searchable: true` | Remove one of them |
| `searchOn takes the related schema's fields as symbols, not column keys as strings. Write searchOn: [#name].` | Strings in `searchOn` | Write symbols |
| `searches #nope, which is not a field of Bad. Its fields are: ...` | A symbol that is not a field of the related class | Use a listed field |
| `is a to-many relationship, so it must be declared as a List of the related schema.` | `@HasMany` or `@BelongsToMany` on a single-value field | Declare `List<Other>` |
| `points at Ghost, which is not a @Resource under lib/.` | The related class has no `@Resource`, or is outside `lib/` | Annotate it, or move it |
| `currencyFrom #nope must name a String schema field on a BeakDecimal money column.` | `currencyFrom` on the wrong type, or naming a missing or non-`String` field | Point it at a `String` field |
| `has a field with no declared type.` | `late final x;` | Declare the type |
| `marks 2 fields @Display (name, sku). Exactly one field is the display column, so keep the annotation on one of them.` | `@Display` on more than one field of a class | Keep it on one |
| `@Image needs a storagePath, the folder its uploads land in.` | `@Image()` or `@FileField()` without `storagePath` | Write `@Image(storagePath: 'covers')`, or drop the annotation to use the table name |
| `cannot be generated: the typed record view wraps the underlying record as record` | A field named `record` | Rename the field; keep the column with `@Column(columnName: 'record')` |
| ``has no part directive. Add `part 'x.beak.dart';` under the imports`` | The schema file lacks `part '<file>.beak.dart';` | Add it under the imports |
| `declares no fields, so it has nothing to display.` | An empty schema class | Add a field |
| `names the table "bad-table", which is not a table name Beak can write a migration for.` | A `table:` with a dash, a space or a leading digit | Use letters, digits and underscores |
| `declares the table "notes", which Note (lib/...) already uses. A table has exactly one schema class` | Two schema classes on one table. The issue is on the class that wrote `table:`, or on the later one when both did | Give one another table, or merge them |
| `cannot be the name of a schema class: the code generated for it uses that name for something else` | A class named after a reserved type such as `List` | Rename the class and keep the table with `@Resource(table:)` |
| `is the created_at column that timestamps: true already adds, so the class would declare it twice.` | A field for a column that `timestamps` or `softDeletes` adds | Drop the field, or drop the option |

## Rules and limits

- `beak prepare` reads annotation arguments as source text and re-emits them. Anything valid in a `const` expression works, and the generated file is what the compiler checks.
- A schema class has to be a `@Resource` under `lib/`. Files ending `.beak.dart`, `.g.dart` or `.freezed.dart`, and files whose name starts with `_`, are not scanned.
- The pluraliser behind the default table name knows the regular rules and a short list of irregular words. It appends `es` after `s`, `x`, `z`, `ch` and `sh`, turns a consonant and `y` into `ies`, keeps the `y` after a vowel, and otherwise appends `s`. `Person` becomes `people`, `Day` and `Key` become `days` and `keys`, and `Staff` and `Media` stay as they are. Only the last word of a compound name changes, so `SalesPerson` becomes `sales_people`. Set `@Resource(table: 'analyses')` for a word it does not know, such as `Analysis`, which would otherwise become `analysises`.
- Renaming a field renames its column key unless `columnName` pins it. Pin it when the table already exists.
- A schema class cannot be called `List`, `String`, `Future`, `Function`, `Enum`, `DateTime`, `Schema`, `Migration`, `BeakSchema`, `Resource`, `Column`, `Display`, `BelongsTo`, `HasOne`, `HasMany` or `BelongsToMany`. The code generated for it, or its create-table migration, uses those names for something else, and the compile errors never mention the class. `beak prepare` refuses it, and `beak make:resource` and `beak introspect` name the class something else (`ListEntry`; keep the table with `@Resource(table: 'lists')`).
- Annotations declare structure. Presentation lives in the resource, [form screens](screens-and-layouts.md) and `beak.yaml`, and behaviour in the `behavior` getter.

## Source

- `packages/beak_core/lib/src/schema/beak_schema_annotations.dart` declares every annotation on this page.
- `packages/beak_core/lib/src/schema/beak_schema_types.dart` declares the authoring types.
- `packages/beak_cli/lib/src/schema/beak_schema_reader.dart` reads the class and produces the errors above.
- `packages/beak_cli/lib/src/schema/beak_schema_emitter.dart` writes the part file.
- `examples/serverpod/bookshop_beak/lib/models` holds the `Author` and `Book` schemas quoted here.

## Continue reading

- [Field types](field-types.md) maps each Dart type to its column and lists the column options.
- [Generated files and symbols](generated-files.md) lists what `beak prepare` writes from these annotations.
- [Validation rules](validation-rules.md) covers the rules you pass to `rules:`.
- [Defining models](../models/defining-models.md) walks through writing a schema class from scratch.
