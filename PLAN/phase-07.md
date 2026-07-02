# Phase 07 — beak_backend: Shelf foundation + DataSource abstraction

## Objective
Stand up the Shelf server foundation, the middleware stack, the source-agnostic
`BeakDataSource` interface, and its default `WormDataSource` that translates a
`BeakQuerySpec` into a worm query. Wire worm to Postgres and load config from env.

## Prerequisites
- Phases 04 (`BeakQuerySpec`) and 05 (storage) `✅ DONE`. Docker Postgres available.

## Files created (in `packages/beak_backend/lib/src/`)
- `server/beak_server.dart`, `server/middleware/*.dart`
- `data/beak_data_source.dart` (interface)
- `data/worm/worm_data_source.dart`, `data/worm/query_translator.dart`,
  `data/worm/column_type_mapper.dart`
- `config/beak_backend_config.dart`, `config/env_loader.dart`
- barrel updates

## Public API to implement (contract)

### The source-agnostic data interface (the beak_serverpod seam)
```dart
abstract interface class BeakDataSource {
  Future<BeakPage<BeakRecord>> query(BeakQuerySpec spec);
  Future<BeakRecord?> getOne(String table, Object id);
  Future<BeakRecord> create(String table, BeakRecord data);
  Future<BeakRecord> update(String table, Object id, BeakRecord data);
  Future<void> delete(String table, Object id, {bool force = false});
  Future<List<BeakRecord>> batchGet(String table, List<Object> ids); // reference dedup
  Future<void> attach(String table, Object id, String relationKey, List<Object> relatedIds);
  Future<void> detach(String table, Object id, String relationKey, List<Object> relatedIds);
  Future<num> aggregate(BeakAggregateSpec spec); // count/sum/avg for dashboards
}
```
`BeakRecord` is a typed row wrapper (NOT `Map<String,dynamic>`): it holds
`Map<String, BeakValue>` internally and exposes typed getters/`toJson`/`fromJson`. Define
it in `beak_core` (Phase 04 addendum) or `beak_backend` — prefer `beak_core` so the
frontend client can reuse it. If added now, update `beak_core` and re-gate it at 100%.

### WormDataSource (default implementation)
```dart
final class WormDataSource implements BeakDataSource {
  WormDataSource(this.registry, {required this.adapters});
  final BeakModelRegistry registry;
  // Translates BeakQuerySpec -> worm QueryBuilder using query_translator.dart:
  //   filter tree -> PredicateTree, sorts -> orderBy, search -> OR of ilike/contains
  //   over searchColumnKeys, relationLoads -> withRelations/withNested (batched!),
  //   pagination -> paginate(), withTrashed -> soft-delete scope.
  //   BeakOperator -> worm Operator mapping (from the documented table).
}
```
The translator is generic: it does not know Product/User; it uses `BeakModel` metadata +
worm's descriptor API. Because worm models normally need a concrete `static query()`, the
backend uses a **generic worm querying path**: construct a `QueryContext` from the
`BeakModel` (table + a row-map hydrator that yields `BeakRecord`) so a single code path
serves every registered model without per-model boilerplate. Verify this against the worm
spec's `QueryContext`/`QueryBuilder.from` API; if a generic hydrator to `BeakRecord` is
cleanest, use it.

### Server + middleware
```dart
final class BeakServer {
  BeakServer({required this.config, required this.dataSource, required this.registry,
      this.storage, this.authGuard, this.router});
  Handler get handler;                 // the composed Shelf handler
  Future<HttpServer> start();
}
```
Middleware (each its own file, composed in order): request-id + logging, JSON
encode/decode, CORS, error-mapping (`BeakException` → status+JSON:
validation→422 with fieldErrors, notFound→404, auth→401/403, conflict→409, config→500),
and an auth hook slot (guard added in Phase 10; default = pass-through here).

### Config
```dart
final class BeakBackendConfig {
  const BeakBackendConfig({required this.databaseUrl, required this.port, ...});
  static BeakBackendConfig fromEnv(); // reads DATABASE_URL, PORT, etc. Typed, validated.
}
```

## Tests to write FIRST
- `query_translator_test.dart` — the biggest: for a sample `BeakModel`, translate a rich
  `BeakQuerySpec` and assert the resulting worm query's `.toSql()` (golden) covers where/
  order/limit/offset/search; operator mapping exhaustive; `withTrashed` toggles the
  soft-delete scope; relation loads produce the batched calls (assert with worm's
  `LoggingAdapter` query count — 1 parent + 1 per relation path).
- `worm_data_source_test.dart` — against `InMemoryAdapter` + `Worm.reset()` teardown:
  create→getOne→query(paged)→update→delete→batchGet; `batchGet` issues ONE query
  (reference-dedup proof via `InMemoryQueryLogger`).
- `middleware_test.dart` — drive the Shelf `Handler` with crafted `Request`s: JSON in/out,
  CORS headers present, each `BeakException` maps to the right status + body shape.
- `config_test.dart` — `fromEnv` parses valid env; missing `DATABASE_URL` throws config.

## Implementation notes / constraints
- Follow the layering: handlers are thin; the DataSource does I/O; the translator is pure.
- Depend on `worm` + `worm_postgres` here (NOT in `beak_core`).
- No `dynamic`. `BeakRecord` typed values throughout.
- Postgres adapter constructed from `DATABASE_URL`; `Worm.initialize` once at startup
  (and a test-mode init with `InMemoryAdapter`).

## Definition of Done (gate)
- [ ] analyze 0 · tests green · coverage ≥ 90% (`beak_core` stays 100%) · format clean.
- [ ] Golden `.toSql()` for the translated query asserted.
- [ ] Reference-dedup (batchGet + relation load) query-count proof passes.
- [ ] STATE.md row 07 → `✅ DONE` + SHA.

## Commit
`feat(beak_backend): add Shelf foundation, source-agnostic DataSource and Worm translator`
