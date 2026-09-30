# Fields

> Pick the Dart type that becomes the column you want, set what @Column adds to it, and give an enum readable labels and badge colours.

Every field in a schema class becomes a column, and its Dart type does the choosing. After this page you can pick the type for each thing you store, say what `@Column` adds on top, and give an enum labels and colours.

You do not write a column class, a form input and a table cell for each field. You write `late final String title;` and Beak derives all three. The price is that the type has to say what you mean, so it is worth knowing the list.

## At a glance

| You store | Declare | Column | Note |
| --- | --- | --- | --- |
| A name, a title, a code | `String` | `BeakStringColumn` | One line. `BeakMaxLength(n)` also sizes the column |
| A paragraph | `BeakText` | `BeakTextColumn` | Multi-line input, truncated in tables |
| Formatted text | `BeakRichText` | `BeakRichTextColumn` | An editor, rendered markup elsewhere |
| A whole number | `int` | `BeakIntColumn` | `BeakMin` and `BeakMax` bound the stepper |
| A measurement that may round | `double` | `BeakDecimalColumn` | `precision:` sets the fraction digits |
| An amount that must add up | `BeakDecimal` with a money semantic | `BeakIntColumn` | Exact, see [Semantic fields](semantic-fields.md) |
| Yes or no | `bool` | `BeakBoolColumn` | `bool?` adds a third state, unset |
| A moment | `DateTime` | `BeakDateTimeColumn` | An instant, `format:` picks the display |
| A calendar day, a time of day, a span | `BeakDate`, `BeakTime`, `Duration` | text or integer | See [Semantic fields](semantic-fields.md) |
| One of a fixed set | Any enum declared under `lib/` | `BeakEnumColumn<T>` | A badge in tables, a select in forms |
| A colour | `BeakHexColor` | `BeakColorColumn` | `#rrggbb`, a swatch and a picker |
| Any JSON | `BeakJson` | `BeakJsonColumn` | A typed tree, never a `Map<String, dynamic>` |
| A list of strings, numbers or flags | `List<String>`, `List<int>`, `List<double>`, `List<bool>` | JSON column | See [Semantic fields](semantic-fields.md) |
| An uploaded image or file | `BeakImageRef`, `BeakFileRef` | `BeakImageColumn`, `BeakFileColumn` | See [Files and storage columns](files-and-storage-columns.md) |
| Something Beak has no column for | `Object?` with `@Custom('tag')` | `BeakCustomColumn` | Drawn by a renderer you register |

Two rules sit under the table. The Dart type picks the column, and nullability picks required-ness: `String name` is required, `String? nickname` is not. Everything below is what a field can say beyond that.

A type Beak cannot map (`Uri`, `Map`, a `List` of `DateTime`) is an error from `beak prepare` that names the field. `BeakText`, `BeakRichText`, `BeakHexColor`, `BeakImageRef` and `BeakFileRef` come from `package:beak/schema.dart`. They are extension types over `String`, so they cost nothing at runtime and exist to tell `String` fields apart.

## What @Column adds

A field with no annotation is a valid column with a label made from its name (`weightInGrams` becomes "Weight In Grams"). `@Column` carries what the type cannot say. Its options sort into three groups.

**Where the column shows up and how it behaves in queries**

| Option | Default | Effect |
| --- | --- | --- |
| `visibleOn` | table, form, detail | The surfaces the column appears on. `{}` hides it everywhere while the API still carries it |
| `sortable` | `false` | Table headers may sort by it |
| `searchable` | `false` | The search box includes it |
| `filterable` | `false` | The list derives a filter control from it |
| `indexed` | `false` | The migration adds an index |
| `unique` | `false` | A unique index, and the server refuses a duplicate value |

**How the value is written and labelled**

| Option | Applies to | Effect |
| --- | --- | --- |
| `columnName` | Any | The stored column name. Defaults to the snake-cased field name |
| `label` | Any | Label in tables, forms and detail views |
| `prefix`, `suffix` | `int`, `double`, `BeakDecimal` | Text before or after the number, such as `%` or `kg` |
| `precision`, `totalDigits` | `double` | Fraction digits, and total stored digits (`NUMERIC(totalDigits, precision)`) |
| `format` | `DateTime` | `BeakDateFormat.standard`, `relative`, `dateOnly`, `timeOnly` or `iso` |
| `placeholder` | `String` | Hint text in the empty input |
| `trueLabel`, `falseLabel` | `bool` | The names of the two states |

