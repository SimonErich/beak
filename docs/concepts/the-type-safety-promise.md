---
title: The type-safety promise
description: Why Beak has no string field references and no dynamic: generated column and relationship consts, sealed families that force exhaustive handling, and BeakValue as a lossless wire type.
---

# The type-safety promise

After this page you will understand the second half of Beak's contract: you never
write a string field reference, and you never touch `dynamic`. Columns and
relationships arrive as generated typed constants, the sealed families make the
compiler check your work, and filter operands cross the wire as a typed
`BeakValue` that does not lose what it was.

## You hold a column, not a string

You declare a field. `beak prepare` writes the constant. From then on you pass
the constant itself, never its key.

```dart title="examples/store/lib/models/category.dart"
/// What the category is called.
@Display()
@Column(searchable: true, sortable: true, rules: [BeakMaxLength(120)])
late final String name;
```

becomes, in the part file beside it:

```dart title="examples/store/lib/models/category.beak.dart"
/// What the category is called.
static const BeakStringColumn name = BeakStringColumn(
  key: 'name',
  label: 'Name',
  rules: [BeakRequired(), BeakMaxLength(120)],
  searchable: true,
  sortable: true,
);
```

The key exists, and the database needs it, but it is an artifact of generation
rather than something you type. `CategoryColumns.name` is a `BeakStringColumn`.
The analyzer knows its type, your IDE autocompletes it, and a typo is a compile
error instead of an empty column at runtime. There is no `columns['naem']` to
get wrong, and no second place the string `'name'` is written down.

Relationships work the same way. You name the other class:

```dart title="examples/store/lib/models/product.dart"
/// The category this product is filed under.
@BelongsTo(onDelete: BeakOnDelete.setNull)
late final Category? category;
```

and get a typed constant with the foreign key, the related table and the display
column filled in:

```dart title="examples/store/lib/models/product.beak.dart"
/// The category this product is filed under.
static const BeakBelongsTo category = BeakBelongsTo(
  key: 'category',
  label: 'Category',
  relatedTable: 'categories',
  displayColumnKey: 'name',
  foreignKey: 'category_id',
  searchColumnKeys: ['name'],
  onDelete: BeakOnDelete.setNull,
);
```

`BeakBelongsTo`, `BeakHasOne`, `BeakHasMany`, and `BeakBelongsToMany` are members
of one sealed `BeakRelationship` family. You point a `BeakBelongsToField` at
`ProductRelations.category` and the panel knows the cardinality, the related
table, and which column to show, all from the type. The matching
`CategoryRelations.products` is generated on the other side from the same
annotation, so the pair cannot drift.

## The one key a schema names is checked

There is exactly one place a schema class refers to another table's column by
key: `searchOn:`, which widens what a relationship picker looks through. The
store has no need for it, so this one comes from `examples/superdashboard`,
where an order's customer is looked up by name or by email:

```dart title="examples/superdashboard/lib/models/commerce/order.dart"
/// The customer who placed the order.
@BelongsTo(label: 'Customer', searchOn: ['name', 'email'])
late final User? user;
```

Because it is a string, it is checked. `beak prepare` reads the related schema,
collects its column keys, and refuses to generate when one does not match:

```dart title="packages/beak_cli/lib/src/schema/beak_schema_reader.dart"
// `searchOn` is the one place a schema class names a column of
// another table by key. Checking it here is what keeps that from
// being a string that can be quietly wrong.
final Set<String> keys = {
  for (final column in related.columns) column.columnKey,
};
for (final key in relation.searchOn) {
  if (keys.contains(key)) {
    continue;
  }
  issues.add(
    BeakDiscoveryIssue(
      path: 'lib/${schema.libraryPath}',
      message:
          '${schema.className}.${relation.fieldName} searches '
          '"$key", which ${related.className} has no column for. '
          'Its columns are: ${(keys.toList()..sort()).join(', ')}.',
    ),
  );
}
```

Write `searchOn: ['naem']` and `beak prepare` refuses to generate anything. It
prints a `Cannot generate` header and one line per problem, naming the field,
the bad key, and every key the other schema does have. A misspelled key is a
build failure, not a picker that silently finds nothing.

## Sealed families force exhaustive handling

The most-used vocabulary in Beak is sealed: `BeakColumn`, `BeakValue`,
`BeakFilter`, `BeakResult`, and `BeakException` all have a fixed, closed set of
subtypes. Sealed types are worth the ceremony because Dart's `switch` becomes
exhaustive over them: add a variant and every unhandled `switch` stops compiling
until you deal with the new case. The compiler keeps the audit for you.

