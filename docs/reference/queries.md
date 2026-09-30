---
title: Queries
description: Look up BeakQuerySpec, filters, operators, typed values, sorts, search, aggregates, summaries and the limits the API enforces.
type: reference
audience: [expert, agent]
status: stable
search: {boost: 2}
---

# Queries

A query is a `BeakQuerySpec`: a typed value the panel builds from generated field references and ships as JSON, and the server rebuilds before it reaches the database. This page lists every type that takes part, its fields and defaults, the JSON it produces and what the server rejects.

## Import

```dart
import 'package:beak/beak.dart';
```

`package:beak/beak.dart` re-exports `package:beak_core/beak_core.dart`, which is the import for a package that depends on `beak_core` alone. Nothing on this page needs Flutter or `dart:io`.

## Summary

| Type | Role | Wire shape | Built from |
| --- | --- | --- | --- |
| `BeakQuerySpec` | One query: filter, sorts, search, relation loads, page window | `POST /api/{table}/query` body | `model.query(...)` |
| `BeakFilter` | Predicate tree: `BeakFieldFilter`, `BeakAndFilter`, `BeakOrFilter`, `BeakRelationFilter` | `{"type": "field" \| "and" \| "or" \| "relation", ...}` | Typed predicates on field references |
| `BeakOperator` | The 17 comparison operators | Operator name as a string | Typed predicates, or `BeakFieldFilter` |
| `BeakValue` | Typed operand: null, bool, int, double, string, timestamp, list | Raw JSON primitive, array, or a tagged timestamp | `BeakValue.of(...)`, or a field's `encode` |
| `BeakSort` | One ordering directive | `{"column": ..., "descending": ...}` | `field.ascending()`, `field.descending()` |
| `BeakSearch` | Term matched against columns | `{"term": ..., "columns": [...]}` | `spec.searching(...)` |
| `BeakRelationLoad` | Eager-load directive, optionally filtered and nested | `{"relation": ..., "filter": ..., "nested": [...]}` | `spec.withRelation(...)` |
| `BeakPagination` | 1-based page and page size | `{"page": ..., "perPage": ...}` | `spec.paginate(...)` |
| `BeakPage<T>` | Response envelope: items, total, page, perPage | `{"items": [...], "total": ..., ...}` | Returned by `BeakDataSource.query` |
| `BeakRecord` | One row: typed values plus eager-loaded relations | `{"values": {...}, "relations": {...}}` | Returned inside a page |
| `BeakAggregateSpec` | One number: count, sum or avg | `POST /api/{table}/aggregate` body | `model.count`, `model.sum`, `model.avg` |
| `BeakSummarySpec` | Grouped measures over the whole matching population | `POST /api/{table}/summary` body | `model.summary(...)` |
| `BeakOptionQuery` | Picker source: a model plus a spec, no I/O | Not serialized | `field.options(...)`, `XModel.options(...)` |
| `BeakTableRef` | Typed handle for a table name | The table name string | `model.ref` |

Application code never writes a table name, a column key or a relation key. Every entry point starts from a model (`const ProductModel()`) and uses its generated field references (`ProductModel.price`). The constructors that take raw keys (`BeakQuerySpec(table: ...)`, `BeakFieldFilter.forKey`, `BeakSort(...)`) are the decoder path.

## Building a spec

`BeakModel.query` mirrors the constructor of `BeakQuerySpec` and fills in the table.

```dart title="packages/beak_core/lib/src/model/beak_model.dart"
BeakQuerySpec query({
  BeakFilter? filter,
  List<BeakSort> sorts = const [],
  BeakSearch? search,
  List<BeakRelationLoad> relationLoads = const [],
  BeakPagination pagination = const BeakPagination(),
  bool withTrashed = false,
}) => BeakQuerySpec(
  // ...
);
```

A spec is immutable. Five copy-builders return a new spec and can be chained.

| Builder | Effect | Throws |
| --- | --- | --- |
| `withFilter(BeakFilter filter)` | AND-merges `filter` into the existing predicate. The first filter is taken as-is, later ones join one `BeakAndFilter` | Never |
| `orderBy(BeakScalarField<Object> field, {bool descending = false})` | Appends a sort | `BeakConfigurationException` for a field reached through a relationship |
| `withRelation(BeakRelationship relation, {BeakFilter? constraint})` | Appends an eager load of `relation`, optionally constrained | Never |
| `searching(String term, List<BeakScalarField<Object>> fields)` | Replaces the search. Fields may be reached through relationships | Never |
| `paginate({int? page, int? perPage})` | Replaces either half of the paging window; an omitted half keeps its value | `AssertionError` in debug builds for a value below 1 |

The copy-builders only add or replace. There is no builder that removes a filter or a sort, and none that sets `withTrashed`; pass those to `model.query` (or to the constructor) when the spec is created. The chain in the next section uses four of them.

## BeakQuerySpec

```dart title="packages/beak_core/lib/src/query/beak_query_spec.dart"
const BeakQuerySpec({
  required this.table,
  this.filter,
  this.sorts = const [],
  this.search,
  this.relationLoads = const [],
  this.pagination = const BeakPagination(),
  this.withTrashed = false,
});
```