**What the value has to be**

| Option | Effect |
| --- | --- |
| `rules` | Validation rules, enforced in the form and again in the API, see [Validation](validation.md) |
| `defaultValue` | Used for a new record when the value is left out. An explicit `null` is not replaced. Also the column's default in the migration |
| `semantic` | Domain meaning of the value, see [Semantic fields](semantic-fields.md) |
| `currencyFrom` | The `String` field that holds a money field's currency |

An option on a kind that cannot use it is an error from `beak prepare`, at the field, before anything is written.

The showcase's specimen schema puts one field of every kind in a single class. These four show the options at work:

```dart title="examples/showcase/lib/resources/specimens/models/specimen.dart"
/// Wingspan tip to tip (int column with a unit in its name).
@Column(suffix: 'cm', rules: [BeakMin(1)])
late final int wingspanInCentimeters;

/// Body weight (decimal column).
@Column(suffix: 'g', precision: 1, rules: [BeakMin(0)])
late final double weightInGrams;
```

```dart title="examples/showcase/lib/resources/specimens/models/specimen.dart"
/// Whether the species is on a conservation list (bool column).
@Column(filterable: true, trueLabel: 'Endangered', falseLabel: 'Stable')
late final bool endangered;
```

The unit sits in the field name and again in `suffix:`. The name keeps code honest (nobody adds grams to centimetres by accident), the suffix keeps the table readable.

The shop shows the same options doing quieter work. A date that displays without its time, and a snapshot column that only the detail view shows:

```dart title="examples/clean_beak_config/lib/resources/invoices/models/invoice.dart"
/// Invoice date, including historical invoices.
@Column(format: BeakDateFormat.dateOnly, sortable: true)
late final DateTime issuedAt;
```

```dart title="examples/clean_beak_config/lib/resources/invoices/models/invoice.dart"
/// Snapshot of the billed customer's name.
@Column(visibleOn: {BeakContext.detail})
late final String? customerName;
```

And a SKU that is searchable and unique, so the search box finds it and the database keeps it single:

```dart title="examples/clean_beak_config/lib/resources/products/models/product_variant.dart"
/// Unique stock-keeping identifier.
@Column(searchable: true, unique: true)
late final String sku;
```

Bounds are rules and not options. `maxLength:`, `min:` and `max:` are gone from `@Column`, and `beak prepare` names the rule that replaces each. `BeakMaxLength(120)` on a `String` validates the input and sizes the stored column. `BeakMin(0)` and `BeakMax(30)` on an `int` validate it and bound the form's stepper.

## Enums: labels and badges

An enum field gives you a select in the form and a badge in the table without a line of configuration. The stored value is the enum's name, so what you see and what is stored can differ, and two annotations control what you see:

- `@EnumLabels<T>` maps values to display labels. A value you leave out shows its name.
- `@Badges<T>` maps values to a `BeakColor`: `primary`, `secondary`, `success`, `warning`, `error`, `info` or `muted`. A value you leave out gets the theme's default badge.

Both are generic in the enum, so a key that does not belong to it is a compile error. The showcase's specimens have a diet, because birds also have to eat something:

```dart
/// The bird's diet (enum column with badges).
@Column(defaultValue: Diet.granivore, filterable: true)
@EnumLabels<Diet>({
  Diet.granivore: 'Granivore',
  Diet.frugivore: 'Frugivore',
  Diet.insectivore: 'Insectivore',
  Diet.piscivore: 'Piscivore',
  Diet.nectarivore: 'Nectarivore',
})
@Badges<Diet>({
  Diet.granivore: BeakColor.warning,
  Diet.frugivore: BeakColor.error,
  Diet.insectivore: BeakColor.success,
  Diet.piscivore: BeakColor.info,
  Diet.nectarivore: BeakColor.secondary,
})
late final Diet diet;
```