You can see the pattern in `BeakValue.of`, which turns plain Dart into a typed
operand by matching on the runtime value and never falling back to `dynamic`:

```dart title="packages/beak_core/lib/src/query/beak_value.dart"
static BeakValue of(Object? raw) => switch (raw) {
  null => const BeakNullValue(),
  final BeakValue value => value,
  final bool value => BeakBoolValue(value),
  final int value => BeakIntValue(value),
  final double value => BeakDoubleValue(value),
  final String value => BeakStringValue(value),
  final DateTime value => BeakDateTimeValue(value),
  final List<Object?> values => BeakListValue([
    for (final value in values) BeakValue.of(value),
  ]),
  _ => throw BeakConfigurationException(
    'BeakValue does not support ${raw.runtimeType} values (got $raw).',
  ),
};
```

An unsupported type does not slip through as `dynamic`. It hits the `_` arm and
throws a typed `BeakConfigurationException`, so the failure is loud and specific
instead of a silent `null` three layers later.

## BeakValue is a lossless wire type

A filter's operand has to travel from the panel to the server as JSON and come
back meaning the same thing. Plain JSON cannot tell a timestamp from a string:
both are text. `BeakValue` solves this by being the single type every operand
wears on the wire, with one tagged encoding for the case JSON would otherwise
mangle.

```dart title="packages/beak_core/lib/src/query/beak_value.dart"
/// A typed wrapper around a filter comparison operand, so query specs
/// serialize losslessly without ever exposing `dynamic`.
///
/// Wire encoding: [BeakNullValue], [BeakBoolValue], [BeakIntValue],
/// [BeakDoubleValue], and [BeakStringValue] serialize as the raw JSON
/// primitive; [BeakListValue] as a JSON array; [BeakDateTimeValue] as a
/// tagged object `{"type": "dateTime", "value": <ISO-8601>}` so decoding
/// never confuses timestamps with plain strings.
@immutable
sealed class BeakValue {
  const BeakValue();
```

Primitives ride as themselves. A `DateTime` rides tagged, so the decoder can
reconstruct a real `DateTime` and not a lookalike string:

```dart title="packages/beak_core/lib/src/query/beak_value.dart"
@override
Object? toJson() => {'type': 'dateTime', 'value': value.toIso8601String()};
```

The result is that `BeakValue.of(x).toJson()` and `BeakValue.fromJson(...)`
round-trip a filter operand across HTTP without a single `as` cast or a stray
`Map<String, dynamic>` at either end.

!!! note "Where the operands live"
    `BeakValue` is the leaf of the query wire format. Filters, sorts, search, and
    pagination all sit in a `BeakQuerySpec` that serializes the same way. See
    [How data flows](how-data-flows.md) for the whole spec.

## Reading a row keeps its types too

`beak prepare` also writes an extension type per resource, so reading a record
gives you the Dart type you declared rather than an `Object?` to pattern-match:

```dart title="examples/store/lib/models/category.beak.dart"
/// What the category is called.
String get name => CategoryColumns.name.require(record);

/// The one-line blurb shown above the product list.
String? get blurb => CategoryColumns.blurb.readFrom(record);
```

A required field reads as `String`, a nullable one as `String?`, and the
nullability matches the schema class because both came from it. Reach for a row
with `record.asCategory` and the getters are there.

## What this buys you

Put together, the promise is a short list of things you will not find in Beak
code, and a shorter list of what you use instead:

| You will not write | You write instead |
| ------------------ | ----------------- |
| `record['price']` | `ProductColumns.price`, or `record.asProduct.price` |
| `dynamic value` | a typed `BeakValue` or the column's value type |
| `value as int` | a `switch` over the sealed family |
| `Map<String, dynamic>` as an API type | a `BeakRecord` or a typed DTO |
| a stringly-typed status | an enum field, which becomes a `BeakEnumColumn<ProductStatus>` |
| `'price'` in a migration, a form and a table | one field on the schema class |

The payoff is that renaming a field, adding an enum case, or introducing a new
column variant surfaces as a compile error at the exact call site that needs
attention, not as a runtime `null` a user reports next week.

## Continue reading

- [The one-definition promise](the-one-definition-promise.md) the same declaration, feeding six surfaces plus the migration.
- [Results and errors](results-and-errors.md) the sealed `BeakResult` and `BeakException` families.
- [How data flows](how-data-flows.md) `BeakValue` inside the serializable query spec.
- [Relationships](../models/relationships.md) the four kinds, and the constants they generate.
- [Generated code](../models/generated-code.md) every symbol `beak prepare` writes.
