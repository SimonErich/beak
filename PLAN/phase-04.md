# Phase 04 — beak_core: serializable query spec (the wire contract)

## Objective
Define `BeakQuerySpec` — the typed, losslessly JSON-serializable description of a query
that the frontend builds and the backend executes via worm. This is the contract that
makes "the backend is invisible" work without leaking `dynamic`.

## Prerequisites
- Phase 03 `✅ DONE`.

## Files created (in `packages/beak_core/lib/src/query/`)
- `beak_query_spec.dart`
- `beak_filter.dart` (sealed predicate tree)
- `beak_sort.dart`, `beak_pagination.dart`, `beak_relation_load.dart`
- `beak_value.dart` (typed value wrapper for serialization)
- barrel updates

## Public API to implement (contract)

### Typed serializable value
Filters compare against values that must serialize without `dynamic`. Model them:
```dart
sealed class BeakValue {
  const BeakValue();
  Object? toJson();                 // primitive JSON
  static BeakValue of(Object? raw); // factory from String/int/double/bool/DateTime/null/List
}
// BeakStringValue, BeakIntValue, BeakDoubleValue, BeakBoolValue, BeakDateTimeValue,
// BeakNullValue, BeakListValue(List<BeakValue>)
```

### Predicate tree
```dart
sealed class BeakFilter {
  const BeakFilter();
  Map<String, Object?> toJson();
  static BeakFilter fromJson(Map<String, Object?> json);
}
// BeakFieldFilter(columnKey, BeakOperator, BeakValue)
// BeakAndFilter(List<BeakFilter>)
// BeakOrFilter(List<BeakFilter>)
```
Add ergonomic builders so callers never construct raw nodes with strings:
`BeakColumn`-aware helpers live in `beak_frontend`, but `beak_core` exposes
`BeakFieldFilter(column: BeakColumn, operator:, value:)` taking a `BeakColumn` (reads its
`key`), keeping the type-safety promise.

### Sort / pagination / relation loads
```dart
final class BeakSort { const BeakSort(this.columnKey, {this.descending = false}); ... toJson/fromJson }
final class BeakPagination { const BeakPagination({this.page = 1, this.perPage = 25}); ... }
final class BeakRelationLoad { const BeakRelationLoad(this.relationKey, {this.filter, this.nested = const []}); ... }
```

### The spec
```dart
final class BeakQuerySpec {
  const BeakQuerySpec({
    required this.table,
    this.filter,                    // BeakFilter?
    this.sorts = const [],          // List<BeakSort>
    this.search,                    // BeakSearch? (term + column keys)
    this.relationLoads = const [],  // List<BeakRelationLoad>  (reference dedup / eager)
    this.pagination = const BeakPagination(),
    this.withTrashed = false,       // soft-delete awareness
  });
  Map<String, Object?> toJson();
  static BeakQuerySpec fromJson(Map<String, Object?> json);

  // Immutable copy-builders mirroring the concept's fluent API:
  BeakQuerySpec withFilter(BeakFilter f);           // AND-merges
  BeakQuerySpec orderBy(BeakColumn c, {bool descending = false});
  BeakQuerySpec withRelation(BeakRelationship r, {BeakFilter? constraint});
  BeakQuerySpec searching(String term, List<BeakColumn> columns);
  BeakQuerySpec paginate({int page, int perPage});
}
final class BeakSearch { const BeakSearch(this.term, this.columnKeys); ... toJson/fromJson }
```
Plus a paged result envelope returned by the backend:
```dart
final class BeakPage<T> {
  const BeakPage({required this.items, required this.total, required this.page, required this.perPage});
  // toJson/fromJson given an item (de)serializer function.
}
```

## Tests to write FIRST — golden serialization is the core proof
- `beak_value_test.dart` — every `BeakValue` variant round-trips; `BeakValue.of` picks
  the right variant for each Dart type; unsupported types throw a clear config error.
- `beak_filter_test.dart` — nested AND/OR trees `toJson`→`fromJson` deep-equal; **pin the
  exact JSON map** for a representative tree (golden).
- `beak_query_spec_test.dart` — build a rich spec via the copy-builders (matching the
  concept example: with([author]), where(status eq active), where(lastActive lt X),
  orderBy(createdAt desc), search, paginate) → `toJson` matches a **committed golden JSON
  file**, and `fromJson(toJson(x)) == x`.
- `beak_page_test.dart` — envelope round-trips with a sample item serializer.
- Property-ish test: encode→decode→encode is stable (idempotent JSON).

## Implementation notes / constraints
- Absolutely no `dynamic` and no `Map<String,dynamic>` as a public type — the JSON maps
  are an internal serialization detail, and public methods take/return typed objects.
- `fromJson` validates structure and throws `BeakConfigurationException` on malformed
  input (tested).
- Keep it ORM-neutral: the spec references column/relation **keys**, not worm fields.

## Definition of Done (gate)
- [ ] analyze 0 · tests green · `beak_core` coverage 100% · format clean.
- [ ] Committed golden JSON file(s) under `test/golden/` match and are asserted.
- [ ] `fromJson(toJson(spec)) == spec` for the rich example.
- [ ] STATE.md row 04 → `✅ DONE` + SHA.

## Commit
`feat(beak_core): add serializable, type-safe query spec with golden coverage`
