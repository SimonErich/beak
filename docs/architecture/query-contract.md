---
title: The query contract
description: How BeakQuerySpec, BeakFilter, and BeakValue serialize losslessly and become a worm query on the backend.
---

# The query contract

After this page you can read a `BeakQuerySpec` on the wire, explain why timestamps travel tagged while everything else travels raw, and follow one filter from a typed column constant all the way to a worm predicate tree.

Beak's two halves never share a process. The panel runs in Flutter, the server runs on Shelf, and the only thing that crosses between them is JSON. `BeakQuerySpec` is that JSON: a typed, fully serializable description of a query that the frontend builds from column constants and the backend rebuilds losslessly before handing it to the ORM. No string field references, no `Map<String, dynamic>`, no ORM types on the wire.

The pieces all live in `packages/beak_core/lib/src/query/`; the translation to worm lives in `packages/beak_backend/lib/src/data/worm/query_translator.dart`.

## What a spec carries

A spec is an immutable value with seven fields.

| Field | Type | Meaning |
| --- | --- | --- |
| `table` | `String` | Physical table/collection name of the queried model. |
| `filter` | `BeakFilter?` | The predicate records must satisfy, if any. |
| `sorts` | `List<BeakSort>` | Ordering directives, applied in order. |
| `search` | `BeakSearch?` | The full-text search directive, if any. |
| `relationLoads` | `List<BeakRelationLoad>` | Relations to eager-load with the results (Beak never lazy-loads). |
| `pagination` | `BeakPagination` | The paging window (1-based `page`, `perPage`, defaults `1`/`25`). |
| `withTrashed` | `bool` | Whether soft-deleted records are included. |

The spec references column and relation *keys* only, which is what keeps it ORM-neutral. It knows a column is called `status`; it does not know or care whether `status` is a Postgres `text` column or a Serverpod field.

## Building a spec

You never set those fields by hand. The frontend composes a spec through immutable copy-builders that read their keys from typed column and relationship constants. Each builder returns a new spec, so they chain and the original is never mutated.

```dart title="packages/beak_core/lib/src/query/beak_query_spec.dart"
final spec = const BeakQuerySpec(table: 'posts')
    .withRelation(author)
    .withFilter(BeakFieldFilter(
      column: status,
      operator: BeakOperator.eq,
      value: BeakValue.of('published'),
    ))
    .orderBy(createdAt, descending: true)
    .paginate(page: 2, perPage: 50);
```

One builder is worth calling out. `withFilter` does not nest: the first filter is taken as-is, and each later one joins an ever-growing conjunction instead of wrapping the previous tree one level deeper.

```dart title="packages/beak_core/lib/src/query/beak_query_spec.dart"
BeakQuerySpec withFilter(BeakFilter filter) => _copy(
  filter: switch (this.filter) {
    null => filter,
    final BeakAndFilter existing => BeakAndFilter([
      ...existing.filters,
      filter,
    ]),
    final BeakFilter existing => BeakAndFilter([existing, filter]),
  },
);
```

So a table with a status filter and a date filter and a search box produces one flat `BeakAndFilter`, not a right-leaning stack of them.

## The round-trip

`toJson()` writes every key, always, and `fromJson` requires every key and throws `BeakConfigurationException` on anything malformed. That strictness is deliberate: a spec that decodes at all decodes to exactly what was sent. Here is the concept spec Beak's own golden test builds:

```dart title="packages/beak_core/test/src/query/beak_query_spec_test.dart"
BeakQuerySpec richSpec() => const BeakQuerySpec(table: 'posts')
    .withRelation(author)
    .withFilter(
      BeakFieldFilter(
        column: status,
        operator: BeakOperator.eq,
        value: BeakValue.of('active'),
      ),
    )
    .withFilter(
      BeakFieldFilter(
        column: lastActive,
        operator: BeakOperator.lt,
        value: BeakValue.of(cutoff),
      ),
    )
    .orderBy(createdAt, descending: true)
    .searching('ada', const [name, email])
    .paginate(page: 2, perPage: 50);
```

That spec serializes byte-for-byte to the pinned golden file. This is the actual wire body of a `POST /api/posts/query`:

```json title="packages/beak_core/test/golden/rich_query_spec.json"
{
  "table": "posts",
  "filter": {
    "type": "and",
    "filters": [
      {
        "type": "field",
        "column": "status",
        "operator": "eq",
        "value": "active"
      },
      {
        "type": "field",
        "column": "last_active",
        "operator": "lt",
        "value": {
          "type": "dateTime",
          "value": "2026-06-01T00:00:00.000Z"
        }
      }
    ]
  },
  "sorts": [
    {
      "column": "created_at",
      "descending": true
    }
  ],
  "search": {
    "term": "ada",
    "columns": [
      "name",
      "email"
    ]
  },
  "relations": [
    {
      "relation": "author",
      "filter": null,
      "nested": []
    }
  ],
  "pagination": {
    "page": 2,
    "perPage": 50
  },
  "withTrashed": false
}
```