| Field | Type | Default | JSON key | Meaning |
| --- | --- | --- | --- | --- |
| `table` | `String` | required | `table` | Stored table name of the queried model. Must equal the route's table |
| `filter` | `BeakFilter?` | `null` | `filter` | Predicate every returned record satisfies |
| `sorts` | `List<BeakSort>` | `[]` | `sorts` | Ordering directives, applied in order |
| `search` | `BeakSearch?` | `null` | `search` | Full-text directive, ANDed with `filter` |
| `relationLoads` | `List<BeakRelationLoad>` | `[]` | `relations` | Relations to eager-load with each record |
| `pagination` | `BeakPagination` | `BeakPagination()` | `pagination` | Page window, default page 1 of 25 |
| `withTrashed` | `bool` | `false` | `withTrashed` | Include soft-deleted rows. Only models with `softDeletes` are affected |

`toJson()` writes every key. `BeakQuerySpec.fromJson` needs only `table`; every other key falls back to the default in the table, so `{"table": "book"}` is a valid request body. A key that is present must have the right type, and the objects inside `sorts`, `relations`, `search` and `pagination` take their own defaults for what they omit (see [Required keys](#required-keys)).

Real output of `toJson()` for a spec built against the `Book` and `Author` models of `examples/serverpod`:

```dart
final spec = const BookModel()
    .query(
      filter: BeakFilter.allOf([
        BookModel.format.eq(BookFormat.hardcover),
        BookModel.priceInCents.lte(2000),
        BookModel.author.matches(AuthorModel.name.contains('Ada')),
      ]),
    )
    .withRelation(BookModel.author.relation)
    .orderBy(BookModel.title)
    .searching('dune', [BookModel.title, BookModel.author.name])
    .paginate(page: 2, perPage: 50);
```

```json
{
  "table": "book",
  "filter": {
    "type": "and",
    "filters": [
      { "type": "field", "column": "format", "operator": "eq", "value": "hardcover" },
      { "type": "field", "column": "priceInCents", "operator": "lte", "value": 2000 },
      {
        "type": "relation",
        "relation": "author",
        "filter": { "type": "field", "column": "name", "operator": "contains", "value": "Ada" }
      }
    ]
  },
  "sorts": [{ "column": "title", "descending": false }],
  "search": { "term": "dune", "columns": ["title", "author.name"] },
  "relations": [{ "relation": "author", "filter": null, "nested": [] }],
  "pagination": { "page": 2, "perPage": 50 },
  "withTrashed": false
}
```

The first snippet is illustrative (it uses the generated `BookModel`); the JSON is what `toJson()` printed for it, reformatted for width.

## Filters

`BeakFilter` is a sealed class. A translator switches over its four subclasses exhaustively.

| Node | Constructor | JSON `type` | Other JSON keys | Matches |
| --- | --- | --- | --- | --- |
| `BeakFieldFilter` | `BeakFieldFilter({column, operator, value})`, `BeakFieldFilter.forKey(columnKey, operator, [value])` | `field` | `column`, `operator`, `value` | Records whose column satisfies `operator` against `value` |
| `BeakAndFilter` | `BeakAndFilter(List<BeakFilter> filters)` | `and` | `filters` | Records satisfying every child |
| `BeakOrFilter` | `BeakOrFilter(List<BeakFilter> filters)` | `or` | `filters` | Records satisfying at least one child |
| `BeakRelationFilter` | `BeakRelationFilter(String relationKey, BeakFilter filter)` | `relation` | `relation`, `filter` | Owners with at least one related record satisfying the whole inner filter |

```dart title="packages/beak_core/lib/src/query/beak_filter.dart"
const BeakFieldFilter({
  required BeakColumn column,
  required this.operator,
  this.value = const BeakNullValue(),
}) : _column = column,
     _columnKey = null;
const BeakFieldFilter.forKey(
  String columnKey,
  this.operator, [
  this.value = const BeakNullValue(),
]) : _columnKey = columnKey,
     _column = null;
```

`BeakFilter.allOf` is the one way a list of filters becomes one predicate: `null` for an empty list, the single element for a list of one, otherwise a `BeakAndFilter`.

```dart title="packages/beak_core/lib/src/query/beak_filter.dart"
static BeakFilter? allOf(List<BeakFilter> filters) =>
    switch (filters.length) {
      0 => null,
      1 => filters.single,
      _ => BeakAndFilter(filters),
    };
```

### Column keys with dots

A `BeakFieldFilter` on a field reached through a relationship carries a dotted key, for example `author.name`. The server expands each such condition into its own related-record test. Two dotted conditions on the same to-many path can therefore be satisfied by different related records. `BeakRelationFilter` (built by `matches` and `any`, below) keeps the conditions together on one related record, and is the form to use for a to-many path.

### Typed predicates

Predicates are methods on the generated field references. Each returns a `BeakFilter` and encodes its operand through the field's column, so an enum travels as its name, an exact decimal as integer units and a calendar date as an ISO string.

| Available on | Method | Operator | Notes |
| --- | --- | --- | --- |
| `BeakScalarField<T>` | `eq(T? value)` | `eq`, or `isNull` for `null` | |
| `BeakScalarField<T>` | `notEq(T? value)` | `neq`, or `isNotNull` for `null` | |
| `BeakScalarField<T extends num>` | `gt`, `gte`, `lt`, `lte` | `gt`, `gte`, `lt`, `lte` | `int` and `double` fields |
| `BeakScalarField<T extends Comparable<T>>` | `gt`, `gte`, `lt`, `lte` | `gt`, `gte`, `lt`, `lte` | `BeakDecimal`, `BeakDate`, `BeakTime`, `Duration`, `DateTime`, `String` fields |
| `BeakScalarField<String>` | `contains(String value)` | `contains` | Case-insensitive substring |
| `BeakToOneField` | `eq(BeakRecord? record)` | `eq` or `isNull` on the foreign key | Belongs-to only |
| `BeakToOneField` | `equalsId(Object? id)` | `eq` or `isNull` on the foreign key | Belongs-to only; no loaded record needed |
| `BeakToOneField` | `matches(BeakFilter filter)` | Wraps `filter` in a `BeakRelationFilter` | Build `filter` from the target model's fields |
| `BeakToManyField` | `any(BeakFilter filter)` | Wraps `filter` in a `BeakRelationFilter` | One related record satisfies the whole `filter` |

```dart title="packages/beak_core/lib/src/model/beak_field_ref.dart"
extension BeakNumericFieldPredicates<T extends num> on BeakScalarField<T> {
  BeakFilter gt(T value) => _compare(BeakOperator.gt, value);
  BeakFilter gte(T value) => _compare(BeakOperator.gte, value);
  BeakFilter lt(T value) => _compare(BeakOperator.lt, value);
  BeakFilter lte(T value) => _compare(BeakOperator.lte, value);
}
```

`bool` and enum fields have `eq` and `notEq` only. The operators without a method (`like`, `ilike`, `startsWith`, `endsWith`, `inList`, `notInList`, `between`, `notBetween`) are written with the column constant that `beak prepare` generates next to the model:

```dart
BeakFieldFilter(
  column: BookColumns.priceInCents,
  operator: BeakOperator.between,
  value: BeakValue.of([1000, 2000]),
)
```

That snippet is illustrative. `BookColumns.priceInCents` is the generated column constant.

### Operators

`BeakOperator` values serialize by name. The server translates each to a worm operator; the three substring operators have no worm counterpart and become `ilike` with a wildcard pattern built from the escaped operand.

| Operator | SQL meaning | Operand | Server translation |
| --- | --- | --- | --- |
| `eq` | `=` | One value that fits the column | `Operator.eq` |
| `neq` | `!=` | One value that fits the column | `Operator.neq` |
| `gt` | `>` | One value that fits the column | `Operator.gt` |
| `gte` | `>=` | One value that fits the column | `Operator.gte` |
| `lt` | `<` | One value that fits the column | `Operator.lt` |
| `lte` | `<=` | One value that fits the column | `Operator.lte` |
| `like` | `LIKE`, case-sensitive | String pattern, text column | `Operator.like` |
| `ilike` | `LIKE`, case-insensitive | String pattern, text column | `Operator.ilike` |
| `contains` | Substring, ignoring case | String, text column | `Operator.ilike` with `%value%`, `value` escaped |
| `startsWith` | Prefix, ignoring case | String, text column | `Operator.ilike` with `value%`, `value` escaped |
| `endsWith` | Suffix, ignoring case | String, text column | `Operator.ilike` with `%value`, `value` escaped |
| `isNull` | `IS NULL` | None (`BeakNullValue`) | `Operator.isNull` |
| `isNotNull` | `IS NOT NULL` | None (`BeakNullValue`) | `Operator.isNotNull` |
| `inList` | `IN (...)` | `BeakListValue` of values that fit the column | `Operator.inList` |
| `notInList` | `NOT IN (...)` | `BeakListValue` of values that fit the column | `Operator.notInList` |
| `between` | `BETWEEN`, inclusive | `BeakListValue` of exactly two values that fit the column | `Operator.between` |
| `notBetween` | `NOT BETWEEN`, inclusive | `BeakListValue` of exactly two values that fit the column | `Operator.notBetween` |

`ilike` compiles to `ILIKE` on Postgres and to `LIKE` on SQLite (`packages/worm_postgres/lib/src/compiler/postgres_compiler.dart`, `packages/worm_sqlite/lib/src/compiler/sqlite_compiler.dart`). Every pattern the server builds states its escape character, a backslash, in the SQL (`ESCAPE '\'`), because SQLite has no default one and PostgreSQL and MySQL disagree on theirs. The operand of `contains`, `startsWith` and `endsWith` is escaped with `beakEscapeLike` (`packages/beak_core/lib/src/query/beak_like_pattern.dart`), so `50%` finds the text `50%` and not every row that contains `50`. The operand of `like` and `ilike` is a pattern: `%` and `_` are wildcards in it, and a backslash makes the next character literal, so `50\%` matches the text `50%`. An operand of the wrong shape for its operator (a number for `contains`, a scalar for `inList`, three values for `between`) is a `BeakValidationException` from the translator, which the API returns as a `422` (see [Rules and limits](#rules-and-limits)).

An operand also has to fit the column it is compared with, and the translator checks that before any database sees it, so a mistake is the same `422` on every database. An integer column takes integers, a decimal column integers and finite fractions, a boolean column booleans, a timestamp column a `BeakDateTimeValue` and a text column (enums included) a string that holds no NUL character. A column whose semantic changes what is stored is checked by what it stores: a money, exact-decimal or duration column takes integer units, a calendar-date or time column takes ISO text. `null` always passes, `inList` and the range operators check every element, and the pattern operators (`like`, `ilike`, `contains`, `startsWith`, `endsWith`) apply to text columns only.

## Values on the wire

`BeakValue` is a sealed class that wraps an operand so a spec serializes without `dynamic`. `BeakValue.of(raw)` wraps `null`, `bool`, `int`, `double`, `String`, `DateTime` and `List`, passes an existing `BeakValue` through, and throws a `BeakConfigurationException` for anything else. `BeakValue.fromJson` is the inverse.

| Variant | Wraps | JSON | Note |
| --- | --- | --- | --- |
| `BeakNullValue` | Nothing | `null` | Operand of `isNull`, `isNotNull`, and the default of a `BeakFieldFilter` |
| `BeakBoolValue` | `bool` | `true` / `false` | |
| `BeakIntValue` | `int` | `42` | |
| `BeakDoubleValue` | `double` | `1.5` | A JSON number with a fraction decodes to this |
| `BeakStringValue` | `String` | `"text"` | Also the wire form of an enum name and of a `BeakDate` |
| `BeakDateTimeValue` | `DateTime` | `{"type": "dateTime", "value": "2026-01-05T00:00:00.000Z"}` | Tagged so it never decodes as a plain string. The value is always the UTC instant, `toUtc().toIso8601String()`, so a local `DateTime` travels with a `Z` and names the same moment for the server. A hand-written value with no offset is read as UTC, never in the zone of the machine that decodes it. Two values are equal when they name the same instant |
| `BeakListValue` | `List<BeakValue>` | `[1, 2, 3]` | Operand of `inList`, `notInList`, `between`, `notBetween`. Nesting past 16 lists is refused |

Every variant exposes `raw` (plain Dart; a `BeakDateTimeValue` unwraps to a `DateTime`) and `toJson()`.

A typed predicate does not call `BeakValue.of` on an enum or a semantic value. It encodes through the field's column (`BeakScalarField.encode`), which is why these operands work:

| Field type | Operand you pass | Encoded as | Real output |
| --- | --- | --- | --- |
| Enum | `BookFormat.hardcover` | `BeakStringValue` of the enum name | `"hardcover"` |
| `BeakDecimal` (money or exact decimal) | `BeakDecimal.parse('12.50')` | `BeakIntValue` of the integer units at the semantic scale | `1250` |
| `BeakDate` | `BeakDate(2026, 9, 29)` | `BeakStringValue`, `YYYY-MM-DD` | `"2026-09-29"` |
| `BeakTime` | `BeakTime(8, 30)` | `BeakStringValue`, `HH:mm:ss` | `"08:30:00"` |
| `Duration` | `Duration(minutes: 2)` | `BeakIntValue` of microseconds | `120000000` |
| `DateTime` | `DateTime.utc(2026)` | `BeakDateTimeValue` | tagged object above |

`BeakValue.of` on an enum, a `Duration` or a `BeakDecimal` throws; go through the field.

## Typed field references

The generated model exposes one reference per column and relationship: `ProductModel.price` is a `BeakScalarField<double>`, `ProductModel.category` a `BeakToOneField`. All of them extend `BeakFieldRef<T>`.

| Member | Type | Meaning |
| --- | --- | --- |
| `model` | `BeakModel` | Root model that owns the path |
| `path` | `List<BeakRelationship>` | To-one relationships between the root model and the field's owner |
| `isRequired` | `bool` | Whether the schema declares a non-nullable value |
| `key` | `String` | Storage key of the terminal column or relationship |
| `label` | `String` | Default human-readable label |
| `qualifiedKey` | `String` | Path keys and `key` joined by `.`. This is the string a query carries |
| `readFrom(BeakRecord)` | `T?` | Reads the value from an already-loaded record; never loads |
| `invalid(String message)` | `BeakValidationException` | A validation failure attached to this field |
| `ownerRecord(BeakRecord)` | `BeakRecord?` | Follows the eagerly loaded to-one path to the owner record |

`BeakScalarField<T>` adds the following.

| Member | Meaning |
| --- | --- |
| `column` | The `BeakColumn` constant behind the field |
| `require(BeakRecord)` | Like `readFrom`, but throws `BeakRecordShapeException` when the value is absent |
| `encode(T? value)` | The value in the column's wire form, as a `BeakValue` |
| `to(T? value)` | Pairs the field with a value for a typed write (`BeakFieldValue`) |
| `writeTo(BeakRecord, T? value)` | Returns a record with this root field replaced; throws for a field reached through a relationship |
| `rootKey` | The field's key on its own model; throws for a field reached through a relationship |
| `ascending()`, `descending()` | A `BeakSort` on `rootKey` |
| `eq`, `notEq`, `gt`, `gte`, `lt`, `lte`, `contains` | Predicates, see above |
| `sum(BeakDataSource source, {BeakFilter? filter, bool withTrashed})` | On `BeakScalarField<BeakDecimal>` only. Returns the exact `BeakDecimal` total |

`BeakToOneField` adds `relation`, `target`, `relationLoad` (the eager load that brings the related record, including every relationship on its path), `linkTo(BeakRecordRef)` for typed writes, and `options({String search = '', BeakFilter? filter})`. `BeakToManyField` adds `relation`, `target`, `any(filter)` and `search(field)`, which roots a target field on the collection for use in a resource's global search sources. `beak prepare` generates a subclass of `BeakToOneField` per model, so `BookModel.author.name` is a `BeakScalarField<String>` whose `path` is `[author]`.

`BeakFormattedField<T>` (`package:beak/panel.dart`) wraps a scalar field with a display format (`currency`, `formatted`). It keeps model, column and path, and queries, sorts and filters ignore the format. Scaled or formatted values never enter a payload.

## Sorts

```dart title="packages/beak_core/lib/src/query/beak_sort.dart"
const BeakSort(this.columnKey, {this.descending = false});
```

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `columnKey` | `String` | required | Key of a column of the queried model |
| `descending` | `bool` | `false` | Sort largest first |

JSON: `{"column": "title", "descending": false}`. `column` is required when decoding and `descending` defaults to `false`, so `{"column": "title"}` sorts ascending. Sorts apply in list order. Typed code can only sort by a field of the model itself: `ascending()`, `descending()` and `orderBy` throw for a field reached through a relationship, and the server answers a hand-written dotted key such as `category.name` with a `422`.

## Search

```dart title="packages/beak_core/lib/src/query/beak_query_spec.dart"
const BeakSearch(this.term, this.columnKeys);
```

`columnKeys` are qualified keys, so `author.name` searches through the author relationship. `beakSearchFilter` turns a search into one `BeakOrFilter` over the columns, chosen by column kind:

```dart title="packages/beak_core/lib/src/query/beak_search_filter.dart"
BeakFilter? beakSearchFilter(
  BeakSearch? search,
  BeakModel model,
  BeakModelRegistry registry,
) {
```

| Column kind | Predicate the term becomes |
| --- | --- |
| Any string-backed column: `String`, `BeakText`, rich text, enum (matches the stored name), color, image and file references | `ilike` with `%term%`, with `%`, `_` and `\` in the term escaped |
| `int` | `eq` when the term parses as an integer, otherwise the column is skipped |
| `double` | `eq` when the term parses as a number, otherwise skipped |
| `bool` | `eq` for the terms `true` and `false`, otherwise skipped |
| `DateTime` | `eq` when `DateTime.tryParse` accepts the term, otherwise skipped |
| Exact decimal, money | `eq` when the term parses at the column's scale, otherwise skipped |
| `BeakDate`, `BeakTime` | `eq` when the term parses, otherwise skipped |
| `Duration` | `eq` when the term is an integer number of microseconds, otherwise skipped |

Rules:

- A search with a blank term (after trimming) or no columns adds no predicate.
- The term is trimmed before use. When no column can represent the term, the search matches no records.
- A column or relationship that does not exist, a password column, a JSON column (which includes list and object fields) or a custom column in the list is a `BeakValidationException`, a `422` on the API.
- A path of more than 17 segments is a `BeakValidationException`.
- The API folds the search into `filter` before execution, so the query that reaches the database carries no separate search.

## Relation loads

Beak never lazy-loads. A relation appears on a record only when the spec asked for it.

```dart title="packages/beak_core/lib/src/query/beak_relation_load.dart"
const BeakRelationLoad(
  this.relationKey, {
  this.filter,
  this.nested = const [],
});
```

| Field | Type | Default | JSON key | Meaning |
| --- | --- | --- | --- | --- |
| `relationKey` | `String` | required | `relation` | Key of a relationship of the model being loaded |
| `filter` | `BeakFilter?` | `null` | `filter` | Constrains which related rows load |
| `nested` | `List<BeakRelationLoad>` | `[]` | `nested` | Relations of the related model to load in turn |

Only `relation` is required when decoding: `filter` and `nested` default to no constraint and no nested loads, so `{"relation": "author"}` loads the bare relation. A dotted `relation` such as `items.product` is accepted by the API and expanded into nested loads. The API also intersects every load with the related model's row policy, so a load never returns rows the caller could not query directly. `BeakToOneField.relationLoad` builds the nested chain for a field reached through several relationships.

## Pagination and pages

```dart title="packages/beak_core/lib/src/query/beak_pagination.dart"
const BeakPagination({this.page = 1, this.perPage = 25})
    : assert(page >= 1, 'page is 1-based and must be >= 1'),
      assert(perPage >= 1, 'perPage must be >= 1');
```

`BeakPagination.fromJson` takes both keys as optional (`page` 1, `perPage` 25) and throws a `BeakConfigurationException` for a value below 1. The server turns the window into `limit(perPage)` and `offset((page - 1) * perPage)`.

`BeakPagination.maxPerPage` (200) is the largest page a server serves. A query that asks for more is answered with 200 rows and an envelope whose `perPage` says 200, so a client that needs the rest pages through it, and one that needs a total asks a summary or an aggregate. `defaults.build(maxPerPage: ...)` (and `BeakServer`, `beakApiRouter`) changes the ceiling for the whole server. A page whose offset would pass 2^53 - 1 rows is a `422`.

The response is a `BeakPage<T>`.

```dart title="packages/beak_core/lib/src/query/beak_page.dart"
const BeakPage({
  required this.items,
  required this.total,
  required this.page,
  required this.perPage,
});
```

| Field | Type | Meaning |
| --- | --- | --- |
| `items` | `List<T>` | The records of this page, in result order |
| `total` | `int` | Records matching the query across all pages, counted before the page window applies |
| `page` | `int` | The 1-based page this envelope represents |
| `perPage` | `int` | The page size the query used |

`BeakPage.fromJson(json, decodeItem)` and `toJson(encodeItem)` take the item codec, so the envelope stays generic. A client has more pages when `page * perPage < total`.

### Records

A `BeakRecord` holds typed values by column key and eager-loaded relations by relation key. A to-one relation is a list of at most one record. Real output of `BeakPage<BeakRecord>.toJson` for one book with its author loaded:

```json
{
  "items": [
    {
      "values": {
        "id": 1,
        "title": "Notes",
        "publishedOn": { "type": "dateTime", "value": "2026-01-05T00:00:00.000Z" }
      },
      "relations": {
        "author": [{ "values": { "id": 7, "name": "Ada Lovelace" }, "relations": {} }]
      }
    }
  ],
  "total": 41,
  "page": 2,
  "perPage": 1
}
```

| Member | Meaning |
| --- | --- |
| `BeakRecord({required values, relations})` | Typed values and eager-loaded relations |
| `BeakRecord.fromRow(Map<String, Object?>)` | Wraps every value with `BeakValue.of` |
| `BeakRecord.fromJson`, `toJson()` | Wire form above. Both `values` and `relations` are required when decoding |
| `record[key]` | The `BeakValue` under `key`, or `null` |
| `values`, `relations` | Unmodifiable views |
| `toRow()` | Plain Dart row, the inverse of `fromRow` |

Generated `XRecord` extension types (`record.asBook`) read a record with the declared Dart types. See [Generated files and symbols](generated-files.md).

## Aggregates

`BeakAggregateSpec` computes one number over the rows that match a filter.

| Model method | Result | Column |
| --- | --- | --- |
| `count({BeakFilter? filter, bool withTrashed = false})` | Number of matching rows | None |
| `sum(BeakScalarField<num> field, {filter, withTrashed})` | Sum of the column | Required |
| `avg(BeakScalarField<num> field, {filter, withTrashed})` | Arithmetic mean of the column | Required |

```dart title="packages/beak_core/lib/src/model/beak_model.dart"
BeakAggregateSpec count({BeakFilter? filter, bool withTrashed = false}) =>
    BeakAggregateSpec.count(
// ...
BeakAggregateSpec sum(
  BeakScalarField<num> field, {
  BeakFilter? filter,
  bool withTrashed = false,
}) => BeakAggregateSpec.sum(
// ...
```

| Field | Type | Default | JSON key | Meaning |
| --- | --- | --- | --- | --- |
| `table` | `String` | required | `table` | Stored table name; must not be empty |
| `function` | `BeakAggregateFunction` | required | `function` | `count`, `sum` or `avg` |
| `columnKey` | `String?` | `null` | `column` | Required for `sum` and `avg`, forbidden for `count` |
| `filter` | `BeakFilter?` | `null` | `filter` | Rows to aggregate |
| `withTrashed` | `bool` | `false` | `withTrashed` | Include soft-deleted rows |

`BeakAggregateSpec.fromJson` needs `table` and `function`. `BeakAggregateSpec.forKey` (the decoder path) throws a `BeakConfigurationException` when `column` contradicts the function. Real output:

```json
{ "table": "book", "function": "count", "column": null,
  "filter": { "type": "field", "column": "stock", "operator": "gt", "value": 0 },
  "withTrashed": false }
```

The API answers `{"value": <number>}`. `sum` and `avg` over no rows return `0`. Sums and averages are in stored units: an exact decimal or money column is a count of minor units. `BeakScalarField<BeakDecimal>.sum(source)` runs the sum and returns a `BeakDecimal` at the semantic scale; it throws when the result is fractional or outside the safe integer range and never rounds. An average of whole units is rarely whole, so `BeakScalarField<BeakDecimal>.avg(source, rounding: ...)` takes the rounding you mean (`BeakRounding.floor`, `ceiling`, `halfAwayFromZero` or `halfToEven`).

`model.sum` and `model.avg` take `BeakScalarField<num>`, which a money field is not. For an exact-decimal or money field use `model.sumDecimal(field)` and `model.avgDecimal(field)`. They put the same request on the wire (stored units are integers, so the sum is exact) and throw a `BeakConfigurationException` for a field of another model, one reached through a relationship, or one without exact-decimal or money semantics. There is no `min` or `max` aggregate. The server answers a `sum` or `avg` over a column that is not numeric, or a dotted column, with a `422`.

## Summaries

`BeakSummarySpec` computes named measures over the whole matching population, grouped by one field. It is the query behind preset counts, choice-filter counts and dashboard blocks.

```dart title="packages/beak_core/lib/src/model/beak_model.dart"
BeakSummarySpec summary({
  BeakScalarField<Object>? groupBy,
  required List<BeakSummaryMeasure> measures,
  BeakFilter? filter,
  BeakSearch? search,
  int limit = 100,
  bool withTrashed = false,
}) => BeakSummarySpec.forKeys(
```

| Field | Type | Default | JSON key | Meaning |
| --- | --- | --- | --- | --- |
| `table` | `String` | required | `table` | Stored table name |
| `groupByKey` | `String?` | `null` | `groupBy` | Scalar column to group by; `null` returns one total row |
| `measures` | `List<BeakSummaryMeasure>` | required | `measures` | One to eight measures with unique keys |
| `filter` | `BeakFilter?` | `null` | `filter` | Population shared by every measure |
| `search` | `BeakSearch?` | `null` | `search` | The same search a query uses |
| `limit` | `int` | `100` | `limit` | Maximum groups returned, 1 to 500 |
| `withTrashed` | `bool` | `false` | `withTrashed` | Include soft-deleted rows |

A measure is declared once and read back by object.

```dart title="packages/beak_core/lib/src/query/beak_summary_spec.dart"
const BeakSummaryMeasure.count(this.key, {this.filter})
    : columnKey = null,
      scale = null;
BeakSummaryMeasure.sum(
  this.key, {
  required BeakScalarField<num> field,
  this.filter,
}) : columnKey = field.rootKey,
       scale = null;
BeakSummaryMeasure.sumDecimal(
  this.key, {
  required BeakScalarField<BeakDecimal> field,
  this.filter,
}) : columnKey = field.exactColumn.key,
       scale = field.scale;
const BeakSummaryMeasure.forKey(this.key, {this.columnKey, this.filter})
    : scale = null;
```

| Measure field | Meaning |
| --- | --- |
| `key` | Names the value in the response; 1 to 80 characters, unique within the spec |
| `columnKey` | Numeric column to sum, or `null` to count. `count` counts records, including those whose group is `null` |
| `filter` | Predicate ANDed with the spec's shared population for this measure only |
| `scale` | Decimal places of a `sumDecimal` measure, otherwise `null`. Client-side only; it never travels |

Summaries offer `count` and `sum`, no `avg`. A `sum` over an empty group is `0`. `BeakSummaryMeasure.sumDecimal` sums an exact-decimal or money field: the wire form is the same as `sum`'s, and `row.decimalOf(measure)` reads the total back as a `BeakDecimal` at the field's scale. It throws a `BeakConfigurationException` for a measure that is not a decimal sum and for a value that is not a whole number of stored units. It never rounds.

`BeakSummaryResult` is the response: `rows` (a `List<BeakSummaryRow>`) and `truncated` (`true` when more groups exist than `limit`). A `BeakSummaryRow` has `group` (a `BeakValue`, `BeakNullValue` for the null group and for a total row) and `values` (`Map<String, num>` by measure key); read one value with `row.valueOf(measure)`. Rows are ordered by group: `null` first, numbers ascending, everything else by its string form. Real `toJson()` output for `summary(groupBy: BookModel.format, measures: [books, stock])`, the request body:

```json
{
  "table": "book", "groupBy": "format",
  "measures": [{ "key": "books", "column": null }, { "key": "stock", "column": "stock" }],
  "filter": null, "search": null, "limit": 100, "withTrashed": false
}
```

```json
{
  "rows": [
    { "group": "hardcover", "values": { "books": 12, "stock": 40 } },
    { "group": null, "values": { "books": 1, "stock": 0 } }
  ],
  "truncated": false
}
```

The second block is the response: the shape `BeakSummaryResult.toJson` produces, with illustrative values.

`withQuery(BeakQuerySpec query)` swaps the population of an existing summary for the filter, search and `withTrashed` of a query on the same table. The panel uses it to reuse the active list query. A data source that cannot summarize does not implement `BeakSummaryDataSource`, and the API answers with a `BeakConfigurationException`.

## Option queries

`BeakOptionQuery` describes the records a picker offers and performs no I/O. The panel's data runtime executes it.

```dart title="packages/beak_core/lib/src/model/beak_field_ref.dart"
const BeakOptionQuery({required this.model, required this.query});
```

| Member | Meaning |
| --- | --- |
| `model` | Model whose data source runs the query |
| `query` | Filter, sorts, search and pagination |
| `including(List<BeakToOneField> fields)` | A copy that also eager-loads each to-one path; throws when a field belongs to another model |

Sources: `BeakToOneField.options({search, filter})` uses the relationship's search columns, and the generated model carries `XModel.options({filter})` and `XModel.search(term, {filter})`.

## How a list builds its spec

The list screen keeps user choices in a `BeakQueryState` and derives the spec from it. The permanent scope (`base`) is never serialized.

```dart title="packages/beak_frontend/lib/src/query/beak_query_controller.dart"
return BeakQuerySpec(
  table: model.table,
  filter: BeakFilter.allOf([
    ?base.filter,
    ?preset?.filter,
    for (final entry in effectiveFilters(value).entries)
      if (entry.key != excludingFilter) entry.value,
  ]),
  search: value.search.trim().isEmpty || searchKeys.isEmpty
      ? base.search
      : BeakSearch(value.search.trim(), searchKeys),
  sorts: value.sorts,
  relationLoads: base.relationLoads,
  pagination: BeakPagination(page: value.page, perPage: value.perPage),
  withTrashed: base.withTrashed,
);
```

When a list declares no search fields, the search runs over the model's `searchable` columns. `BeakQueryState` rejects a page below 1, a page size below 1 and a page size above 1000. See [Filter builders](filter-builders.md) for how filter controls produce the predicates in `effectiveFilters`.

## Required keys

When the API decodes a spec, absent keys fall back to the defaults the constructors declare, at the top level and in the objects nested inside a query. A key that is present must have the right type. Two things have no default: a sort without a column, a relation load without a relation, and a search without a term or columns are rejected with a message naming the missing key.

| Object | Required keys | Optional keys |
| --- | --- | --- |
| `BeakQuerySpec` | `table` | `filter`, `sorts`, `search`, `relations`, `pagination`, `withTrashed` |
| Field filter | `type`, `column`, `operator`, `value` (may be `null`) | |
| And / or filter | `type`, `filters` | |
| Relation filter | `type`, `relation`, `filter` | |
| `BeakSort` | `column` | `descending` (`false`) |
| `BeakSearch` | `term`, `columns` | |
| `BeakRelationLoad` | `relation` | `filter` (none), `nested` (none) |
| `BeakPagination` | | `page` (`1`), `perPage` (`25`) |
| `BeakAggregateSpec` | `table`, `function` | `column`, `filter`, `withTrashed` |
| `BeakSummarySpec` | `table`, `measures` | `groupBy`, `filter`, `search`, `limit`, `withTrashed` |
| `BeakSummaryMeasure` | `key` | `column`, `filter` |

## Rules and limits

What the API rejects, and with which status. `422` carries a message safe to show; `500` is a `BeakConfigurationException`, which now means the server is wired wrong and never that the caller's spec was.

| Condition | Result |
| --- | --- |
| Body is not valid JSON, or not a JSON object | `422` |
| Spec fails to decode (missing key, wrong type, unknown operator, unknown filter `type`, bad timestamp) | `422`, message begins `Malformed spec body:` |
| `table` differs from the route's table, or names a table nobody registered | `422` |
| Caller may not view the model | `401` when anonymous, `403` when signed in |
| Sort, filter or relation names an unknown field or relationship | `422` |
| Sort, filter or relation names a field or relationship the caller may not read | `401` when anonymous, `403` when signed in |
| Filter or load nested deeper than 64 levels | `422` |
| Relationship filter nested more than 16 levels deep | `422` |
| Operand of the wrong shape for the operator, or of a type the column cannot compare with (text for an integer column, a pattern operator on a number, NUL in text) | `422` |
| A value the database refuses in a comparison (an integer outside an `integer` column) | `422` |
| Search over an unknown, password, JSON or custom column, or a search path over 17 segments | `422` |
| Sort key, aggregate column, summary group or summary measure column with a dot | `422` (these work on the queried table's own columns) |
| Aggregate `sum` or `avg` over a column that is not numeric | `422` |
| Page whose offset passes 2^53 - 1 rows | `422` |
| Summary: no measures, more than 8, duplicate or over-long key, `limit` outside 1 to 500 | `422` |
| Summary: group is a JSON or custom column, or a measure column is not numeric | `422` |
| Summary against a data source without `BeakSummaryDataSource` | `500` |

Behaviors that follow from the contract:

- Every read is intersected with the caller's row policy: the policy's scope is ANDed into the filter, into every relation filter and into every relation load. The filter a client sends cannot widen it.
- A sort always ends with the primary key, so rows that tie on the sort column keep one order across pages and each shows on exactly one of them. A query with no sort is left in the order the database keeps.
- Soft-deleting models hide deleted rows unless `withTrashed` is `true`. A relation filter always ignores soft-deleted related rows.
- Search and filters combine with AND. A `BeakChoiceFilter` ORs its own choices before that.
- `total` is a count of the filtered population, computed by a separate `COUNT` before the page is read.
- A page size above 200 (`BeakPagination.maxPerPage`) is served as 200, and the envelope's `perPage` reports the size used. The panel's `BeakQueryState` refuses a page size above 200 for the same reason, and a saved view or bookmark written with a larger size loads at 200.
- A query costs one `COUNT`, one page `SELECT`, and one batched query per eager-loaded relation level.
- `contains`, `startsWith`, `endsWith` and the search escape `%`, `_` and `\` in the term, so they match the text they were given.
- Number operands are compared by the database. A JSON `2000` decodes to `BeakIntValue`, `2000.0` to `BeakDoubleValue`.

## Source

- `packages/beak_core/lib/src/query/beak_query_spec.dart`: `BeakQuerySpec`, `BeakSearch`.
- `packages/beak_core/lib/src/query/beak_filter.dart`: `BeakFilter` and its four subclasses.
- `packages/beak_core/lib/src/query/beak_operator.dart`: `BeakOperator`.
- `packages/beak_core/lib/src/query/beak_value.dart`: `BeakValue` and its variants.
- `packages/beak_core/lib/src/query/beak_sort.dart`, `beak_pagination.dart`, `beak_page.dart`, `beak_record.dart`, `beak_relation_load.dart`, `beak_table_ref.dart`.
- `packages/beak_core/lib/src/query/beak_aggregate_spec.dart`, `beak_summary_spec.dart`: aggregates and summaries.
- `packages/beak_core/lib/src/query/beak_search_filter.dart`: `beakSearchFilter`.
- `packages/beak_core/lib/src/query/beak_like_pattern.dart`: `beakLikeEscape`, `beakEscapeLike` and `beakLikeRegExp`, which a data source that evaluates a pattern in Dart uses to match the way the databases do.
- `packages/beak_core/lib/src/model/beak_field_ref.dart`: field references, typed predicates, `BeakOptionQuery`.
- `packages/beak_core/lib/src/model/beak_model.dart`: `query`, `count`, `sum`, `avg`, `summary`.
- `packages/beak_backend/lib/src/data/worm/query_translator.dart`: spec to worm translation.
- `packages/beak_backend/lib/src/auth/beak_query_authorizer.dart`: policy scoping and path checks.
- `packages/beak_backend/lib/src/data/worm/worm_data_source.dart`: query, aggregate and summary execution.
- `packages/beak_frontend/lib/src/query/beak_query_controller.dart`: `BeakQueryState` and the list's spec.

## Continue reading

- [REST API](rest-api.md) the routes that accept a spec and the error envelope.
- [Exceptions](exceptions.md) the typed exceptions behind the `422` and `500` results above.
- [The query contract](../architecture/query-contract.md) how a filter travels from a column constant to a worm predicate.
