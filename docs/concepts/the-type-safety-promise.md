---
title: The type-safety promise
description: Why Beak has no string field references and no dynamic: typed column and relationship consts, sealed families that force exhaustive handling, and BeakValue as a lossless wire type.
---

# The type-safety promise

After this page you will understand the second half of Beak's contract: you never
write a string field reference, and you never touch `dynamic`. Columns and
relationships are typed constants, the sealed families make the compiler check
your work, and filter operands cross the wire as a typed `BeakValue` that does not
lose what it was.

## You hold a column, not a string

When you configure a table, a filter, or a form, you pass the column constant
itself, not its key. The keys exist (a column has a `key: 'price'`), but they are
an internal detail of talking to the database. You work with the typed object.

```dart
/// Display name.
static const name = BeakStringColumn(
  key: 'name',
  label: 'Name',
  searchable: true,
  sortable: true,
  rules: [BeakRequired(), BeakMaxLength(255)],
);
```

`ProductColumns.name` is a `BeakStringColumn`. The analyzer knows its type, your
IDE autocompletes it, and a typo is a compile error instead of an empty column at
runtime. There is no `columns['naem']` to get wrong.

Relationships are typed constants for the same reason:

```dart
/// The category a product is filed under.
static const category = BeakBelongsTo(
  key: 'category',
  label: 'Category',
  relatedTable: 'categories',
  displayColumnKey: 'name',
  foreignKey: 'category_id',
  searchColumnKeys: ['name'],
);
```

`BeakBelongsTo`, `BeakHasOne`, `BeakHasMany`, and `BeakBelongsToMany` are members
of one sealed `BeakRelationship` family. You point a `BeakBelongsToField` at
`ProductRelations.category` and the panel knows the cardinality, the related
table, and which column to show, all from the type.

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

## What this buys you

Put together, the promise is a short list of things you will not find in Beak
code, and a shorter list of what you use instead:

| You will not write | You write instead |
| ------------------ | ----------------- |
| `record['price']` | `ProductColumns.price` |
| `dynamic value` | a typed `BeakValue` or the column's value type |
| `value as int` | a `switch` over the sealed family |
| `Map<String, dynamic>` as an API type | a `BeakRecord` or a typed DTO |
| a stringly-typed status | a `BeakEnumColumn<ProductStatus>` over your enum |

The payoff is that renaming a field, adding an enum case, or introducing a new
column variant surfaces as a compile error at the exact call site that needs
attention, not as a runtime `null` a user reports next week.

## Continue reading

- [The one-definition promise](the-one-definition-promise.md) the same typed column, feeding six surfaces.
- [Results and errors](results-and-errors.md) the sealed `BeakResult` and `BeakException` families.
- [How data flows](how-data-flows.md) `BeakValue` inside the serializable query spec.
- [Relationships](../models/relationships.md) the sealed `BeakRelationship` family in full.