!!! note "Reading the round-trip"
    The two `withFilter` calls collapsed into a single `type: "and"` node with two children. The string operand serialized as a bare JSON string, but the `DateTime` operand serialized as a tagged object. That tag is the whole trick of the value layer, and it is next.

## The value layer: `BeakValue`

Filter operands are the one place a query could smuggle in `dynamic`. Beak closes that door with `BeakValue`, a sealed wrapper so every operand has a known type on both sides. `BeakValue.of` wraps plain Dart into the matching variant; anything it does not understand throws rather than serializing as an untyped blob.

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

The wire encoding is what makes the round-trip lossless. Primitives serialize as raw JSON, so they read naturally; a `DateTime` serializes as a tagged object so decoding never has to guess whether a string is text or a timestamp.

| Variant | `raw` Dart type | Wire JSON |
| --- | --- | --- |
| `BeakStringValue` | `String` | the string |
| `BeakIntValue` | `int` | the number |
| `BeakDoubleValue` | `double` | the number |
| `BeakBoolValue` | `bool` | the boolean |
| `BeakDateTimeValue` | `DateTime` | `{"type": "dateTime", "value": "<ISO-8601>"}` |
| `BeakNullValue` | `null` | `null` |
| `BeakListValue` | `List` | a JSON array (recursive) |

`fromJson` reads that table backwards: a bare string decodes to `BeakStringValue`, a map shaped `{"type": "dateTime", ...}` decodes to `BeakDateTimeValue`, and a list decodes element by element. The `dateTime` tag is the only map-shaped value, which keeps the tag namespace open for future typed operands without ambiguity.

Note the difference between `raw` and `toJson`: `raw` unwraps a `BeakDateTimeValue` back to a real `DateTime`, while `toJson` produces the tagged object. The translator reads `raw` (it wants the value); the wire uses `toJson` (it wants the tag).

## The filter tree: `BeakFilter`

Predicates form a sealed tree with three shapes: a leaf comparison and two combinators.

```dart title="packages/beak_core/lib/src/query/beak_filter.dart"
sealed class BeakFilter {
  const BeakFilter();
  // ...
  Map<String, Object?> toJson();
}

final class BeakFieldFilter extends BeakFilter { /* column, operator, value */ }
final class BeakAndFilter extends BeakFilter { /* filters */ }
final class BeakOrFilter extends BeakFilter { /* filters */ }
```

Each node tags itself with a `type` discriminator (`field`, `and`, `or`) on the wire, and `fromJson` switches on it:

```dart title="packages/beak_core/lib/src/query/beak_filter.dart"
static BeakFilter fromJson(Map<String, Object?> json) => switch (json) {
  {'type': 'field'} => _fieldFromJson(json),
  {'type': 'and'} => BeakAndFilter(_childrenFromJson(json, 'BeakAndFilter')),
  {'type': 'or'} => BeakOrFilter(_childrenFromJson(json, 'BeakOrFilter')),
  _ => throw BeakConfigurationException('Malformed BeakFilter JSON: $json.'),
};
```

`BeakFieldFilter` has two constructors, and the split matters. The default constructor takes a `BeakColumn` and reads `columnKey` from it, so user code never types a key string. The `.forKey` constructor takes a raw string and exists for one caller only: `fromJson`, rebuilding a filter it decoded off the wire.

```dart title="packages/beak_core/lib/src/query/beak_filter.dart"
BeakFieldFilter({
  required BeakColumn column,
  required this.operator,
  this.value = const BeakNullValue(),
}) : columnKey = column.key;

const BeakFieldFilter.forKey(
  this.columnKey,
  this.operator, [
  this.value = const BeakNullValue(),
]);
```

Because the tree is sealed, a translator that walks it must handle every node or the build breaks. That is the property the backend leans on next.

## The operator set: `BeakOperator`

Operators are Beak's own ORM-neutral vocabulary, serialized by `name`. Most map one-to-one onto worm, and the three substring operators, which worm has no direct counterpart for, translate to `ilike` with a wildcard pattern built from the operand.

