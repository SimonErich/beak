# worm_postgres

PostgreSQL adapter and SQL compiler for the worm ORM.

## ⚠️ Status: needs post-EPIC-004 API alignment

This adapter was authored against the pre-EPIC-004 query API and has
not yet been updated for the merged worm core. `dart analyze`
currently reports ~120 errors against:

- `Predicate.column` → renamed to `Predicate.fieldName` in EPIC-004.
- `QueryDescriptor.predicates: List<Predicate>` → replaced by
  `QueryDescriptor.where: PredicateTree?`.
- `SchemaOperation.createTable/dropTable/truncateTable` → renamed to
  `SchemaOperation.create/drop/truncate`.
- `SchemaDescriptor.columns: List<String>` → typed
  `List<SchemaColumn>`.
- `OrderBy` → renamed to `SortClause` with `SortDirection` enum.
- `DatabaseAdapter.explain(QueryDescriptor) → Future<String>` →
  removed; adapters that support EXPLAIN mix in `ExplainCapable` from
  `package:worm/src/logging/explain_runner.dart` and return
  `Future<ExplainResult>` instead.

Tracked in `packages/worm/concept/missing-worm-concept-spec.md` as a
follow-up epic.

## Layout

- `lib/src/compiler/postgres_compiler.dart` — descriptor → SQL.
- `lib/src/pool/postgres_connection_pool.dart` — connection pool.
- `lib/src/pool/prepared_statement_cache.dart` — prepared-stmt cache.
- `lib/src/postgres_adapter.dart` — top-level adapter.
- `lib/src/postgres_transaction_adapter.dart` — transaction adapter.
- `lib/src/postgres_error_mapper.dart` — Postgres error → worm
  exceptions.
