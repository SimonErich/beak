# worm_mongodb

MongoDB adapter and filter compiler for the worm ORM.

## ⚠️ Status: needs post-EPIC-004 API alignment

This adapter was authored against the pre-EPIC-004 query API and has
not yet been updated for the merged worm core. `dart analyze`
currently reports ~77 errors against:

- `Predicate.column` → renamed to `Predicate.fieldName` in EPIC-004.
- `QueryDescriptor.predicates: List<Predicate>` → replaced by
  `QueryDescriptor.where: PredicateTree?`.
- `SchemaOperation` enum constants renamed.
- `SchemaDescriptor.columns: List<String>` → typed
  `List<SchemaColumn>`.
- `OrderBy` → renamed to `SortClause`.
- `DatabaseAdapter.explain` removed in favor of the `ExplainCapable`
  mixin.

Tracked in `packages/worm/concept/missing-worm-concept-spec.md` as a
follow-up epic.

## Layout

- `lib/src/compiler/mongo_filter_compiler.dart` — descriptor → Mongo
  filter document.
- `lib/src/connection/mongo_connection.dart` — Mongo connection
  wrapper.
- `lib/src/mongo_adapter.dart` — top-level adapter.
- `lib/src/mongo_transaction_adapter.dart` — transaction adapter
  (replica set required).
- `lib/src/mongo_error_mapper.dart` — Mongo error → worm exceptions.