| `BeakOperator` | worm translation |
| --- | --- |
| `eq`, `neq`, `gt`, `gte`, `lt`, `lte` | the same comparison operator |
| `like`, `ilike` | `Operator.like` / `Operator.ilike` (raw pattern) |
| `contains` | `Operator.ilike` with pattern `%value%` |
| `startsWith` | `Operator.ilike` with pattern `value%` |
| `endsWith` | `Operator.ilike` with pattern `%value` |
| `isNull`, `isNotNull` | `Operator.isNull` / `Operator.isNotNull` (operand-less) |
| `inList`, `notInList` | list membership |
| `between`, `notBetween` | inclusive range (exactly two bounds) |

A test pins this table exhaustively, so adding an operator without teaching the translator about it fails the build.

## From spec to SQL: `WormQueryTranslator`

On the server, `WormQueryTranslator` turns a decoded spec into a worm `QueryBuilder`. It is the engine behind `WormDataSource`, and it is fully generic: it works off `BeakModel` metadata and the registry alone, so one code path serves every registered model. No per-model translation code exists anywhere.

```dart title="packages/beak_backend/lib/src/data/worm/query_translator.dart"
QueryBuilder<WormRecordModel> builderFor(
  BeakQuerySpec spec,
  DatabaseAdapter adapter,
) {
  final model = registry.byTableOrThrow(spec.table);
  var builder = QueryBuilder<WormRecordModel>.from(
    contextFor(model, adapter),
  );
  if (spec.withTrashed) {
    builder = builder.withTrashed();
  }
  final PredicateTree? filter = predicateFor(spec.filter, model);
  if (filter != null) {
    builder = builder.where(filter);
  }
  final PredicateTree? search = _searchPredicate(spec.search, model);
  if (search != null) {
    builder = builder.where(search);
  }
  for (final sort in spec.sorts) {
    builder = builder.orderBy(
      wormFieldForColumn(columnOrThrow(model, sort.columnKey)),
      descending: sort.descending,
    );
  }
  builder = _applyRelationLoads(builder, model, spec.relationLoads);
  builder = builder.limit(spec.pagination.perPage);
  final int offsetRows = (spec.pagination.page - 1) * spec.pagination.perPage;
  if (offsetRows > 0) {
    builder = builder.offset(offsetRows);
  }
  return builder;
}
```

Filters translate through an exhaustive switch over the sealed tree. An unknown column key, or an operand an operator cannot use, throws `BeakConfigurationException` (which the error middleware maps to `422`, not `500`).

```dart title="packages/beak_backend/lib/src/data/worm/query_translator.dart"
PredicateTree? predicateFor(BeakFilter? filter, BeakModel model) =>
    switch (filter) {
      null => null,
      final BeakFieldFilter field => _leafFor(field, model),
      final BeakAndFilter and => _composite(and.filters, model, isAnd: true),
      final BeakOrFilter or => _composite(or.filters, model, isAnd: false),
    };
```

The leaf translation is where the operator table becomes code. Note the substring operators building their `ilike` patterns from the operand:

```dart title="packages/beak_backend/lib/src/data/worm/query_translator.dart"
BeakOperator.contains => predicate(
  Operator.ilike,
  '%${_stringOperand(filter)}%',
),
BeakOperator.startsWith => predicate(
  Operator.ilike,
  '${_stringOperand(filter)}%',
),
BeakOperator.endsWith => predicate(
  Operator.ilike,
  '%${_stringOperand(filter)}',
),
```

Relation loads become batched eager-load paths, a search becomes a grouped OR of case-insensitive matches over the searchable columns, and a soft-deleting model is scoped with worm's `SoftDeleteScope` unless `withTrashed` lifts it. The result is a builder the data source runs with `count()` for the total and `get()` for the page.

## Why the contract looks like this

Three properties fall out of the design, and each one is an invariant the rest of Beak depends on.

- **Lossless.** Every `toJson` writes all keys and every `fromJson` requires them, and the `dateTime` tag removes the one genuine ambiguity. A spec that survives the wire is the spec you sent.
- **No `dynamic`, ever.** `BeakValue` is the escape hatch that is not one: operands are typed on both sides, so a filter cannot smuggle an untyped value past the type system.
- **ORM-neutral.** The spec speaks column keys, not database columns. `WormQueryTranslator` is the only code that knows about worm, so a future `ServerpodDataSource` would ship its own translator and touch nothing here.

## Continue reading

- [How data flows](../concepts/how-data-flows.md) the same contract, told from the panel's point of view.
- [The data source seam](data-source-seam.md) the interface that consumes a spec on either side.
- [The generated API](../backend/the-generated-api.md) the routes a spec is posted to.
- [Performance](../guides/performance.md) eager loading, pagination, and query counts in practice.