`beak prepare` copies both maps into the column it writes, and supplies `values: Diet.values` itself:

```dart title="examples/showcase/lib/resources/specimens/models/specimen.beak.dart"
static const BeakEnumColumn<Diet> diet = BeakEnumColumn<Diet>(
  key: 'diet',
  label: 'Diet',
  rules: [BeakRequired()],
  defaultValue: Diet.granivore,
  filterable: true,
```

`defaultValue: Diet.granivore` is an enum value and not a string. It also becomes the column's default in the migration, so the model and the table cannot disagree about it.

Renaming an enum value renames what is stored. A row written under the old name reads as `null` afterwards, and Beak does not throw. Add the new value, migrate the data, then remove the old one.

## Rules and limits

- The type is the discriminator. There is no `kind:` option on `@Column`. A `BeakText` is a text area because of its type.
- Enums must be declared under `lib/`. `beak prepare` collects enum declarations from your source, and an enum imported from a package is reported as an unsupported type.
- `double` is a floating-point number. Its default of `NUMERIC(10, 2)` leaves eight digits before the point, which suits a weight and not a ledger. Money that has to add up is a `BeakDecimal`.
- Lists hold primitives. `List<String>`, `List<int>`, `List<double>` and `List<bool>` are stored as JSON text. A list of schema objects is a relationship, see [Relationships](relationships.md).
- `BeakDate`, `BeakTime`, `Duration` and `BeakDecimal` share a physical column. Raw SQL sees the stored form, such as `2026-09-29` or a count of units, not the Dart type.
- A `@Column` option belongs to one kind. `precision` on a `String` is an error, and so is a semantic on a type it does not accept.
- Renaming a field renames its column. Pin the old name with `columnName:` when the table already exists.
- `@Custom` fields are skipped by generated forms. A custom column needs a registered renderer, see [Custom columns](../extending/custom-columns.md).

## Verify it

Run `beak prepare` and read the column it wrote in the part file, or let it tell you what is wrong. This is real output for a field with an option its kind does not have:

```text
  lib/resources/notes/models/scratch_bad.dart: Widget2.name is a string column, which has no "precision". Decimal places belong on a `double` field.
  lib/resources/notes/models/scratch_bad.dart: Widget2.weight is a decimal column, which has no "trueLabel". State labels belong on a `bool` field.
  lib/resources/notes/models/scratch_bad.dart: Widget2.contact: BeakSemantic.email is incompatible with int. Use its semantic Dart value type.
```

Then `dart analyze`: a `defaultValue` that does not match the field type is only caught there.

## Reference

The mapping from a Dart type to a column is one function, and `beak prepare` uses it:

```dart
static BeakColumnKind? ofType(String typeName) => switch (typeName) {
  'String' || 'BeakDate' || 'BeakTime' => string,
  'BeakText' => text,
  'BeakRichText' => richText,
  'int' || 'Duration' || 'BeakDecimal' => integer,
  'double' => decimal,
  'bool' => boolean,
  'DateTime' => dateTime,
  'BeakJson' || 'BeakJsonObject' => json,
  'BeakHexColor' => color,
  'BeakImageRef' => image,
  'BeakFileRef' => file,
  _ => null,
};
```

| Annotation | Goes on | Declares |
| --- | --- | --- |
| `@Column` | Any field | The options above |
| `@Display` | One field | The label of a record |
| `@EnumLabels<T>`, `@Badges<T>` | An enum field | Display labels, badge colours |
| `@Image`, `@FileField` | `BeakImageRef`, `BeakFileRef` | Storage path and file rules |
| `@Custom(tag)` | `Object?` | A column drawn by a registered renderer |

Every column class with its constructor, every `@Column` parameter with its default and the render intent per surface are in [Field types](../reference/field-types.md) and [Annotations](../reference/annotations.md).

## Continue reading

- [Semantic fields](semantic-fields.md) money, percentages, dates, lists and objects.
- [Validation](validation.md) the rules a field's `rules:` list takes.
- [Relationships](relationships.md) fields that point at another schema.
